#include "commands.h"

#include <cctype>

namespace {

// =====================================
// LOWERCASE (UTF-8, включая кириллицу)
// =====================================

std::string to_lower_utf8(const std::string& input)
{
    std::string out;

    for (size_t i = 0; i < input.size(); ) {

        unsigned char c = static_cast<unsigned char>(input[i]);

        // ASCII
        if (c < 0x80) {
            out.push_back(static_cast<char>(std::tolower(c)));
            i++;
            continue;
        }

        // Кириллица в UTF-8: 0xD0/0xD1 + второй байт
        if (c == 0xD0 && i + 1 < input.size()) {

            unsigned char next = static_cast<unsigned char>(input[i + 1]);

            if (next >= 0x90 && next <= 0x9F) {          // А-П -> а-п
                out.push_back(static_cast<char>(0xD0));
                out.push_back(static_cast<char>(next + 0x20));
                i += 2;
                continue;
            }

            if (next >= 0xA0 && next <= 0xAF) {          // Р-Я -> ^р-я
                out.push_back(static_cast<char>(0xD1));
                out.push_back(static_cast<char>(next - 0x20));
                i += 2;
                continue;
            }

            if (next == 0x81) {                          // Ё -> ё
                out.push_back(static_cast<char>(0xD1));  // 0x451: D1 91
                out.push_back(static_cast<char>(0x91));
                i += 2;
                continue;
            }
        }

        out.push_back(input[i]);
        i++;
    }

    return out;
}

// =====================================
// RUN COMMANDS
// =====================================

void open_url(const std::string& url)
{
    std::string cmd = "open '" + url + "' &";

    std::system(cmd.c_str());
}

void open_app(const std::string& app)
{
    std::string cmd = "open -a '" + app + "' &";

    std::system(cmd.c_str());
}

bool contains(const std::string& text, const std::string& needle)
{
    return text.find(needle) != std::string::npos;
}

} // namespace

namespace commands {

std::string execute_command(const std::string& raw)
{
    std::string command = to_lower_utf8(raw);

    if (contains(command, "ютуб")) {
        open_url("https://youtube.com");
        return "Открываю YouTube";
    }

    if (contains(command, "гугл")) {
        open_url("https://google.com");
        return "Открываю Google";
    }

    if (contains(command, "сафари")) {
        open_app("Safari");
        return "Открываю Safari";
    }

    if (contains(command, "яндекс музыка")
        || contains(command, "музыка")
        || contains(command, "музло")
        || contains(command, "музыку")
        || contains(command, "песенки")) {
        open_app("Яндекс Музыка");
        return "Врубаю музло сэр";
    }

    return "";
}

} // namespace commands
