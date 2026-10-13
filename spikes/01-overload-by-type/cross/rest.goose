namespace rest;

import std;

struct Cx { cookie: const u8[:], page: i64 }

// A built-in extractor; the application adds its own as rest::from_request.
struct Query { raw: const u8[:] }
fn from_request(cx: Cx&, v: Query&) { v.raw = "a=1"; }

fn take<T, F>(cx: Cx&) {
    var v = default<T>();
    from_request(cx, v);
    F(v);
}
