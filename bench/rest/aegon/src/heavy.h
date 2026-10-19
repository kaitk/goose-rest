// What tier D's routes share with tier C's: their errors, their bearer
// check, and the times both tiers read and write.

#pragma once

#include <glaze/glaze.hpp>

#include "app.h"
#include "http/Middleware.h"

namespace app::heavy {

// Tiers C's and D's errors, of the status in the body too.
Reply bad_request();
Reply unauthorized();

// The bearer check, as middleware on a route group: 401 without a bearer
// token of three base64url segments (app::has_bearer).
aegon::http::MiddlewareFn bearer();

}  // namespace app::heavy

namespace app {

// A time as ms since the epoch, which JSON gives and takes as toISOString's
// string.
struct Iso {
    int64_t ms{};
};

}  // namespace app

namespace glz {

template <>
struct from<JSON, app::Iso> {
    template <auto Opts>
    static void op(app::Iso& value, is_context auto&& ctx, auto&& it, auto&& end) {
        std::string s;
        parse<JSON>::op<Opts>(s, ctx, it, end);
        if (bool(ctx.error)) return;
        if (auto ms = app::parse_iso(s)) {
            value.ms = *ms;
        } else {
            ctx.error = error_code::syntax_error;
        }
    }
};

template <>
struct to<JSON, app::Iso> {
    template <auto Opts>
    static void op(auto&& value, is_context auto&& ctx, auto&& b, auto&& ix) {
        std::string s = app::iso(value.ms);
        serialize<JSON>::op<Opts>(std::string_view(s), ctx, b, ix);
    }
};

}  // namespace glz
