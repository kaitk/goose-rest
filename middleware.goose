// Middleware: blocks around a group of routes, inlined into the handler
// (spike 04), and prefix scopes over http::router. One rest::route takes a
// request's failures: routes nested in routes keep each other out of line
// (docs/architecture/README.md, "Inlining"). So middleware that adds fields
// to every answer, timed and cors, goes outside the route and answers what
// it refuses itself, and checks that fail, as bearer, go inside it.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";

// Inserts the field name: value after the status line of the response begun
// at mark in out's buffer, so that a middleware can add a field once its
// block has answered. Nothing when the block wrote no response, as when it
// waits, or for a field http::is_field refuses.
fn insert_field(out: http::Reply, mark: i64, name: const u8[:], value: const u8[:]) {
    guard out.buf.len > mark && http::is_field(name, value) else { return; }
    let eol = find(out.buf[mark..], "\r\n");
    guard eol >= 0 else { return; }
    let at = mark + eol + 2;
    let n = name.len + value.len + 4;
    let old = out.buf.len;
    // Grown by appending: resize may shrink, which is refused while a slice
    // of the request is live (spec §5.1).
    out.buf.append(name);
    out.buf.append(": ");
    out.buf.append(value);
    out.buf.append("\r\n");
    var i = old;
    while i > at {
        i--;
        out.buf[i + n] = out.buf[i];
    }
    var k = at;
    for c in name { out.buf[k] = c; k++; }
    out.buf[k] = ':';
    out.buf[k + 1] = ' ';
    k += 2;
    for c in value { out.buf[k] = c; k++; }
    out.buf[k] = '\r';
    out.buf[k + 1] = '\n';
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
// age, without running F; the browser checks the request against them. An
// answer written after F returns, at a WAKE, gets no CORS fields.
//
//   rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) { ... };
inline fn cors<S, F>(cx: Cx<S>&, c: Cors) {   // a reference: the block sees the caller's cx.out
    let origin, has_origin = http::field_of(cx.req, "origin");
    let common = cx.out.common;
    if has_origin {
        guard origin_in(c.origins, origin) else {
            write_error(cx.out, cx.state,403, "origin_not_allowed", "", -1, "");
            return;
        }
        let method, preflight = http::field_of(cx.req, "access-control-request-method");
        if preflight && cx.req.method == "OPTIONS" {
            answer_preflight(cx.out, c, origin);
            return;
        }
        cx.out.common = with_cors(cx.scratch, common, c, origin);
    }
    F();
    cx.out.common = common;
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
    http::finish(out, "", "");
}

// common with the CORS fields of an allowed origin after it, onto scratch,
// which the result points into.
fn with_cors(scratch: u8[>..]&, common: const u8[:], c: Cors, origin: const u8[:]) -> const u8[:] {
    let at = scratch.len;
    scratch.append(common);
    format(scratch, "Access-Control-Allow-Origin: ", origin, "\r\n");
    if c.credentials { scratch.append("Access-Control-Allow-Credentials: true\r\n"); }
    if c.expose.len > 0 { format(scratch, "Access-Control-Expose-Headers: ", c.expose, "\r\n"); }
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
    let scheme, token, found = http::authorization(cx.req);
    guard found && token.len > 0 && http::same_name(scheme, "bearer") else {
        fail_auth(cx, "unauthenticated", "Bearer");
    }
    return token;
}

// Fails the enclosing route with 401 invalid_token and WWW-Authenticate:
// Bearer error="invalid_token", for a bearer token the program refuses.
fn invalid_token(cx) {
    fail_auth(cx, "invalid_token", "Bearer error=\"invalid_token\"");
}

// Runs F, then adds Server-Timing to its answer with the milliseconds F
// took, as "app;dur=0.042", and, when log is set, writes an access log line
// to standard error: method, target, status, the response's bytes, and the
// milliseconds, as "GET /v1/projects?page=2 200 87 0.042". A request whose
// answer F didn't write, as one that waits, gets neither.
inline fn timed<F>(cx, log: bool = true) {
    let begun = clock_ns();
    let mark = cx.out.buf.len;
    F();
    guard cx.out.buf.len > mark else { return; }
    let us = (clock_ns() - begun) / 1000;
    var ms: u8[..32] = [];
    format(ms, us / 1000, ".");
    let frac = us % 1000;
    if frac < 100 { ms.push('0'); }
    if frac < 10 { ms.push('0'); }
    format(ms, frac);
    var value: u8[..48] = [];
    format(value, "app;dur=", ms);
    insert_field(cx.out, mark, "Server-Timing", value);
    if log {
        write_stderr(str(cx.req.method, " ", cx.req.target, " ", cx.out.stream.status, " ", cx.out.buf.len - mark,
                         " ", ms, "\n"));
    }
}

// Whether r's path starts with prefix, one or more literal segments such as
// "/v1" or "/api/v1", ending at a segment's end, as http::on compares
// segments. If it does, r's path becomes the rest, which the routes inside
// the scope match: "/projects" for "/v1/projects", "" for "/v1" itself. A
// route that doesn't match there still adds its method to r's Allow, so
// rest::otherwise answers 404, 405, and OPTIONS across scopes.
//
//   if rest::scope(r, "/v1") {
//       if http::on(r, "GET", "/projects") { ... }
//       else { rest::otherwise(cx, r); }
//   }
fn scope(r: http::Router&, prefix: const u8[:]) -> bool {
    guard !r.bad else { return false; }
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
