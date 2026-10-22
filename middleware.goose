// Middleware: blocks around a group of routes, inlined into the handler
// (spike 04), and prefix scopes over http::router. One rest::route takes a
// request's failures: routes nested in routes keep each other out of line
// (docs/architecture.md, "Middleware and inlining"). So middleware that adds fields
// to every answer, timed and cors, goes outside the route and answers what
// it refuses itself, and checks that fail, as bearer, go inside it.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.5.3";

// Server-Timing as rest::timed writes it before its value, and the spaces it
// leaves for the value.
let TIMING = "Server-Timing: app;dur=";
let TIMING_WIDTH = 12;

// Writes ms into the Server-Timing placeholder of the response begun at mark
// in out's buffer, which follows its status line and the before bytes of
// common before timed's. Nothing for a response written without
// http::start, which has no placeholder there.
fn fill_timing(out: http::Reply, mark: i64, before: i64, ms: const u8[:]) {
    let eol = find(out.buf[mark..], "\r\n");
    guard eol >= 0 else { return; }
    let at = mark + eol + 2 + before + TIMING.len;
    guard at + TIMING_WIDTH <= out.buf.len && out.buf[at - TIMING.len..at] == TIMING else { return; }
    for c, i in ms[..min(ms.len, TIMING_WIDTH)] { out.buf[at + i] = c; }
}

// Cross-origin resource sharing (the Fetch standard's CORS protocol), for
// rest::cors. origins lists the origins allowed, separated by spaces, as
// "https://app.example https://admin.example", or is "*" for any.
struct Cors {
    origins: const u8[:],
    methods: const u8[:] = "GET, HEAD, POST, PUT, PATCH, DELETE",
    headers: const u8[:] = "Authorization, Content-Type",
    expose: const u8[:] = "",
    max_age: i64 = 600,
    credentials: bool = false,
}

// Whether origin is one of list's, separated by spaces, or list is "*".
fn origin_in(list: const u8[:], origin: const u8[:]) -> bool {
    if list == "*" { return true; }
    var found = false;
    each_split(list, ' ') { if it.len > 0 && it == origin { found = true; } };
    return found;
}

// Runs F for a request c allows, with the CORS fields in every answer F
// writes, errors included: they go in cx.out.common, which http::start
// writes after each status line, for as long as F runs. A request without
// Origin, same-origin or not from a browser, runs F as it is. An Origin c
// doesn't list gets 403 origin_not_allowed. A preflight, OPTIONS with
// Access-Control-Request-Method, gets 204 with c's methods, headers, and max
// age, without running F; the browser checks the request against them. A
// route F leaves to answer at a later call keeps the fields with its
// exchange, and serve adds them to that answer (keep_fields). Inside
// rest::routes, F runs in rest::scoped.
//
//   rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) { ... };
inline fn cors<S, A, R, F>(cx: Cx<S, A, R>&, c: Cors) {   // a reference: the block sees the caller's cx.out
    let origin, has_origin = http::field_of(cx.req, "origin");
    let common = cx.out.common;
    let at = cx.scratch.len;
    if has_origin {
        guard origin_in(c.origins, origin) else {
            write_error(cx.out, cx.state, 403, "origin_not_allowed", "", -1, "");
            taken(cx);
            return;
        }
        if cx.req.method == "OPTIONS" {
            let method, preflight = http::field_of(cx.req, "access-control-request-method");
            if preflight {
                answer_preflight(cx.out, c, origin);
                taken(cx);
                return;
            }
        }
        cx.out.common = with_cors(cx.scratch, common, c, origin);
    }
    let mark = cx.out.buf.len;
    scoped(cx) { F(); };
    if has_origin && cx.out.buf.len == mark { keep_fields(cx, at, at + cx.out.common.len); }
    cx.out.common = common;
}

// Keeps the fields the middleware around F adds, cx.out.common, which is
// cx.scratch[from..to], for the answer at a later call, when F left the
// request unanswered for one: a reply it waits for (rest::ask), or a body
// it reads in pieces. The innermost middleware keeps them first, with the
// outer ones' in them. Kept holds offsets, not the slice: the checker can't
// tell that the scratch outlives what cx.kept points to.
fn keep_fields(cx, from: i64, to: i64) {
    var k .= cx.kept;
    guard k && !k.taken && answers_later(cx) else { return; }
    k.from = from;
    k.to = to;
    k.taken = true;
}

// Whether the route waits to answer at a later call, at REQUEST. A body
// left to gather (rest::body) runs the route again, middleware and all,
// once it's whole.
fn answers_later(cx) -> bool {
    guard cx.kind == http::REQUEST else { return false; }
    var x .= cx.ex;
    guard x else { return false; }
    guard (x.mode & GATHERING) == 0 || !cx.more else { return false; }
    return cx.out.stream.waiting || (x.mode & RECEIVING) != 0;
}

// Appends ns as milliseconds with three decimals, as "0.042".
fn format_ms(out: u8[..32]&, ns: i64) {
    let us = ns / 1000;
    format(out, us / 1000, ".");
    let frac = us % 1000;
    if frac < 100 { out.push('0'); }
    if frac < 10 { out.push('0'); }
    format(out, frac);
}

fn answer_preflight(out: http::Reply, c: Cors, origin: const u8[:]) {
    http::start(out, 204);
    http::field(out, "Access-Control-Allow-Origin", origin);
    if c.credentials { http::field(out, "Access-Control-Allow-Credentials", "true"); }
    http::field(out, "Access-Control-Allow-Methods", c.methods);
    if c.headers.len > 0 { http::field(out, "Access-Control-Allow-Headers", c.headers); }
    if c.max_age > 0 {
        var age: u8[..20] = [];
        format(age, c.max_age);
        http::field(out, "Access-Control-Max-Age", age);
    }
    http::field(out, "Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers");
    http::finish(out, http::NO_TYPE, "");
}

// common with the CORS fields of an allowed origin after it, onto scratch,
// which the result points into.
fn with_cors(scratch: u8[>..]&, common: const u8[:], c: Cors, origin: const u8[:]) -> const u8[:] {
    let at = scratch.len;
    scratch.append(common);
    scratch.append("Access-Control-Allow-Origin: ");
    scratch.append(origin);
    scratch.append("\r\n");
    if c.credentials { scratch.append("Access-Control-Allow-Credentials: true\r\n"); }
    if c.expose.len > 0 {
        scratch.append("Access-Control-Expose-Headers: ");
        scratch.append(c.expose);
        scratch.append("\r\n");
    }
    scratch.append("Vary: Origin\r\n");
    return scratch[at..];
}

// Runs F(token) with the request's bearer token (RFC 6750 §2.1), which the
// block checks. A request without one fails with 401 unauthenticated and
// WWW-Authenticate: Bearer. The block refuses a token with invalid_token.
// It goes inside rest::route, as any code that fails does.
inline fn bearer<F>(cx) {
    F(bearer_token(cx));
}

// The request's bearer token, or a failure, 401 unauthenticated with
// WWW-Authenticate: Bearer, as rest::bearer gives it. For a generated
// router's security_<scheme> function.
fn bearer_token(cx) -> const u8[:] {
    let token, found = http::bearer(cx.req);
    guard found else { fail_auth(cx, "unauthenticated", "Bearer"); }
    return token;
}

// Fails the enclosing route with 401 invalid_token and WWW-Authenticate:
// Bearer error="invalid_token", for a bearer token the program refuses.
fn invalid_token(cx) {
    fail_auth(cx, "invalid_token", "Bearer error=\"invalid_token\"");
}

// Runs F, with Server-Timing in its answer, the milliseconds F took, as
// "app;dur=0.042", and, when log is set, writes an access log line to
// standard error: method, target, status, the response's bytes, and the
// milliseconds, as "GET /v1/projects?page=2 200 87 0.042". A route F leaves
// to answer at a later call keeps the field and the start with its
// exchange, and serve fills in the field and writes the line for that
// answer, timed from the request (keep_fields); one that writes no answer
// gets neither. The field goes in cx.out.common, which
// http::start writes after the status line, with TIMING_WIDTH spaces for its
// value, and timed fills them in once F has answered, so that no byte of the
// answer moves. The spaces the value doesn't take are whitespace a field
// value may end in (RFC 9110 §5.5). At a later call, F runs as it is.
// Inside rest::routes, F runs in rest::scoped.
inline fn timed<S, A, R, F>(cx: Cx<S, A, R>&, log: bool = true) {   // a reference, as cors's
    let begun = clock_ns();
    let mark = cx.out.buf.len;
    let common = cx.out.common;
    let first = cx.kind == http::REQUEST;
    let at = cx.scratch.len;
    if first {
        cx.scratch.append(common);
        cx.scratch.append(TIMING);
        cx.scratch.append("            \r\n");
        cx.out.common = cx.scratch[at..];
    }
    scoped(cx) { F(); };
    guard first else { return; }
    if cx.out.buf.len == mark {
        keep_fields(cx, at, at + common.len + TIMING.len + TIMING_WIDTH + 2);
        var k .= cx.kept;
        if k && k.taken {
            k.timed = true;
            k.log = log;
            k.begun = begun;
        }
    }
    cx.out.common = common;
    guard cx.out.buf.len > mark else { return; }
    var ms: u8[..32] = [];
    format_ms(ms, clock_ns() - begun);
    fill_timing(cx.out, mark, common.len, ms);
    if log {
        write_stderr(str(cx.req.method, " ", cx.req.target, " ", cx.out.stream.status, " ", cx.out.buf.len - mark,
                         " ", ms, "\n"));
    }
}

// Whether the request is method on a path pattern matches, as http::on
// takes them, against the router of the rest::routes block around it, the
// only context that has one. A pattern that matches with another method adds
// the method to the router's Allow, which rest::routes answers with.
fn on<S, A>(cx: Cx<S, A, http::Router>&, method: const u8[:], pattern: const u8[:]) -> bool {
    return http::on(cx.router, method, pattern);
}

// Runs F when the request is method on pattern, and marks the request
// taken first, so that the routes and scopes after it don't match. F returns
// as any block does, so middleware around it works after it. The mark is
// checked here as well as in http::on, so that a route after it costs a
// branch rather than a call.
inline fn route_on<S, A, F>(cx: Cx<S, A, http::Router>&, method: const u8[:], pattern: const u8[:]) {
    if !cx.router.bad && on(cx, method, pattern) {
        taken(cx);
        F();
    }
}

// The route for a method on pattern, inside rest::routes. get takes HEAD too.
//
//   rest::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
inline fn get<S, A, F>(cx: Cx<S, A, http::Router>&, pattern: const u8[:]) { route_on(cx, "GET", pattern) { F(); }; }
inline fn post<S, A, F>(cx: Cx<S, A, http::Router>&, pattern: const u8[:]) { route_on(cx, "POST", pattern) { F(); }; }
inline fn put<S, A, F>(cx: Cx<S, A, http::Router>&, pattern: const u8[:]) { route_on(cx, "PUT", pattern) { F(); }; }
inline fn patch<S, A, F>(cx: Cx<S, A, http::Router>&, pattern: const u8[:]) { route_on(cx, "PATCH", pattern) { F(); }; }
inline fn delete<S, A, F>(cx: Cx<S, A, http::Router>&, pattern: const u8[:]) { route_on(cx, "DELETE", pattern) { F(); }; }

// Runs F when the path left to match starts with prefix, as narrowed below
// takes it, against the router of the rest::routes block around it, so that
// rest::get and its kin in F match the rest. Then it answers as rest::routes
// does when F left the request unanswered, and takes it: the scope owns the
// paths under prefix, and the routes after it don't match.
//
//   rest::routes(cx) { cx =>
//       rest::get(cx, "/health") { ... };
//       rest::scope(cx, "/v1") {
//           rest::get(cx, "/projects") { ... };
//       };
//   };
inline fn scope<S, A, F>(cx: Cx<S, A, http::Router>&, prefix: const u8[:]) {
    if !cx.router.bad && narrowed(cx.router, prefix) {
        let mark = cx.out.buf.len;
        F();
        // Unmarked, no route in F matched, and the path is routable: narrowed took it.
        if !cx.router.bad && unanswered(cx, mark) { otherwise(cx); }
        taken(cx);
    }
}

// Whether r's path starts with prefix, one or more literal segments such as
// "/v1" or "/api/v1", ending at a segment's end, as http::on compares
// segments. If it does, r's path becomes the rest, which the routes inside
// the scope match: "/projects" for "/v1/projects", "" for "/v1" itself. A
// route that doesn't match there still adds its method to r's Allow, so
// rest::otherwise answers 404, 405, and OPTIONS across scopes. The caller
// checks r.bad first, inline, so that a scope after a route that took the
// request costs a branch rather than a call.
fn narrowed(r: http::Router&, prefix: const u8[:]) -> bool {
    let path = r.path;
    var p = 0;
    var q = 0;
    while p < prefix.len {
        guard q < path.len && prefix[p] == '/' && path[q] == '/' else { return false; }
        p++;
        q++;
        var pe = p;
        while pe < prefix.len && prefix[pe] != '/' { pe++; }
        var qe = q;
        while qe < path.len && path[qe] != '/' { qe++; }
        guard http::same_segment(prefix[p..pe], path[q..qe]) else { return false; }
        p = pe;
        q = qe;
    }
    r.path = path[q..];
    return true;
}
