#pragma once

// =====================================
// EXECUTOR MODULE
// =====================================

#include <string>

namespace executor {

// Разбирает строку вида:
//   ACTION: OPEN_APP: Safari
//   ACTION: OPEN_SITE: youtube.com
//   ACTION: SEARCH_GOOGLE: запрос
// и выполняет соответствующее действие.
// Возвращает сообщение JARVIS или пустую строку,
// если действие не распознано.
std::string execute_ai_action(const std::string& action);

} // namespace executor
