// A context that carries the worker's state and, for hand-written routes, the
// router, so that a route's functions take cx alone.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";

struct Cx<S, A> {
    req: const http::Request&,
    out: u8[>..]&,
    state: S&,                    // per request
    app: A&,                      // the worker's
    router: http::Router? = null, // set by routes
}

// Runs F(c), c being cx with a router over its request.
inline fn routes<S, A, F>(cx: Cx<S, A>&) {
    var r = http::router(cx.req);
    var c = Cx<S, A> { req: cx.req, out: cx.out, state: cx.state, app: cx.app, router: r };
    F(c);
}

fn on(cx, method: const u8[:], pattern: const u8[:]) -> bool {
    var r .= cx.router;
    guard r else { return false; }
    return http::on(r, method, pattern);
}

fn scope(cx, prefix: const u8[:]) -> bool {
    var r .= cx.router;
    guard r else { return false; }
    return narrowed(r, prefix);
}

fn narrowed(r: http::Router&, prefix: const u8[:]) -> bool {
    let path = r.path;
    guard path.len >= prefix.len && path[..prefix.len] == prefix else { return false; }
    guard path.len == prefix.len || path[prefix.len] == '/' else { return false; }
    r.path = path[prefix.len..];
    return true;
}

fn param(cx, name: const u8[:]) -> const u8[:] {
    let r .= cx.router;
    guard r else { return ""; }
    return http::param(r, name);
}

fn text(cx, status: i32, s: const u8[:]) { format(cx.out, status, " ", s, "\n"); }

// 404, or 405 with the methods of the routes whose path matched.
fn otherwise(cx) {
    let r .= cx.router;
    guard r && r.allow.len > 0 else { text(cx, 404, "not_found"); return; }
    text(cx, 405, str("allow: ", r.allow));
}
