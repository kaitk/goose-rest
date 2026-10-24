namespace plod;

import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";

// Between http::start and http::finish, or plod::begin and its first send.
// Validation and serialization are goose-http's; false writes nothing.
fn set_cookie(cx, c: http::Cookie) -> bool { http::set_cookie(cx.out, c) }

// Keep the cookie's original path and domain to remove the same cookie.
fn clear_cookie(cx, var c: http::Cookie) -> bool {
    c.value = "";
    c.max_age = 0;
    c.expires = 0;
    return set_cookie(cx, c);
}
