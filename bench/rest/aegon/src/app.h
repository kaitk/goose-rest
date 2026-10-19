// goose-http's REST benchmark tiers on Aegon: the records, the answers, and
// the helpers the tiers share, ported from bench/rest/rust-app's lib.rs, and
// the answer type each route writes into Aegon's Response.
//
//   arena      tier A, HttpArena's production-stack application layer
//   snow       tier B, snowtime's k6 hot path, under /api/v1
//   heavy      tier C, a clinic's schedule and records, under /api/v2
//   writes     tier D, writes with large bodies, under /api/v3, beside C
//   framework  goose-rest's tiers F, R, and M (bench/rest/tiers)
//
// Each tier's file holds its records and answers, and its routes() on
// Aegon's Router, groups, and middleware.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

#include "http/Context.h"
#include "http/Router.h"

namespace app {

// A response: its status, whether its body is JSON, and whether the server
// closes the connection after it, rather than read the rest of a body.
struct Reply {
    uint16_t status = 200;
    bool json = false;
    bool close = false;
    std::string body;

    static Reply empty(uint16_t status) { return {status, false, false, {}}; }
    static Reply json_with(uint16_t status, std::string body) { return {status, true, false, std::move(body)}; }
};

inline Reply json(std::string body) {
    return Reply::json_with(200, std::move(body));
}

// Writes r into the context's Response.
void answer(aegon::http::Context& ctx, Reply r);

enum class Tier { A, B, C, D, F, R, M };

struct Config {
    Tier tier = Tier::A;
    std::string tier_name = "a";
    unsigned workers = 1;
    uint16_t port = 8080;
    // JSON=template: answers from each record's JSON, written once at
    // startup, with the per-request values added.
    bool template_json = false;
    std::string dir;
    std::string routes;
};

// Reads TIER, REST_DATA, JSON, WORKERS, and ROUTES, and the port from the
// first argument, and loads TIER's dataset.
const Config& init(int argc, char** argv);
const Config& config();

constexpr int64_t DAY = 86'400'000;
constexpr int64_t MINUTE = 60'000;

// The time in seconds, and in ms, since the epoch.
uint64_t now_s();
int64_t now_ms();

// dir/name whole, or a stop that says to run goose-http's gen.goose.
std::string read_file(const std::string& dir, std::string_view name);

// id as a record's index, if it's one of n.
inline std::optional<size_t> index_of(uint64_t id, size_t n) {
    if (id >= 1 && id <= n) return id - 1;
    return std::nullopt;
}

// A decimal integer as Rust's str::parse reads one: an optional sign, then
// digits only, within range.
std::optional<int64_t> parse_int(std::string_view s);
std::optional<uint64_t> parse_uint(std::string_view s);

// Whether an Authorization value is a bearer token of three base64url
// segments, as tiers C and D require; the token isn't verified.
bool has_bearer(std::optional<std::string_view> authorization);

// Whether an Authorization value is a bearer token, as tier M requires.
bool is_bearer(std::optional<std::string_view> authorization);

// A form's key or value decoded: '+' as a space, and percent-escapes, or
// nullopt for a '%' without two hex digits after it.
std::optional<std::string> decode_form(std::string_view s);

// Whether body's JSON value, if any, is an object.
bool is_object(std::string_view body);

// Whether body is one JSON value.
bool is_json(std::string_view body);

// ms since the epoch as JavaScript's toISOString writes it.
std::string iso(int64_t ms);

// A time as a JSON string, for a template's splice.
void push_iso(std::string& out, int64_t ms);

// "YYYY-MM-DDTHH:MM:SS.sssZ", or without the milliseconds, as ms since the
// epoch.
std::optional<int64_t> parse_iso(std::string_view s);

// "YYYY-MM-DD" as ms since the epoch at its midnight in UTC.
std::optional<int64_t> parse_day(std::string_view s);

// Howard Hinnant's days_from_civil.
int64_t days_from(int64_t y, int64_t m, int64_t d);

// Writes n as decimal digits onto out.
void push_int(std::string& out, int64_t n);

// A JSON string literal of s, escaped as serde_json escapes it.
void push_string(std::string& out, std::string_view s);

// Each tier's records, loaded by init.
namespace arena {
void load(const std::string& dir, bool template_json);
size_t records();
void routes(aegon::http::Router& router);
Reply not_found();
}

namespace snow {
void load(const std::string& dir, bool template_json);
size_t records();
void routes(aegon::http::Router& router);
// snowtime's 404, for a path under /api/v1 that no route takes.
Reply not_found();
}

namespace heavy {
void load(const std::string& dir, bool template_json);
size_t records();
void routes(aegon::http::Router& router);
// The clinic's 404, for a path under /api/v2 or /api/v3 that no route takes.
Reply not_found();
}

namespace writes {
void routes(aegon::http::Router& router);
}

namespace framework {
void micro(aegon::http::Router& router);
void github(aegon::http::Router& router);
void middleware(aegon::http::Router& router);
}

}  // namespace app
