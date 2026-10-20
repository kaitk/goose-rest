// The shorter form, beside the package so that both forms build from one
// tree: routes that answer 404, 405, 501, and OPTIONS themselves when no
// route answered, and a call per method that matches a route and opens it.
// Adopted, these would be rest::routes itself and rest::get and its kin.
namespace compact;

import std;
import http;
import rest;

// rest::routes, then rest::otherwise if nothing in F answered or waits for
// a later call. A route that matched leaves through return from routes, and
// never gets here.
inline fn routes<S, A, F>(cx: rest::Cx<S, A, rest::NoRouter>&) {
    let mark = cx.out.buf.len;
    rest::routes(cx) { cx =>
        F(cx);
        if unanswered(cx, mark) { rest::otherwise(cx); }
    };
}

// Whether cx's response is still unwritten from mark, with no reply, body,
// or room to send awaited, as serve's settle_kept tells.
fn unanswered(cx, mark: i64) -> bool {
    guard cx.out.buf.len == mark && !cx.out.stream.waiting else { return false; }
    var x .= cx.ex;
    return !(x && (x.mode & rest::LATER) != 0);
}

// rest::on and rest::route in one, then out of routes: the statements after
// it are the else of an if chain.
inline fn on<S, A, F>(cx: rest::Cx<S, A, http::Router>&, method: const u8[:], pattern: const u8[:]) {
    if rest::on(cx, method, pattern) {
        rest::route(cx) { F(); };
        return from routes;
    }
}

inline fn get<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "GET", pattern) { F(); }; }
inline fn post<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "POST", pattern) { F(); }; }
inline fn put<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "PUT", pattern) { F(); }; }
inline fn patch<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "PATCH", pattern) { F(); }; }
inline fn delete<S, A, F>(cx: rest::Cx<S, A, http::Router>&, pattern: const u8[:]) { on(cx, "DELETE", pattern) { F(); }; }
