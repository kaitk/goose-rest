// The shorter form, design B, beside the package. routes opens no route.
// route hands its block a context whose router is marked, Routed, and get
// and its kin are overloaded on the context: given routes' context, they
// match, open a route, and leave routes; given a route's, they match, run
// their block, and leave the route. Every call that reads the router takes
// both contexts. Adopted, these would be plod's own.
namespace marked;

import std;
import http;
import plod;

// The router of a context inside a route.
struct Routed { router: http::Router& }

// plod::routes's body, rather than a call to it, so that a return from
// routes crosses the functions it would adopted.
inline fn routes<S, A, F>(cx: plod::Cx<S, A, plod::NoRouter>&) {
    let mark = cx.out.buf.len;
    var r = http::router(cx.req);
    var c = plod::Cx<S, A, http::Router> { req: cx.req, body: cx.body, out: cx.out, state: cx.state,
                       app: cx.app, scratch: cx.scratch,
                       kind: cx.kind, reply: cx.reply, refused: cx.refused, more: cx.more, ex: cx.ex,
                       kept: cx.kept, router: r };
    F(&c);
    if unanswered(c, mark) { plod::otherwise(c); }
}

// Whether cx's response is still unwritten from mark, with no reply, body,
// or room to send awaited, as serve's settle_kept tells.
fn unanswered(cx, mark: i64) -> bool {
    guard cx.out.buf.len == mark && !cx.out.stream.waiting else { return false; }
    var x .= cx.ex;
    return !(x && (x.mode & plod::LATER) != 0);
}

// plod::route, handing F a context with the router marked. Inside a route,
// F gets the route's context, and no second route opens. plod::route's
// body, rather than a call to it, so that the route is one function, as it
// would be adopted.
inline fn route<S, A, F>(cx: plod::Cx<S, A, http::Router>&) {
    var m = Routed { router: cx.router };
    var c = plod::Cx<S, A, Routed> { req: cx.req, body: cx.body, out: cx.out, state: cx.state,
                       app: cx.app, scratch: cx.scratch,
                       kind: cx.kind, reply: cx.reply, refused: cx.refused, more: cx.more, ex: cx.ex,
                       kept: cx.kept, router: m };
    let mark = c.out.buf.len;
    let failed = plod::attempt() { F(&c); };
    for f in failed {
        if f.status == 0 {
        } else if c.out.stream.open {
            c.out.stream.open = false;
            c.out.keep_alive = false;
        } else if c.out.buf.len == mark {
            plod::write_error(c.out, c.state, f.status, f.code, f.detail, f.at, "", f.challenge,
                              if f.retry { plod::RETRY_AFTER } else { "" });
        }
    }
}

inline fn route<S, A, F>(cx: plod::Cx<S, A, Routed>&) { F(cx); }

inline fn route<S, A, F>(cx: plod::Cx<S, A, plod::NoRouter>&) { plod::route(cx) { F(cx); }; }

// Outside a route: the block in a route of its own, then out of routes. The
// return has an arm of its own: Goose inlines no call in an arm that ends
// in a return (docs/goose-findings.md).
inline fn on<S, A, F>(cx: plod::Cx<S, A, http::Router>&, method: const u8[:], pattern: const u8[:]) {
    let hit = plod::on(cx, method, pattern);
    if hit { plod::route(cx) { F(); }; }
    if hit { return from routes; }
}

// Inside a route: the block, then out of the route, back in routes' block,
// which finds the answer written.
inline fn on<S, A, F>(cx: plod::Cx<S, A, Routed>&, method: const u8[:], pattern: const u8[:]) {
    let hit = http::on(cx.router.router, method, pattern);
    if hit { F(); }
    if hit { return [] from plod::attempt; }
}

inline fn get<S, A, R, F>(cx: plod::Cx<S, A, R>&, pattern: const u8[:]) { on(cx, "GET", pattern) { F(); }; }
inline fn post<S, A, R, F>(cx: plod::Cx<S, A, R>&, pattern: const u8[:]) { on(cx, "POST", pattern) { F(); }; }
inline fn put<S, A, R, F>(cx: plod::Cx<S, A, R>&, pattern: const u8[:]) { on(cx, "PUT", pattern) { F(); }; }
inline fn patch<S, A, R, F>(cx: plod::Cx<S, A, R>&, pattern: const u8[:]) { on(cx, "PATCH", pattern) { F(); }; }
inline fn delete<S, A, R, F>(cx: plod::Cx<S, A, R>&, pattern: const u8[:]) { on(cx, "DELETE", pattern) { F(); }; }

// The calls that read the router, for a route's context. plod's own take
// routes' context.
fn scope<S, A>(cx: plod::Cx<S, A, Routed>&, prefix: const u8[:]) -> bool {
    return plod::narrowed(cx.router.router, prefix);
}

fn param<S, A>(cx: plod::Cx<S, A, Routed>&, name: const u8[:]) -> const u8[:] {
    return plod::param(cx, cx.router.router, name);
}

fn param_int<S, A>(cx: plod::Cx<S, A, Routed>&, name: const u8[:]) -> i64 {
    return plod::param_int(cx, cx.router.router, name);
}

fn otherwise<S, A>(cx: plod::Cx<S, A, Routed>&) { plod::otherwise(cx, cx.router.router); }
