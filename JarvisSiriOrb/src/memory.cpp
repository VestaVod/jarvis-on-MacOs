#include "memory.h"

#include <mutex>

namespace {

std::mutex g_mutex;

std::string g_active_image;

int g_message_count = 0;

std::string basename_of(const std::string& path)
{
    auto pos = path.find_last_of('/');

    if (pos == std::string::npos) {
        return path;
    }

    return path.substr(pos + 1);
}

} // namespace

namespace memory {

void set_active_image(const std::string& path)
{
    std::lock_guard<std::mutex> lock(g_mutex);

    g_active_image = path;
}

std::string get_active_image()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    return g_active_image;
}

std::string get_active_image_name()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    return basename_of(g_active_image);
}

bool has_active_image()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    return !g_active_image.empty();
}

void add_message()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    g_message_count++;
}

void clear_memory()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    g_active_image.clear();

    g_message_count = 0;
}

int message_count()
{
    std::lock_guard<std::mutex> lock(g_mutex);

    return g_message_count;
}

} // namespace memory
