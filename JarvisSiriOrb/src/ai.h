#pragma once

// =====================================
// AI MODULE
// =====================================
//
// Диалог ведётся через локальный фоновый сервис
// OpenCode (та же сессия сохраняет контекст).
// Free tier доступен только изнутри OpenCode —
// и мы являемся частью OpenCode.
// =====================================

#include <string>

namespace ai {

// Системный промпт JARVIS — регистрируется как
// instruction entry в новой сессии OpenCode.
extern const char* SYSTEM_PROMPT;

// PLAIN TEXT MODEL (по умолчанию)
extern const char* TEXT_MODEL;

// VISION MODEL (для картинок)
extern const char* VISION_MODEL;

// Провайдер локального OpenCode
extern const char* PROVIDER;

// Убедиться, что родительская папка "screens" находится
// рядом с исполняемым файлом / в домашнем каталоге,
// вернуть путь для нового скриншота.
std::string screenshot_path();

// Основной запрос к модели. Возвращает ответ ассистента
// или кидает std::runtime_error с читаемым сообщением.
// Если image_path не пуст — к сессии прикладывается файл
// и сессия переключается на vision модель.
std::string ask_ai(const std::string& prompt, const std::string& image_path = "");

// Сколько сообщений отправлено в текущей сессии
// (локальный счётчик).
int message_count();

// Начать новую сессию (сброс контекста).
void clear_memory();

// Имя активной модели (для статус-бара).
std::string active_model_label();

// Очистка markdown/LaTeX из ответа модели
// (**жирный**, \frac{...}{...}, одиночные слэши).
std::string clean_ai_output(std::string text);

} // namespace ai
