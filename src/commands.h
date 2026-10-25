#pragma once

// =====================================
// COMMANDS MODULE
// =====================================

#include <string>

namespace commands {

// Прямые ключевые команды (ютуб, гугл, сафари, музыка).
// Возвращает ответ JARVIS или пустую строку,
// если команда не распознана.
std::string execute_command(const std::string& raw);

} // namespace commands
