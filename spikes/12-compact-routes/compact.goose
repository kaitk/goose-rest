// The shorter form, design A, beside the package so that both forms build
// from one tree. routes opens the request's one route around its block, and
// answers 404, 405, 501, and OPTIONS itself when nothing in the block
// answered. get and its kin only match, run their block, and leave routes.
// route opens a route outside routes and joins routes' one inside it.
// Adopted, these would be rest::routes, rest::route, and rest::get and its
// kin.
namespace compact;

import std;
import http;
import rest;

// rest::routes's body, rather than a call to it, so that a return from
// routes crosses the functions it would adopted.
inline fn routes<S, A, F>(cx: rest::Cx<S, A, rest::NoRouter>&) {
    let mark = cx.out.buf.len;
    var r = http::router(cx.req);
    var c = rest::Cx<S, A, http::Router> { req: cx.req, body: cx.body, out: cx.out, state: cx.state,
                       app: cx.app, scratch: cx.scratch,
                       kind: cx.kind, reply: cx.reply, refused: cx.refused, more: cx.more, ex: cx.ex,
                       kept: cx.kept, budget: cx.budget, router: r };
    rest::route(c) {
        F(&c);
        if unanswered(c, mark) { rest::otherwise(c); }
    };
}

// Whether cx's response is still unwritten from mark, with no reply, body,
// or room to send awaited, as serve's settle_kept tells.
fn unanswered(cx, mark: i64) -> bool {
    guard cx.out.buf.len == mark && !cx.out.stream.waiting else { return false; }
    var x .= cx.ex;
    return !(x && (x.mode & rest::LATER) != 0);
}

// A context with a router is inside routes' route, so a route there adds no
// second one: a function that fails returns to the innermost route, and a
// route inside a route keeps both out of line.
inline fn route<S, A, F>(cx: rest::Cx<S, A, rest::NoRouter>&) { rest::route(cx) { F(); }; }
inline fn route<S, A, F>(cx: rest::Cx<S, A, http::Router>&) { F(); }

// The block when the request is method on pattern, then out of routes: the
// statements after it are the else of an if chain. The return has an arm of
// its own: Goose inlines no call in an arm that ends in a return, and a
// function that fails, left a call in the block, keeps routes' route and
// everything around it out of line.
inline fn on<S, A, F>(cx: rest::Cx<S, A, http::Router>&, method: const u8[:], pattern: const u8[:]) {
    let hit = rest::on(cx, method, pattern);
    if hit { F(); }
    if hit { return from routes; }
}

inline fn get<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "GET", pattern) { F(); }; }
inline fn post<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "POST", pattern) { F(); }; }
inline fn put<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "PUT", pattern) { F(); }; }
inline fn patch<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "PATCH", pattern) { F(); }; }
inline fn delete<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "DELETE", pattern) { F(); }; }
