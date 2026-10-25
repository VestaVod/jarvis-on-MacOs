#pragma once

// =====================================
// SPEECH MODULE (_objc bridge)
// =====================================
//
// Озвучка: macOS `say`
// Распознавание: Apple Speech Framework
// =====================================

#include <functional>
#include <string>

namespace speech {

// Асинхронно произнести текст (не блокирует поток).
void speak(const std::string& text);

// Остановить текущую озвучку.
void stop_speaking();

// Начать слушать микрофон. Колбэк вызывается на главном
// потоке когда фраза распознана (пауза ~2 секунды) либо
// когда пользователь остановил вручную. Пустая строка =
// ничего не распознано.
void start_listening(std::function<void(const std::string&)> on_text);

// Остановить распознавание вручную (доставит то, что уже расслышано).
void stop_listening();

// Сейчас микрофон активен?
bool is_listening();

} // namespace speech
