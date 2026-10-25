#include "http.h"

#include <curl/curl.h>
#include "json.hpp"

#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace {

// =====================================
// CURL INIT
// =====================================

struct CurlGlobalInit {

    CurlGlobalInit()
    {
        curl_global_init(CURL_GLOBAL_DEFAULT);
    }

    ~CurlGlobalInit()
    {
        curl_global_cleanup();
    }
};

 CurlGlobalInit g_curl_init;

// =====================================
// WRITE CALLBACK
// =====================================

size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata)
{
    auto* out = static_cast<std::string*>(userdata);

    out->append(ptr, size * nmemb);

    return size * nmemb;
}

} // namespace

namespace http {

// =====================================
// REQUEST
// =====================================

Response Endpoints::request(const char* method, const std::string& path,
                            const std::string& body, long timeout) const
{
    CURL* curl = curl_easy_init();

    if (!curl) {
        throw std::runtime_error("curl_easy_init failed");
    }

    std::string url = base_url_ + path;

    std::string credentials = user_ + ":" + password_;

    Response response;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    curl_easy_setopt(curl, CURLOPT_USERPWD, credentials.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response.body);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 5L);
    curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);

    struct curl_slist* headers = nullptr;

    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Accept: application/json");

    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    if (!body.empty()) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
    }

    CURLcode result = curl_easy_perform(curl);

    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response.status);

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK) {
        throw std::runtime_error(std::string("Connection error: ") + curl_easy_strerror(result));
    }

    return response;
}

Response Endpoints::post(const std::string& path, const std::string& body, long timeout) const
{
    return request("POST", path, body, timeout);
}

Response Endpoints::put(const std::string& path, const std::string& body, long timeout) const
{
    return request("PUT", path, body, timeout);
}

Response Endpoints::get(const std::string& path, long timeout) const
{
    return request("GET", path, "", timeout);
}

Response Endpoints::patch(const std::string& path, const std::string& body, long timeout) const
{
    return request("PATCH", path, body, timeout);
}

Response Endpoints::del(const std::string& path, long timeout) const
{
    return request("DELETE", path, "", timeout);
}

// =====================================
// DISCOVER OPENCODE SERVICE
// =====================================

Endpoints discover_opencode()
{
    namespace fs = std::filesystem;

    std::string home = std::getenv("HOME") ? std::getenv("HOME") : "";

    std::string path = home + "/.local/state/opencode/service.json";

    std::ifstream file(path);

    if (!file) {
        throw std::runtime_error(
            "Не найден ~/.local/state/opencode/service.json. "
            "Запустите 'opencode' чтобы стартовать фоновый сервис.");
    }

    std::stringstream buffer;
    buffer << file.rdbuf();

    nlohmann::json doc;

    try {
        doc = nlohmann::json::parse(buffer.str());
    } catch (const std::exception& e) {
        throw std::runtime_error(std::string("service.json повреждён: ") + e.what());
    }

    std::string url = doc.value("url", "");
    std::string password = doc.value("password", "");

    if (url.empty() || password.empty()) {
        throw std::runtime_error("service.json не содержит url/password");
    }

    return Endpoints(url, "opencode", password);
}

// =====================================
// URL ENCODE
// =====================================

std::string url_encode(const std::string& input)
{
    std::ostringstream out;

    for (unsigned char c : input) {

        bool safe = std::isalnum(c)
            || c == '-' || c == '_' || c == '.' || c == '~';

        if (safe) {
            out << c;
        } else {
            out << '%' << std::uppercase << std::hex << std::setw(2)
                << std::setfill('0') << static_cast<int>(c) << std::nouppercase << std::dec;
        }
    }

    return out.str();
}

} // namespace http
