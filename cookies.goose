namespace rest;

import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";

// Between http::start and http::finish, or rest::begin and its first send.
// Validation and serialization are goose-http's; false writes nothing.
fn set_cookie(cx, c: http::Cookie) -> bool { http::set_cookie(cx.out, c) }

// Keep the cookie's original path and domain to remove the same cookie.
fn clear_cookie(cx, var c: http::Cookie) -> bool {
    c.value = "";
    c.max_age = 0;
    c.expires = 0;
    return set_cookie(cx, c);
}
