#pragma once

// =====================================
// HTTP CLIENT (libcurl)
// =====================================

#include <string>
#include <vector>
#include <utility>

namespace http {

// Контакт со локальным сервисом OpenCode:
// Basic-аутентификация "opencode:<password>" из service.json
struct Response {

    long status = 0;

    std::string body;
};

// Мок для запросов к локальному сервису OpenCode
class Endpoints {

public:

    Endpoints() = default;

    explicit Endpoints(std::string base_url, std::string user, std::string password)
        : base_url_(std::move(base_url))
        , user_(std::move(user))
        , password_(std::move(password))
    {
    }

    const std::string& base_url() const { return base_url_; }
    const std::string& user() const { return user_; }
    const std::string& password() const { return password_; }

    bool valid() const { return !base_url_.empty() && !password_.empty(); }

    Response post(const std::string& path, const std::string& body, long timeout = 180) const;

    Response put(const std::string& path, const std::string& body, long timeout = 60) const;

    Response get(const std::string& path, long timeout = 30) const;

    Response patch(const std::string& path, const std::string& body, long timeout = 60) const;

    Response del(const std::string& path, long timeout = 30) const;

private:

    Response request(const char* method, const std::string& path,
                     const std::string& body, long timeout) const;

    std::string base_url_;

    std::string user_;

    std::string password_;
};

// Загружает ~/.local/state/opencode/service.json
Endpoints discover_opencode();

// Процентное кодирование для URL (перевод кириллицы, пробелов и т.п.)
std::string url_encode(const std::string& input);

} // namespace http
