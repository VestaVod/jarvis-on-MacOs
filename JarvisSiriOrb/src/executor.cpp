#include "executor.h"

#include "http.h"

#include <cctype>
#include <cstdio>
#include <string>

namespace {

// =====================================
// HELPERS
// =====================================

std::string strip(const std::string& input)
{
    size_t begin = 0;
    size_t end = input.size();

    while (begin < end && std::isspace(static_cast<unsigned char>(input[begin]))) begin++;

    while (end > begin && std::isspace(static_cast<unsigned char>(input[end - 1]))) end--;

    return input.substr(begin, end - begin);
}

bool starts_with(const std::string& text, const std::string& prefix)
{
    return text.rfind(prefix, 0) == 0;
}

std::string after_prefix(const std::string& text, const std::string& prefix)
{
    return strip(text.substr(prefix.size()));
}

void run(const std::string& command)
{
    std::string detached = command + " &";

    std::system(detached.c_str());
}

void lower_ascii(std::string& text)
{
    for (char& c : text) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
}

} // namespace

namespace executor {

std::string execute_ai_action(const std::string& action)
{
    std::printf("ACTION: %s\n", action.c_str());

    // =========================
    // OPEN_APP
    // =========================

    if (starts_with(action, "ACTION: OPEN_APP:")) {

        std::string app = after_prefix(action, "ACTION: OPEN_APP:");

        int rc = std::system(("open -a '" + app + "' 2>&1").c_str());

        if (rc != 0) {
            std::string site = app;

            lower_ascii(site);

            site += ".com";

            run("open 'https://" + site + "'");

            return app + " не найден. Открываю сайт.";
        }

        return "Открываю " + app;
    }

    // =========================
    // OPEN_SITE
    // =========================

    if (starts_with(action, "ACTION: OPEN_SITE:")) {

        std::string site = after_prefix(action, "ACTION: OPEN_SITE:");

        if (!starts_with(site, "http")) {
            site = "https://" + site;
        }

        run("open '" + site + "'");

        return "Открываю " + site;
    }

    // =========================
    // SEARCH_GOOGLE
    // =========================

    if (starts_with(action, "ACTION: SEARCH_GOOGLE:")) {

        std::string query = after_prefix(action, "ACTION: SEARCH_GOOGLE:");

        std::string url = "https://google.com/search?q=" + http::url_encode(query);

        run("open '" + url + "'");

        return "Ищу в Google: " + query;
    }

    return "";
}

} // namespace executor
