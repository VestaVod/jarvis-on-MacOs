// =====================================
// MAIN ENTRY
// =====================================

#include <cstdio>
#include <string>

#include "ai.h"
#include "executor.h"
#include "speech.h"

#include "gui.h"

// =====================================
// CLI MODE (для тестов без GUI)
// =====================================

static int run_cli(int argc, char** argv)
{
    std::string prompt;

    std::string image;

    for (int i = 1; i < argc; i++) {

        std::string argument = argv[i];

        if (argument == "--reset") {
            ai::clear_memory();
            std::printf("Сессия сброшена.\n");
            return 0;
        }

        if (argument == "--image" && i + 1 < argc) {
            image = argv[++i];
            continue;
        }

        if (prompt.empty()) {
            prompt = argument;
        } else {
            prompt += " ";
            prompt += argument;
        }
    }

    if (prompt.empty()) {
        std::printf("Использование: jarvis [--reset] [--image file.png] \"запрос\"\n");
        return 1;
    }

    try {

        std::string response = ai::ask_ai(prompt, image);

        if (response.rfind("ACTION:", 0) == 0) {

            std::string result = executor::execute_ai_action(response);

            std::printf("%s\n", result.c_str());

            return 0;
        }

        std::printf("%s\n", ai::clean_ai_output(response).c_str());

    } catch (const std::exception& error) {
        std::fprintf(stderr, "Ошибка: %s\n", error.what());
        return 1;
    }

    return 0;
}

// =====================================
// MAIN
// =====================================

int main(int argc, char** argv)
{
    if (argc > 1) {
        std::string first = argv[1];
        if (first == "--reset" || first == "--image" || first.rfind("--", 0) != 0) {
            return run_cli(argc, argv);
        }
    }

    gui::run();

    return 0;
}
