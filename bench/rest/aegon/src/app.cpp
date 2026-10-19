#include "app.h"

#include <charconv>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <limits>
#include <thread>

#include <glaze/glaze.hpp>

namespace app {

namespace {

Config cfg;

std::string env(const char* name, const char* fallback) {
    const char* v = std::getenv(name);
    return v ? v : fallback;
}

bool is_base64url(std::string_view s) {
    if (s.empty()) return false;
    for (char c : s) {
        bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_';
        if (!ok) return false;
    }
    return true;
}

int hex(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

void digits(char* b, size_t n, int64_t v) {
    for (size_t i = n; i-- > 0;) {
        b[i] = static_cast<char>('0' + v % 10);
        v /= 10;
    }
}

int64_t number_at(std::string_view s, size_t at, size_t n) {
    int64_t v = 0;
    for (size_t i = at; i < at + n; ++i) {
        if (s[i] < '0' || s[i] > '9') return -1;
        v = v * 10 + (s[i] - '0');
    }
    return v;
}

int64_t div_floor(int64_t a, int64_t b) {
    int64_t q = a / b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}

}  // namespace

void answer(aegon::http::Context& ctx, Reply r) {
    auto& res = ctx.res();
    res.status(r.status);
    if (r.json) res.header("Content-Type", "application/json");
    if (r.close) res.header("Connection", "close");
    res.body(std::move(r.body));
}

const Config& init(int argc, char** argv) {
    cfg.dir = env("REST_DATA", "build/rest");
    cfg.tier_name = env("TIER", "a");
    const std::string& t = cfg.tier_name;
    if (t == "a") cfg.tier = Tier::A;
    else if (t == "b") cfg.tier = Tier::B;
    else if (t == "c") cfg.tier = Tier::C;
    else if (t == "d") cfg.tier = Tier::D;
    else if (t == "f") cfg.tier = Tier::F;
    else if (t == "r") cfg.tier = Tier::R;
    else if (t == "m") cfg.tier = Tier::M;
    else {
        std::fprintf(stderr, "TIER is a, b, c, d, f, r, or m\n");
        std::exit(2);
    }
    cfg.template_json = env("JSON", "") == "template";
    cfg.routes = env("ROUTES", "bench/rest/tiers/github.txt");
    cfg.workers = std::max(1u, std::thread::hardware_concurrency());
    if (auto w = parse_uint(env("WORKERS", "")); w && *w > 0) cfg.workers = static_cast<unsigned>(*w);
    if (argc > 1) {
        if (auto p = parse_uint(argv[1]); p && *p <= 65535) cfg.port = static_cast<uint16_t>(*p);
    }
    size_t records = 0;
    switch (cfg.tier) {
    case Tier::A:
    case Tier::M:
        arena::load(cfg.dir, cfg.template_json);
        records = arena::records();
        break;
    case Tier::B:
        snow::load(cfg.dir, cfg.template_json);
        records = snow::records();
        break;
    case Tier::C:
    case Tier::D:
        heavy::load(cfg.dir, cfg.template_json);
        records = heavy::records();
        break;
    case Tier::F:
    case Tier::R:
        break;
    }
    std::printf("rest-aegon: tier %s, %zu records, %u workers on port %u, %s\n", t.c_str(), records, cfg.workers,
                cfg.port, cfg.template_json ? "template" : "serialize");
    std::fflush(stdout);
    return cfg;
}

const Config& config() {
    return cfg;
}

uint64_t now_s() {
    using namespace std::chrono;
    return static_cast<uint64_t>(duration_cast<seconds>(system_clock::now().time_since_epoch()).count());
}

int64_t now_ms() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

std::string read_file(const std::string& dir, std::string_view name) {
    std::string path = dir + "/" + std::string(name);
    std::ifstream f(path, std::ios::binary);
    if (!f) {
        std::fprintf(stderr, "%s: can't read; run goose-http's bench/rest/gen.goose\n", path.c_str());
        std::exit(1);
    }
    return std::string(std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>());
}

std::optional<int64_t> parse_int(std::string_view s) {
    bool negative = false;
    if (!s.empty() && (s[0] == '+' || s[0] == '-')) {
        negative = s[0] == '-';
        s.remove_prefix(1);
    }
    if (s.empty()) return std::nullopt;
    uint64_t v = 0;
    for (char c : s) {
        if (c < '0' || c > '9') return std::nullopt;
        if (v > (std::numeric_limits<uint64_t>::max() - (c - '0')) / 10) return std::nullopt;
        v = v * 10 + static_cast<uint64_t>(c - '0');
    }
    constexpr uint64_t max = static_cast<uint64_t>(std::numeric_limits<int64_t>::max());
    if (negative) {
        if (v > max + 1) return std::nullopt;
        return static_cast<int64_t>(0 - v);
    }
    if (v > max) return std::nullopt;
    return static_cast<int64_t>(v);
}

std::optional<uint64_t> parse_uint(std::string_view s) {
    if (!s.empty() && s[0] == '+') s.remove_prefix(1);
    if (s.empty()) return std::nullopt;
    uint64_t v = 0;
    for (char c : s) {
        if (c < '0' || c > '9') return std::nullopt;
        if (v > (std::numeric_limits<uint64_t>::max() - (c - '0')) / 10) return std::nullopt;
        v = v * 10 + static_cast<uint64_t>(c - '0');
    }
    return v;
}

bool has_bearer(std::optional<std::string_view> authorization) {
    if (!authorization || !authorization->starts_with("Bearer ")) return false;
    std::string_view t = authorization->substr(7);
    size_t a = t.find('.');
    if (a == std::string_view::npos) return false;
    size_t b = t.find('.', a + 1);
    if (b == std::string_view::npos) return false;
    return is_base64url(t.substr(0, a)) && is_base64url(t.substr(a + 1, b - a - 1)) && is_base64url(t.substr(b + 1));
}

bool is_bearer(std::optional<std::string_view> authorization) {
    return authorization && authorization->starts_with("Bearer ") && authorization->size() > 7;
}

std::optional<std::string> decode_form(std::string_view s) {
    std::string out;
    out.reserve(s.size());
    for (size_t i = 0; i < s.size();) {
        if (s[i] == '%') {
            int a = i + 1 < s.size() ? hex(s[i + 1]) : -1;
            int b = i + 2 < s.size() ? hex(s[i + 2]) : -1;
            if (a < 0 || b < 0) return std::nullopt;
            out.push_back(static_cast<char>(a * 16 + b));
            i += 3;
        } else {
            out.push_back(s[i] == '+' ? ' ' : s[i]);
            ++i;
        }
    }
    return out;
}

bool is_object(std::string_view body) {
    size_t i = body.find_first_not_of(" \t\r\n\f");
    return i != std::string_view::npos && body[i] == '{';
}

bool is_json(std::string_view body) {
    return !glz::validate_json(body);
}

std::string iso(int64_t ms) {
    int64_t day = div_floor(ms, DAY);
    int64_t t = ms - day * DAY;
    int64_t z = day + 719'468;
    int64_t era = (z >= 0 ? z : z - 146'096) / 146'097;
    int64_t doe = z - era * 146'097;
    int64_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146'096) / 365;
    int64_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    int64_t mp = (5 * doy + 2) / 153;
    int64_t m = mp < 10 ? mp + 3 : mp - 9;
    std::string b = "0000-00-00T00:00:00.000Z";
    digits(&b[0], 4, yoe + era * 400 + (m <= 2 ? 1 : 0));
    digits(&b[5], 2, m);
    digits(&b[8], 2, doy - (153 * mp + 2) / 5 + 1);
    digits(&b[11], 2, t / 3'600'000);
    digits(&b[14], 2, t / MINUTE % 60);
    digits(&b[17], 2, t / 1000 % 60);
    digits(&b[20], 3, t % 1000);
    return b;
}

void push_iso(std::string& out, int64_t ms) {
    out.push_back('"');
    out.append(iso(ms));
    out.push_back('"');
}

int64_t days_from(int64_t y, int64_t m, int64_t d) {
    int64_t yy = m <= 2 ? y - 1 : y;
    int64_t era = (yy >= 0 ? yy : yy - 399) / 400;
    int64_t yoe = yy - era * 400;
    int64_t doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
    return era * 146'097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719'468;
}

std::optional<int64_t> parse_iso(std::string_view s) {
    size_t n = s.size();
    if (!((n == 24 || n == 20) && s[4] == '-' && s[7] == '-' && s[10] == 'T' && s[13] == ':' && s[16] == ':' &&
          s[n - 1] == 'Z')) {
        return std::nullopt;
    }
    int64_t y = number_at(s, 0, 4), m = number_at(s, 5, 2), d = number_at(s, 8, 2);
    int64_t h = number_at(s, 11, 2), mi = number_at(s, 14, 2), sec = number_at(s, 17, 2);
    int64_t ms = (n == 24 && s[19] == '.') ? number_at(s, 20, 3) : (n == 20 ? 0 : -1);
    bool ok = y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31 && h >= 0 && h < 24 && mi >= 0 && mi < 60 &&
              sec >= 0 && sec < 60 && ms >= 0;
    if (!ok) return std::nullopt;
    return days_from(y, m, d) * DAY + ((h * 60 + mi) * 60 + sec) * 1000 + ms;
}

std::optional<int64_t> parse_day(std::string_view s) {
    if (!(s.size() == 10 && s[4] == '-' && s[7] == '-')) return std::nullopt;
    int64_t y = number_at(s, 0, 4), m = number_at(s, 5, 2), d = number_at(s, 8, 2);
    if (!(y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31)) return std::nullopt;
    return days_from(y, m, d) * DAY;
}

void push_int(std::string& out, int64_t n) {
    char buf[24];
    auto [p, _] = std::to_chars(buf, buf + sizeof buf, n);
    out.append(buf, p);
}

void push_string(std::string& out, std::string_view s) {
    static constexpr char hexdigits[] = "0123456789abcdef";
    out.push_back('"');
    for (char c : s) {
        switch (c) {
        case '"': out.append("\\\""); break;
        case '\\': out.append("\\\\"); break;
        case '\b': out.append("\\b"); break;
        case '\f': out.append("\\f"); break;
        case '\n': out.append("\\n"); break;
        case '\r': out.append("\\r"); break;
        case '\t': out.append("\\t"); break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                out.append("\\u00");
                out.push_back(hexdigits[(c >> 4) & 0xf]);
                out.push_back(hexdigits[c & 0xf]);
            } else {
                out.push_back(c);
            }
        }
    }
    out.push_back('"');
}

}  // namespace app
