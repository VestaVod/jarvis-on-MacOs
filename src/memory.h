#pragma once

// =====================================
// MEMORY CONFIG
// =====================================
//
// Контекст диалога хранит локальный сервис OpenCode
// (внутри его сессии). Здесь только локальная
// статистика и содержимое активной картинки.
// =====================================

#include <string>

namespace memory {

// =====================================
// ACTIVE IMAGE
// =====================================

void set_active_image(const std::string& path);

std::string get_active_image();

std::string get_active_image_name();

bool has_active_image();

// =====================================
// HISTORY
// =====================================

void add_message();

void clear_memory();

int message_count();

} // namespace memory
