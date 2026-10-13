// The runtime: a request's context, routes that fail from any depth below
// them, and answers in JSON, every error in one shape (README, "Errors").
namespace rest;

import std;
import json;
import http from "github.com/kaitk/goose-http@cfb9c02bd8cd1d841eaf9d140ff0dbd96bb3bcf8";

// A request's context: its head, its body, where its answer goes, the
// application's per-request state, which goose-http keeps in the
// connection's slot and starts from fresh for each request, and scratch
// for what the extractors decode, which lasts until the handler returns.
struct Cx<S> {
    req: const http::Request&,
    body: const u8[:],
    out: http::Reply,
    state: S&,
    scratch: u8[>..]&,
}

// The per-request state of a program that keeps none.
struct NoState { unused: bool = false }

// Serves cfg with goose-http's loop, calling H(cx) for each request once its
// body has come whole. A chunked body too long to come whole is answered 413
// by goose-http.
fn serve<S, H>(cfg: http::Config, fresh: S) -> http::Error {
    return http::serve(cfg, fresh) { ev, st, out =>
        if http::whole_only(ev, out) {
            var scratch: u8[>..] = [];
            var cx = Cx<S> { req: ev.req, body: ev.data, out: out, state: st, scratch: scratch };
            H(cx);
        }
    };
}

fn serve<H>(cfg: http::Config) -> http::Error {
    return serve(cfg, NoState { .. }) { cx => H(cx) };
}

// What fail answers with: challenge, when not empty, goes in a
// WWW-Authenticate field. Its text is owned: a long-distance return can't
// carry a slice of the request (docs/goose-findings.md).
struct Failure { status: i32, at: i64, code: u8[], detail: u8[], challenge: u8[] }

// An empty array when F returned, and the failure when it called fail.
inline fn attempt<F>() -> Failure[] {
    F();
    return [];
}

// Runs F, the route's handler, and answers the failure if it or anything it
// calls fails. The first answer wins: a failure after the handler began a
// response leaves that response as it is. route can't take it back, since
// shrinking the write buffer is refused while a slice of the request is live
// (spec §5.1: a parameter's slices may point into any array of their type).
inline fn route<F>(cx) {
    let mark = cx.out.buf.len;
    let failed = attempt() { F() };
    for f in failed {
        if cx.out.buf.len == mark {
            write_error(cx.out, f.status, f.code, f.detail, f.at, "", f.challenge);
        }
    }
}

// Leaves the enclosing route, which answers status with {"error": code}.
// Every caller runs inside rest::route, or the program doesn't compile.
fn fail(cx, status: i32, code: const u8[:]) {
    return [Failure { status: status, at: -1, code: str(code), detail: "", challenge: "" }] from attempt;
}

// Leaves the enclosing route with 401 {"error": code} and a WWW-Authenticate
// field of challenge, as "Bearer" (RFC 9110 §11.6.1).
fn fail_auth(cx, code: const u8[:], challenge: const u8[:]) {
    return [Failure { status: 401, at: -1, code: str(code), detail: "", challenge: str(challenge) }] from attempt;
}

// Leaves the enclosing route with 400 for a body r couldn't read:
// {"error": "invalid_body", "detail": r's error, "at": where it stopped}.
// A generated reader's errors name the field and the check, as "name:
// maxLength" or "unknown member".
fn fail_body(cx, r: const json::Reader&) {
    return [Failure { status: 400, at: r.error_at, code: str("invalid_body"), detail: str(r.error), challenge: "" }]
        from attempt;
}

// Leaves the enclosing route with 400 for a path parameter that doesn't fit
// its schema: {"error": "invalid_parameter", "detail": detail}, as "id:
// integer" or "id: minimum".
fn fail_param(cx, detail: const u8[:]) {
    return [Failure { status: 400, at: -1, code: str("invalid_parameter"), detail: str(detail), challenge: "" }]
        from attempt;
}

// The JSON body as R(r, scratch), a generated reader, reads it: 415 unless
// the request says it's application/json, and 400 invalid_body for a body
// R refused or one with more after its value. Generated from_request
// overloads call it.
inline fn json_body<R>(cx) {
    guard http::has_type(cx.req, "application/json") else { fail(cx, 415, "unsupported_media_type"); }
    var r = json::reader(cx.body);
    let v = R(&r, cx.scratch);   // a block given the local itself gets a copy of it
    if !json::finish(r) { fail_body(cx, r); }
    v
}

// The segment of path after its '/' at at, and where the segment ends: at
// the next '/', or path.len. The generated routers walk a path with it.
fn segment(path: const u8[:], at: i64) -> const u8[:], i64 {
    var end = at + 1;
    while end < path.len && path[end] != '/' { end++; }
    return path[at + 1..end], end;
}

// Whether seg, still encoded, is the literal lit, as http::on compares them:
// an escape of an unreserved byte matches the byte. plain says the path has
// no '%', so that bytes compare as they are.
fn segment_is(seg: const u8[:], lit: const u8[:], plain: bool) -> bool {
    if plain { return seg == lit; }
    return http::same_segment(lit, seg);
}

// Answers a request whose path matched with a method no route of the path
// takes: OPTIONS with 204 and allow, any other method with 405 and allow.
fn no_method(cx, allow: const u8[:]) {
    if cx.req.method == "OPTIONS" {
        http::start(cx.out, 204);
        http::field(cx.out, "Allow", allow);
        http::finish(cx.out, "", "");
    } else {
        write_error(cx.out, 405, "method_not_allowed", "", -1, allow);
    }
}

// Answers a request whose path no route matched, as otherwise does: an
// unknown method 501, a path with a dot-segment or an escaped control byte
// 400, OPTIONS * 204, and anything else 404.
fn no_route(cx, method: const u8[:], path: const u8[:]) {
    if !http::known_method(method) {
        write_error(cx.out, 501, "not_implemented", "", -1, "");
    } else if !http::is_routable(path) {
        write_error(cx.out, 400, "bad_path", "", -1, "");
    } else if method == "OPTIONS" && path == "*" {
        http::start(cx.out, 204);
        http::finish(cx.out, "", "");
    } else {
        write_error(cx.out, 404, "not_found", "", -1, "");
    }
}

// no_route for a request whose method is known and whose path is routable,
// as the generated routers have checked by then: OPTIONS * 204, and 404.
fn not_found(cx, method: const u8[:], path: const u8[:]) {
    if method == "OPTIONS" && path == "*" {
        http::start(cx.out, 204);
        http::finish(cx.out, "", "");
    } else {
        write_error(cx.out, 404, "not_found", "", -1, "");
    }
}

// Answers status with v as JSON, written by v's format overload, which Goose
// finds in the namespace that declares v's type (spike 07). A string's
// overload is std's, which writes its bytes unquoted: answer a string inside
// an object.
fn json(cx, status: i32, v) {
    var body: u8[>..] = [];
    format(body, v);
    http::start(cx.out, status);
    http::finish(cx.out, "Content-Type: application/json\r\nContent-Length: ", body);
}

// Answers status with s as UTF-8 text.
fn text(cx, status: i32, s: const u8[:]) {
    http::start(cx.out, status);
    http::finish(cx.out, "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", s);
}

// Answers a request no route took, as http::otherwise does, with each error in
// the JSON shape: an unknown method 501 not_implemented, a path the router
// refused 400 bad_path, a path no route matched 404 not_found, and another
// method of a path that did 405 method_not_allowed, with Allow. OPTIONS gets
// 204 with that Allow, or for "*" without one.
fn otherwise(cx, r: const http::Router&) {
    if !http::known_method(r.method) {
        write_error(cx.out, 501, "not_implemented", "", -1, "");
    } else if r.bad {
        write_error(cx.out, 400, "bad_path", "", -1, "");
    } else if r.method == "OPTIONS" && (r.path == "*" || r.allow.len > 0) {
        http::start(cx.out, 204);
        if r.allow.len > 0 { http::field(cx.out, "Allow", r.allow); }
        http::finish(cx.out, "", "");
    } else if r.allow.len == 0 {
        write_error(cx.out, 404, "not_found", "", -1, "");
    } else {
        write_error(cx.out, 405, "method_not_allowed", "", -1, r.allow);
    }
}

// The error shape: {"error": code}, with "detail" when detail isn't empty,
// "at" when at isn't negative, an Allow field when allow isn't empty, and a
// WWW-Authenticate field when challenge isn't.
fn write_error(out: http::Reply, status: i32, code: const u8[:], detail: const u8[:], at: i64,
               allow: const u8[:], challenge: const u8[:] = "") {
    var body: u8[>..] = [];
    body.append("{\"error\":");
    json::format_string(body, code);
    if detail.len > 0 {
        body.append(",\"detail\":");
        json::format_string(body, detail);
    }
    if at >= 0 {
        body.append(",\"at\":");
        format(body, at);
    }
    body.push('}');
    http::start(out, status);
    if allow.len > 0 { http::field(out, "Allow", allow); }
    if challenge.len > 0 { http::field(out, "WWW-Authenticate", challenge); }
    http::finish(out, "Content-Type: application/json\r\nContent-Length: ", body);
}
