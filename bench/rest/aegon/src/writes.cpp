// Tier D, writes with large bodies, under /api/v3, behind tier C's token,
// answered from the body alone as goose-http's bench/rest/hyper answers them:
//
//   POST  /api/v3/imports                        a CSV: its rows, and each column's count and sum
//   POST  /api/v3/attachments                    multipart: the fields, the file's size and Adler-32
//   POST  /api/v3/bookings/batch                 JSON: each booking's id, or 422 with the errors
//   POST  /api/v3/forms                          a form: its fields, decoded
//
// Aegon reads a body whole, up to the server's 16 MB, before a route runs.
// Each route checks its media type first, then its limit on the declared
// length and on the body, and reads: the CSV in one piece through a port of
// Goose's reader, the multipart body through Aegon's MultipartParser, and the
// batch through glaze.

#include "heavy.h"

#include <array>
#include <charconv>
#include <cmath>
#include <vector>

namespace app::writes {

namespace {

using aegon::http::Context;
using aegon::http::Request;

constexpr size_t IMPORT_LIMIT = 16 << 20;
constexpr size_t ATTACHMENT_LIMIT = 16 << 20;
constexpr size_t BATCH_LIMIT = 1 << 20;
constexpr size_t FORM_LIMIT = 64 << 10;
constexpr size_t MAX_TEXT = 1024;
constexpr size_t MAX_TEXTS = 8;

constexpr std::string_view CSV = "text/csv";
constexpr std::string_view MULTIPART = "multipart/form-data";
constexpr std::string_view JSON = "application/json";
constexpr std::string_view FORM = "application/x-www-form-urlencoded";

Reply unsupported_media_type() {
    return Reply::json_with(415, "{\"error\":\"unsupported_media_type\",\"status\":415}");
}

// 413, closing the connection rather than reading the rest.
Reply too_large() {
    return {413, false, true, {}};
}

bool iequals(std::string_view a, std::string_view b) {
    if (a.size() != b.size()) return false;
    for (size_t i = 0; i < a.size(); ++i) {
        char x = a[i], y = b[i];
        if (x >= 'A' && x <= 'Z') x += 32;
        if (y >= 'A' && y <= 'Z') y += 32;
        if (x != y) return false;
    }
    return true;
}

// Whether a Content-Type's media type is want, ignoring case and parameters.
bool has_type(std::optional<std::string_view> content_type, std::string_view want) {
    if (!content_type) return false;
    std::string_view v = content_type->substr(0, content_type->find(';'));
    size_t a = v.find_first_not_of(" \t"), b = v.find_last_not_of(" \t");
    return a != std::string_view::npos && iequals(v.substr(a, b - a + 1), want);
}

// The route's media type, then its limit on the declared length and on the
// body read: the refusal, if any.
std::optional<Reply> refused(const Request& req, std::string_view type, size_t limit) {
    if (!has_type(req.header("content-type"), type)) return unsupported_media_type();
    if (auto length = req.header("content-length")) {
        if (auto n = parse_uint(*length); n && *n > limit) return too_large();
    }
    if (req.body().size() > limit) return too_large();
    return std::nullopt;
}

// A JSON string of s, its bytes that aren't UTF-8 replaced with U+FFFD, as
// Rust's from_utf8_lossy reads them.
void push_lossy(std::string& out, std::string_view s) {
    std::string clean;
    clean.reserve(s.size());
    auto byte = [&](size_t i) { return static_cast<unsigned char>(s[i]); };
    for (size_t i = 0; i < s.size();) {
        unsigned char c = byte(i);
        size_t n = c < 0x80 ? 1 : (c >> 5) == 6 ? 2 : (c >> 4) == 14 ? 3 : (c >> 3) == 30 ? 4 : 0;
        bool ok = n > 0 && i + n <= s.size();
        for (size_t k = 1; ok && k < n; ++k) ok = (byte(i + k) & 0xc0) == 0x80;
        if (ok && n == 2) ok = c >= 0xc2;
        if (ok && n == 3) {
            unsigned char d = byte(i + 1);
            ok = !(c == 0xe0 && d < 0xa0) && !(c == 0xed && d >= 0xa0);
        }
        if (ok && n == 4) {
            unsigned char d = byte(i + 1);
            ok = c <= 0xf4 && !(c == 0xf0 && d < 0x90) && !(c == 0xf4 && d >= 0x90);
        }
        if (ok) {
            clean.append(s.substr(i, n));
            i += n;
        } else {
            clean.append("\xef\xbf\xbd");
            ++i;
        }
    }
    push_string(out, clean);
}

// An import's columns, of three kinds.
enum class Kind { Text, Int, Dec };

struct Column {
    std::string_view name;
    Kind kind;
};

constexpr std::array<Column, 6> COLUMNS = {{{"id", Kind::Int}, {"date", Kind::Text}, {"account", Kind::Text},
                                            {"description", Kind::Text}, {"quantity", Kind::Int},
                                            {"amount", Kind::Dec}}};

enum class Quote { Outside, Inside, After };

// A CSV body (RFC 4180, with LF or CRLF line ends) read piece by piece, as
// rest.goose's Csv: where the reader is, the field it's in, and each column's
// count of non-empty cells and its sum, or its bytes for text.
struct Csv {
    int64_t record = 1;
    size_t column = 0;
    Quote quote = Quote::Outside;
    bool closed = false;
    bool cr = false;
    size_t len = 0;
    int64_t value = 0;
    bool neg = false;
    int64_t digits = 0;
    int64_t point = -1;
    bool number = true;
    std::string header;
    std::array<int64_t, 6> counts{};
    std::array<int64_t, 6> sums{};
    int64_t bad = 0;

    void fail() {
        if (bad == 0) bad = record;
    }

    void text(std::string_view s) {
        size_t before = len;
        len += s.size();
        if (record == 1) {
            if (header.size() + s.size() <= 16) header.append(s);
            return;
        }
        if (column >= COLUMNS.size()) return;
        Kind kind = COLUMNS[column].kind;
        if (kind == Kind::Text) return;
        for (size_t i = 0; i < s.size(); ++i) {
            char ch = s[i];
            if (ch >= '0' && ch <= '9') {
                if (digits < 18) {
                    value = value * 10 + (ch - '0');
                } else {
                    number = false;
                }
                ++digits;
                if (point >= 0) ++point;
            } else if (ch == '-' && before + i == 0) {
                neg = true;
            } else if (ch == '.' && kind == Kind::Dec && point < 0 && digits > 0) {
                point = 0;
            } else {
                number = false;
            }
        }
    }

    void field_end() {
        size_t k = column;
        if (k >= COLUMNS.size()) {
            fail();
        } else if (record == 1) {
            if (len > 16 || header != COLUMNS[k].name) fail();
        } else if (len > 0) {
            Kind kind = COLUMNS[k].kind;
            if (kind == Kind::Text) {
                ++counts[k];
                sums[k] += static_cast<int64_t>(len);
            } else if (number && digits > 0 && (kind == Kind::Dec ? point == 2 : point < 0)) {
                ++counts[k];
                sums[k] += neg ? -value : value;
            } else {
                fail();
            }
        }
        ++column;
        len = 0;
        value = 0;
        neg = false;
        digits = 0;
        point = -1;
        number = true;
        closed = false;
        header.clear();
    }

    void record_end() {
        field_end();
        if (column != COLUMNS.size()) fail();
        ++record;
        column = 0;
    }

    void piece(std::string_view p) {
        size_t i = 0;
        while (i < p.size() && bad == 0) {
            char ch = p[i];
            if (quote == Quote::Inside) {
                size_t q = p.find('"', i);
                if (q == std::string_view::npos) {
                    text(p.substr(i));
                    return;
                }
                text(p.substr(i, q - i));
                quote = Quote::After;
                i = q + 1;
                continue;
            }
            if (quote == Quote::After) {
                quote = Quote::Outside;
                if (ch == '"') {
                    text(p.substr(i, 1));
                    quote = Quote::Inside;
                    ++i;
                    continue;
                }
                closed = true;
            }
            if (cr) {
                cr = false;
                if (ch != '\n') {
                    fail();
                    return;
                }
            }
            if (ch == ',') {
                field_end();
                ++i;
            } else if (ch == '\n') {
                record_end();
                ++i;
            } else if (ch == '\r') {
                cr = true;
                ++i;
            } else if (closed || (ch == '"' && len > 0)) {
                fail();
            } else if (ch == '"') {
                quote = Quote::Inside;
                ++i;
            } else {
                size_t j = p.find_first_of(",\n\r\"", i + 1);
                if (j == std::string_view::npos) j = p.size();
                text(p.substr(i, j - i));
                i = j;
            }
        }
    }

    void end() {
        if (bad != 0) return;
        if (quote == Quote::Inside || cr) {
            fail();
            return;
        }
        if (quote == Quote::After || closed || column > 0 || len > 0) record_end();
        if (record == 1) fail();
    }
};

void push_cents(std::string& out, int64_t v) {
    uint64_t a = v < 0 ? 0 - static_cast<uint64_t>(v) : static_cast<uint64_t>(v);
    if (v < 0) out.push_back('-');
    out.append(std::to_string(a / 100));
    out.push_back('.');
    out.push_back(static_cast<char>('0' + a % 100 / 10));
    out.push_back(static_cast<char>('0' + a % 10));
}

Reply import(std::string_view body) {
    Csv c;
    c.piece(body);
    c.end();
    if (c.bad != 0) {
        std::string b = "{\"error\":\"bad_csv\",\"record\":";
        push_int(b, c.bad);
        b.push_back('}');
        return Reply::json_with(400, std::move(b));
    }
    std::string b = "{\"rows\":";
    push_int(b, c.record - 2);
    b.append(",\"columns\":[");
    for (size_t k = 0; k < COLUMNS.size(); ++k) {
        if (k > 0) b.push_back(',');
        b.append("{\"name\":\"");
        b.append(COLUMNS[k].name);
        b.append("\",\"count\":");
        push_int(b, c.counts[k]);
        switch (COLUMNS[k].kind) {
        case Kind::Text:
            b.append(",\"bytes\":");
            push_int(b, c.sums[k]);
            break;
        case Kind::Int:
            b.append(",\"sum\":");
            push_int(b, c.sums[k]);
            break;
        case Kind::Dec:
            b.append(",\"sum\":");
            push_cents(b, c.sums[k]);
            break;
        }
        b.push_back('}');
    }
    b.append("]}");
    return Reply::json_with(201, std::move(b));
}

// Adler-32 (RFC 1950), deferring the modulo as zlib does.
uint32_t adler32(std::string_view data) {
    uint32_t a = 1, b = 0;
    for (size_t at = 0; at < data.size(); at += 5552) {
        for (char c : data.substr(at, 5552)) {
            a += static_cast<unsigned char>(c);
            b += a;
        }
        a %= 65521;
        b %= 65521;
    }
    return (b << 16) | a;
}

// POST /api/v3/attachments: a multipart body of text fields and one file,
// as Aegon's MultipartParser hands over its parts. The parser takes a body
// without its close delimiter, so that's checked first.
Reply attachment(const Request& req) {
    std::string_view body = req.body();
    std::string_view boundary =
        aegon::http::MultipartParser::extract_boundary(req.header("content-type").value_or(""));
    std::string close = "--" + std::string(boundary) + "--";
    if (boundary.empty() || body.find(close) == std::string_view::npos) return heavy::bad_request();
    auto form = req.multipart();
    if (!form) return heavy::bad_request();
    if (form->fields().size() > MAX_TEXTS || form->files().size() > 1) return heavy::bad_request();
    std::string fields;
    for (size_t k = 0; k < form->fields().size(); ++k) {
        const auto& f = form->fields()[k];
        if (f.name.size() > 64 || f.value.size() > MAX_TEXT) return heavy::bad_request();
        if (k > 0) fields.push_back(',');
        push_lossy(fields, f.name);
        fields.push_back(':');
        push_lossy(fields, f.value);
    }
    if (form->files().empty()) {
        return Reply::json_with(422, "{\"error\":\"invalid\",\"errors\":[{\"field\":\"file\",\"message\":\"is required\"}]}");
    }
    const auto& f = form->files()[0];
    if (f.name.size() > 64 || f.filename.size() > 256 || f.content_type.size() > 128) return heavy::bad_request();
    std::string b = "{\"fields\":{";
    b.append(fields);
    b.append("},\"file\":{\"field\":");
    push_lossy(b, f.name);
    b.append(",\"filename\":");
    push_lossy(b, f.filename);
    b.append(",\"contentType\":");
    push_lossy(b, f.content_type);
    b.append(",\"size\":");
    push_int(b, static_cast<int64_t>(f.size()));
    b.append(",\"adler32\":");
    push_int(b, adler32(f.data));
    b.append("}}");
    return Reply::json_with(201, std::move(b));
}

// A batch's members, and a booking's, each kept as its JSON text and checked
// by hand, so that each wrong one is a field error rather than a failed parse.
struct Batch {
    std::optional<glz::raw_json> batchId;
    std::optional<glz::raw_json> bookings;
};

struct BookingIn {
    std::optional<glz::raw_json> clientId;
    std::optional<glz::raw_json> staffId;
    std::optional<glz::raw_json> service;
    std::optional<glz::raw_json> start;
    std::optional<glz::raw_json> end;
    std::optional<glz::raw_json> room;
    std::optional<glz::raw_json> note;
};

struct ReadOpts : glz::opts {
    bool validate_trailing_whitespace = true;
};

constexpr ReadOpts READ{{.error_on_unknown_keys = false}};

// How a booking's member read: absent, wrong, or fine.
enum class How { Absent, Wrong, Fine };

// An integer from lo to hi: a JSON number with no fraction.
How int_member(const std::optional<glz::raw_json>& v, double lo, double hi) {
    if (!v) return How::Absent;
    std::string_view t = v->str;
    if (t.empty() || !(t[0] == '-' || (t[0] >= '0' && t[0] <= '9'))) return How::Wrong;
    double n = 0;
    auto [p, ec] = std::from_chars(t.data(), t.data() + t.size(), n);
    if (ec != std::errc() || p != t.data() + t.size()) return How::Wrong;
    return n >= lo && n <= hi && n == std::trunc(n) ? How::Fine : How::Wrong;
}

std::optional<std::string> string_member(const glz::raw_json& v) {
    if (!v.str.starts_with('"')) return std::nullopt;
    std::string s;
    if (glz::read<READ>(s, v.str)) return std::nullopt;
    return s;
}

bool is_service(std::string_view s) {
    size_t d = s.find('-');
    if (d == std::string_view::npos || d < 2 || d > 4 || s.size() != d + 3) return false;
    for (size_t i = 0; i < d; ++i) {
        if (s[i] < 'A' || s[i] > 'Z') return false;
    }
    return s[d + 1] >= '0' && s[d + 1] <= '9' && s[d + 2] >= '0' && s[d + 2] <= '9';
}

std::pair<How, int64_t> time_member(const std::optional<glz::raw_json>& v) {
    if (!v) return {How::Absent, 0};
    auto s = string_member(*v);
    auto t = s ? parse_iso(*s) : std::nullopt;
    if (!t) return {How::Wrong, 0};
    return {How::Fine, *t};
}

void booking_error(std::string& errors, size_t k, std::string_view field, std::string_view message) {
    if (!errors.empty()) errors.push_back(',');
    errors.append("{\"index\":");
    push_int(errors, static_cast<int64_t>(k));
    errors.append(",\"field\":\"");
    errors.append(field);
    errors.append("\",\"message\":\"");
    errors.append(message);
    errors.append("\"}");
}

void check_field(std::string& errors, size_t k, How how, std::string_view field, std::string_view message) {
    if (how == How::Absent) booking_error(errors, k, field, "is required");
    if (how == How::Wrong) booking_error(errors, k, field, message);
}

// POST /bookings/batch: each booking's id, the batch's id and its number,
// and their minutes, or 422 with each field that doesn't validate.
Reply batch(std::string_view body) {
    if (!is_object(body)) return heavy::bad_request();
    Batch b;
    if (glz::read<READ>(b, body)) return heavy::bad_request();
    auto id = b.batchId ? string_member(*b.batchId) : std::nullopt;
    if (!id || id->empty() || id->size() > 64) return heavy::bad_request();
    if (!b.bookings || !b.bookings->str.starts_with('[')) return heavy::bad_request();
    std::vector<glz::raw_json> list;
    if (glz::read<READ>(list, b.bookings->str)) return heavy::bad_request();
    std::string errors;
    int64_t minutes = 0;
    for (size_t k = 0; k < list.size(); ++k) {
        BookingIn x;
        if (!list[k].str.starts_with('{') || glz::read<READ>(x, list[k].str)) {
            booking_error(errors, k, "booking", "must be an object");
            continue;
        }
        check_field(errors, k, int_member(x.clientId, 1, 1'000'000), "clientId",
                    "must be an integer from 1 to 1000000");
        check_field(errors, k, int_member(x.staffId, 1, 10), "staffId", "must be an integer from 1 to 10");
        How service = How::Absent;
        if (x.service) {
            auto s = string_member(*x.service);
            service = s && is_service(*s) ? How::Fine : How::Wrong;
        }
        check_field(errors, k, service, "service", "must be a service code");
        auto [start, from] = time_member(x.start);
        auto [end, to] = time_member(x.end);
        check_field(errors, k, start, "start", "must be an ISO 8601 time");
        check_field(errors, k, end, "end", "must be an ISO 8601 time");
        if (start == How::Fine && end == How::Fine && (to <= from || to - from > 8 * 3'600'000)) {
            booking_error(errors, k, "end", "must be after start, by at most 8 hours");
        }
        check_field(errors, k, int_member(x.room, 1, 6), "room", "must be an integer from 1 to 6");
        How note = How::Fine;
        if (x.note && x.note->str != "null") {
            auto s = string_member(*x.note);
            note = s && s->size() <= 500 ? How::Fine : How::Wrong;
        }
        check_field(errors, k, note, "note", "must be a string of at most 500 bytes");
        minutes += (to - from) / MINUTE;
    }
    if (!errors.empty()) {
        return Reply::json_with(422, "{\"error\":\"invalid\",\"errors\":[" + errors + "]}");
    }
    std::string out = "{\"batchId\":";
    push_string(out, *id);
    out.append(",\"count\":");
    push_int(out, static_cast<int64_t>(list.size()));
    out.append(",\"minutes\":");
    push_int(out, minutes);
    out.append(",\"ids\":[");
    for (size_t k = 0; k < list.size(); ++k) {
        if (k > 0) out.push_back(',');
        push_string(out, *id + "-" + std::to_string(k + 1));
    }
    out.append("]}");
    return Reply::json_with(201, std::move(out));
}

// POST /forms: the form's fields, decoded, in order.
Reply form(std::string_view body) {
    std::string b = "{\"fields\":{";
    int64_t n = 0;
    while (!body.empty()) {
        size_t amp = body.find('&');
        std::string_view pair = body.substr(0, amp);
        body = amp == std::string_view::npos ? std::string_view{} : body.substr(amp + 1);
        if (pair.empty()) continue;
        size_t eq = pair.find('=');
        auto k = decode_form(pair.substr(0, eq));
        auto v = decode_form(eq == std::string_view::npos ? std::string_view{} : pair.substr(eq + 1));
        if (!k || !v) return heavy::bad_request();
        if (n > 0) b.push_back(',');
        push_lossy(b, *k);
        b.push_back(':');
        push_lossy(b, *v);
        ++n;
    }
    b.append("},\"count\":");
    push_int(b, n);
    b.push_back('}');
    return Reply::json_with(200, std::move(b));
}

}  // namespace

void routes(aegon::http::Router& router) {
    auto v3 = router.group("/api/v3");
    v3.use(heavy::bearer());
    v3.post("/imports", [](Context& ctx) {
        auto r = refused(ctx.req(), CSV, IMPORT_LIMIT);
        answer(ctx, r ? std::move(*r) : import(ctx.req().body()));
    });
    v3.post("/attachments", [](Context& ctx) {
        auto r = refused(ctx.req(), MULTIPART, ATTACHMENT_LIMIT);
        answer(ctx, r ? std::move(*r) : attachment(ctx.req()));
    });
    v3.post("/bookings/batch", [](Context& ctx) {
        auto r = refused(ctx.req(), JSON, BATCH_LIMIT);
        answer(ctx, r ? std::move(*r) : batch(ctx.req().body()));
    });
    v3.post("/forms", [](Context& ctx) {
        auto r = refused(ctx.req(), FORM, FORM_LIMIT);
        answer(ctx, r ? std::move(*r) : form(ctx.req().body()));
    });
}

}  // namespace app::writes
