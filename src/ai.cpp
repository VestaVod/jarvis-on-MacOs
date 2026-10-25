#include "ai.h"

#include "http.h"
#include "memory.h"
#include "json.hpp"

#include <chrono>
#include <cctype>
#include <cstdlib>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <thread>

namespace fs = std::filesystem;

namespace ai {

// =====================================
// CONFIG
// =====================================

const char* SYSTEM_PROMPT =
    "Ты JARVIS — AI ассистент как у Тони Старка.\n"

    "Ты:\n"
    "- умный\n"
    "- краткий\n"
    "- уверенный\n"
    "- технологичный\n"
    "- полезный\n"

    "Отвечай только обычным текстом.\n"

    "Не используй markdown.\n"

    "Не используй LaTeX.\n"

    "Не используй **\n"

    "Не используй математическое форматирование.\n"

    "Если пользователь просит выполнить действие:\n"

    "ACTION: OPEN_APP: название\n"

    "ACTION: OPEN_SITE: сайт\n"

    "ACTION: SEARCH_GOOGLE: запрос\n"

    "Не объясняй ACTION.";

const char* TEXT_MODEL = "flint-40b-free";

const char* VISION_MODEL = "glm-5.3-flash-free";

const char* PROVIDER = "opencode";

// =====================================
// STATE
// =====================================

namespace {

std::mutex g_mutex;

std::string g_session_id;

std::string g_active_model;   // последний выбранный в сессии modelID

bool g_active_model_set = false;

std::string g_default_model;  // прочитанный из /api/model/default

std::string g_default_provider;

// =====================================
// SERVICE
// =====================================

http::Endpoints service()
{
    static http::Endpoints endpoints = http::discover_opencode();

    if (!endpoints.valid()) {
        throw std::runtime_error("Не найден локальный сервис OpenCode");
    }

    return endpoints;
}

// =====================================
// JSON HELPERS
// =====================================

nlohmann::json parse_body(const http::Response& response, const char* what)
{
    try {
        return nlohmann::json::parse(response.body);
    } catch (const std::exception& e) {
        throw std::runtime_error(std::string(what) + ": некорректный ответ сервера ("
                                 + std::to_string(response.status) + "): " + e.what());
    }
}

nlohmann::json data_of(const nlohmann::json& doc)
{
    if (doc.contains("data")) {
        return doc["data"];
    }

    return doc;
}

std::string basename_of(const std::string& path)
{
    auto pos = path.find_last_of('/');

    if (pos == std::string::npos) {
        return path;
    }

    return path.substr(pos + 1);
}

// file:///путь (с percent-encoding для спецсимволов)
std::string file_uri(const std::string& path)
{
    std::ostringstream out;

    out << "file://";

    for (unsigned char c : path) {

        bool safe = std::isalnum(c)
            || c == '/' || c == '_' || c == '.' || c == '-'
            || c == '~';

        if (safe) {
            out << c;
        } else {
            out << '%' << std::uppercase << std::hex << std::setw(2)
                << std::setfill('0') << static_cast<int>(c) << std::nouppercase << std::dec;
        }
    }

    return out.str();
}

// =====================================
// SESSION
// =====================================

std::string working_directory()
{
    std::string path = fs::current_path().string();

    // Запуск из Finder: рабочая папка "/" — используем домашнюю
    if (path == "/" || path.empty()) {
        const char* home = std::getenv("HOME");
        if (home && *home) {
            return std::string(home) + "/Documents/JarvisCPP";
        }
    }

    return path;
}

nlohmann::json fetch_session(const std::string& id)
{
    auto resp = service().get("/api/session/" + id);

    if (resp.status != 200) {
        return nullptr;
    }

    return data_of(parse_body(resp, "GET /api/session"));
}

void create_session()
{
    nlohmann::json payload;

    payload["location"] = { { "directory", working_directory() } };
    payload["title"] = "JARVIS";

    auto resp = service().post("/api/session", payload.dump(), 30);

    if (resp.status != 200 && resp.status != 201) {
        throw std::runtime_error("Не удалось создать сессию OpenCode (HTTP "
                                 + std::to_string(resp.status) + "): " + resp.body.substr(0, 300));
    }

    auto doc = data_of(parse_body(resp, "POST /api/session"));

    g_session_id = doc.value("id", "");

    if (g_session_id.empty()) {
        throw std::runtime_error("OpenCode не вернул id новой сессии");
    }

    // Регистрируем JARVIS-персону как instruction entry
    nlohmann::json instructions;

    instructions["value"] = SYSTEM_PROMPT;

    auto install = service().put(
        "/api/experimental/session/" + g_session_id + "/instructions/entries/jarvis",
        instructions.dump(), 30);

    if (install.status != 200 && install.status != 204) {
        // Не критично: продолжаем без персон
        std::cerr << "warn: instruction entry не сохранён (HTTP "
                  << install.status << ")\n";
    }
}

void ensure_session()
{
    if (!g_session_id.empty()) {

        auto existing = fetch_session(g_session_id);

        if (!existing.is_null()) {
            return;
        }
    }

    create_session();
}

// =====================================
// MODEL SWITCH
// =====================================

void load_default_model()
{
    if (!g_default_model.empty()) {
        return;
    }

    auto resp = service().get("/api/model/default");

    if (resp.status != 200) {
        throw std::runtime_error("Не удалось получить модель по умолчанию (HTTP "
                                 + std::to_string(resp.status) + ")");
    }

    auto doc = data_of(parse_body(resp, "GET /api/model/default"));

    g_default_model = doc.value("modelID", doc.value("id", TEXT_MODEL));

    g_default_provider = doc.value("providerID", PROVIDER);
}

void switch_model(const std::string& provider, const std::string& model)
{
    if (g_active_model_set && g_active_model == model) {
        return;
    }

    nlohmann::json payload;

    payload["model"] = {
        { "id", model },
        { "providerID", provider }
    };

    auto resp = service().post("/api/session/" + g_session_id + "/model", payload.dump(), 30);

    if (resp.status != 200 && resp.status != 204) {
        throw std::runtime_error("Не удалось переключить модель на " + model + " (HTTP "
                                 + std::to_string(resp.status) + ")");
    }

    g_active_model = model;

    g_active_model_set = true;
}

// =====================================
// ANSWER EXTRACT
// =====================================

std::string extract_answer(const nlohmann::json& messages, long long user_created)
{
    const nlohmann::json* best = nullptr;

    long long best_created = -1;

    for (const auto& entry : messages) {

        if (!entry.is_object()) {
            continue;
        }

        if (entry.value("type", std::string()) != "assistant") {
            continue;
        }

        long long created = 0;

        if (entry.contains("time") && entry["time"].contains("created")) {
            created = entry["time"]["created"].get<long long>();
        }

        bool completed = false;

        if (entry.contains("time") && entry["time"].contains("completed")
            && !entry["time"]["completed"].is_null()) {
            completed = true;
        }

        if (!completed || created < user_created || created <= best_created) {
            continue;
        }

        const auto& content = entry.contains("content") ? entry["content"] : nlohmann::json();

        bool has_text = false;

        if (content.is_array()) {
            for (const auto& part : content) {
                if (part.value("type", std::string()) == "text") {
                    has_text = true;
                }
            }
        }

        if (has_text) {
            best = &entry;
            best_created = created;
        }
    }

    if (best == nullptr) {
        return "";
    }

    std::string result;

    const auto& content = (*best)["content"];

    if (content.is_array()) {
        for (const auto& part : content) {
            if (part.value("type", std::string()) == "text") {
                if (!result.empty()) {
                    result += "\n";
                }
                result += part.value("text", std::string());
            }
        }
    }

    return result;
}

} // namespace

// =====================================
// SCREENSHOT PATH
// =====================================

std::string screenshot_path()
{
    namespace chrono = std::chrono;

    auto now = chrono::system_clock::now();

    std::time_t t = chrono::system_clock::to_time_t(now);

    std::tm tm{};

    localtime_r(&t, &tm);

    std::ostringstream stamp;

    stamp << std::put_time(&tm, "%Y-%m-%d_%H-%M-%S");

    std::string dir = working_directory() + "/screens";

    std::error_code ec;

    fs::create_directories(dir, ec);

    if (ec || !fs::is_directory(dir)) {
        dir = "/tmp/jarvis-screens";
        fs::create_directories(dir, ec);
    }

    return dir + "/screen_" + stamp.str() + ".png";
}

// =====================================
// ASK AI
// =====================================

std::string ask_ai(const std::string& prompt, const std::string& image_path)
{
    std::lock_guard<std::mutex> lock(g_mutex);

    ensure_session();

    load_default_model();

    // =====================================
    // ВЫБОР МОДЕЛИ
    // =====================================

    if (!image_path.empty()) {
        switch_model(PROVIDER, VISION_MODEL);
    } else {
        switch_model(g_default_provider, g_default_model);
    }

    // =====================================
    // PROMPT
    // =====================================

    nlohmann::json payload;

    payload["text"] = prompt;

    if (!image_path.empty()) {
        payload["files"] = nlohmann::json::array(
            { nlohmann::json{
                { "uri",
                  file_uri(fs::absolute(fs::path(image_path)).lexically_normal().string()) },
                { "name", basename_of(image_path) } } });
    }

    memory::add_message();

    auto resp = service().post("/api/session/" + g_session_id + "/prompt", payload.dump(), 60);

    if (resp.status != 200) {
        throw std::runtime_error("Не удалось отправить сообщение (HTTP "
                                 + std::to_string(resp.status) + "): " + resp.body.substr(0, 300));
    }

    auto user_message = data_of(parse_body(resp, "POST .../prompt"));

    long long user_created = 0;

    if (user_message.contains("time") && user_message["time"].contains("created")) {
        user_created = user_message["time"]["created"].get<long long>();
    }

    // =====================================
    // WAIT FOR ANSWER
    // =====================================

    auto started = std::chrono::steady_clock::now();

    while (true) {

        std::this_thread::sleep_for(std::chrono::milliseconds(500));

        auto messages_resp = service().get("/api/session/" + g_session_id + "/message", 20);

        if (messages_resp.status != 200) {
            continue;
        }

        auto doc = parse_body(messages_resp, "GET .../message");

        auto answer = extract_answer(data_of(doc), user_created);

        if (!answer.empty()) {
            return answer;
        }

        auto waited = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - started).count();

        if (waited > 240) {
            throw std::runtime_error("Модель не ответила за 4 минуты (проверьте сервис OpenCode)");
        }
    }
}

// =====================================
// MEMORY
// =====================================

void clear_memory()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    std::string old = g_session_id;

    g_session_id.clear();
    g_active_model.clear();
    g_active_model_set = false;

    if (!old.empty()) {
        try {
            service().del("/api/session/" + old, 15);
        } catch (...) {
            // Игнорируем — новая сессия всё равно будет создана
        }
    }
}

int message_count()
{
    return memory::message_count();
}

std::string active_model_label()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_active_model_set && !g_active_model.empty()) {
        return g_active_model;
    }

    if (!g_default_model.empty()) {
        return g_default_model;
    }

    return "OpenCode";
}

// =====================================
// CLEAN AI OUTPUT
// =====================================

namespace {

void replace_all(std::string& text, const std::string& from, const std::string& to)
{
    if (from.empty()) {
        return;
    }

    size_t position = 0;

    while ((position = text.find(from, position)) != std::string::npos) {
        text.replace(position, from.size(), to);
        position += to.size();
    }
}

std::string trim_spaces(std::string text)
{
    size_t begin = 0;
    size_t end = text.size();

    while (begin < end && std::isspace(static_cast<unsigned char>(text[begin]))) begin++;

    while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1]))) end--;

    return text.substr(begin, end - begin);
}

} // namespace

std::string clean_ai_output(std::string text)
{
    if (text.empty()) {
        return "";
    }

    // **жирный** -> жирный
    size_t position = 0;

    while ((position = text.find("**", position)) != std::string::npos) {

        size_t closing = text.find("**", position + 2);

        if (closing == std::string::npos) {
            break;
        }

        text.erase(closing, 2);
        text.erase(position, 2);
    }

    // \frac{a}{b} -> (a)/(b)
    const std::string frac_prefix = "\\frac{";

    position = 0;

    while ((position = text.find(frac_prefix, position)) != std::string::npos) {

        size_t close_first = text.find('}', position + frac_prefix.size());

        if (close_first == std::string::npos) {
            break;
        }

        if (close_first + 1 >= text.size() || text[close_first + 1] != '{') {
            position = close_first + 1;
            continue;
        }

        size_t close_second = text.find('}', close_first + 2);

        if (close_second == std::string::npos) {
            break;
        }

        std::string numerator = text.substr(
            position + frac_prefix.size(), close_first - (position + frac_prefix.size()));

        std::string denominator = text.substr(
            close_first + 2, close_second - (close_first + 2));

        std::string replacement =
            "(" + numerator + ")/(" + denominator + ")";

        text.replace(position, close_second + 1 - position, replacement);

        position += replacement.size();
    }

    // Оставшиеся слэши LaTeX убираем
    replace_all(text, "\\", "");

    return trim_spaces(text);
}

} // namespace ai
