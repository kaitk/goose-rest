// The runtime: a request's context, routes that fail from any depth below
// them, and answers in JSON, every error in one shape, goose-rest's or the
// program's (docs/reference.md, "Errors").
namespace rest;

import std;
import json;
import http from "github.com/kaitk/goose-http@v0.3.2";

// A request's context: its head, its body, where its answer goes, the
// application's per-request state, which goose-http keeps in the
// connection's slot and starts from fresh for each request, the worker's
// state, app, which every request of the worker shares, and scratch for
// what the extractors decode, which lasts until the handler returns. When a
// route that asked another thread resumes (rest::woken), kind is
// http::WAKE, and reply, tag, and more hold the reply (waiting.goose); req
// is then empty.
// router is the http::Router of rest::routes' block, R, and a NoRouter
// elsewhere, so that rest::on and the calls that read a matched route take
// only the context routes gives its block, or the program doesn't compile.
struct Cx<S, A, R> {
    req: const http::Request&,
    body: const u8[:],
    out: http::Reply,
    state: S&,
    app: A&,
    scratch: u8[>..]&,
    kind: u8 = 0,
    reply: const u8[:] = "",
    tag: i32 = 0,
    more: bool = false,
    // The connection's body gathering, under serve; null elsewhere.
    gather: Gather? = null,
    router: R&,
}

// A context's router outside rest::routes: none.
struct NoRouter { unused: bool = false }

// Runs F(c), c being cx with a router over its request, so that the block's
// rest::on, rest::scope, rest::param, and rest::otherwise take c alone. A
// generated dispatch inside the block answers with the Allow of the routes
// tried before it.
//
//   rest::routes(cx) { cx =>
//       if rest::on(cx, "GET", "/health") { ... } else { rest::otherwise(cx); }
//   };
inline fn routes<S, A, F>(cx: Cx<S, A, NoRouter>&) {
    var r = http::router(cx.req);
    var c = Cx<S, A, http::Router> { req: cx.req, body: cx.body, out: cx.out, state: cx.state,
                       app: cx.app, scratch: cx.scratch,
                       kind: cx.kind, reply: cx.reply, tag: cx.tag, more: cx.more, gather: cx.gather,
                       router: r };
    F(&c);   // a block given the local itself gets a copy of it
}

// The per-request state, or the worker's, of a program that keeps none.
struct NoState { unused: bool = false }

// The most bytes of a body rest::body takes unless a route says otherwise.
let BODY_LIMIT = 1024 * 1024;

// A body that didn't come with its head, gathered for the route that asked
// for it with rest::body: a run of the worker's spill from at, of cap bytes,
// that holds the head rebuilt (head bytes) and then the body so far.
struct Gather {
    pending: bool = false,   // the body hasn't come whole
    limit: i64 = 0,          // the first rest::body's limit, 0 before it
    at: i64 = 0,
    len: i64 = 0,
    cap: i64 = 0,
    head: i64 = 0,
}

// goose-http's state for each request: the program's, and the gathering.
struct Slot<S> { state: S, body: Gather = Gather { .. } }

// Serves cfg with goose-http's loop, calling H(cx) for each request, and again
// when a route that asked another thread gets its reply (waiting.goose), with
// app, the worker's state, in cx.app, and the per-request state, starting
// from fresh, in cx.state. A body that doesn't come with its head is gathered
// when a route asks for it (rest::body), and H runs again once it's whole.
// Each worker calls serve, so the spill, a local of this call, is that
// worker's own.
//
//   var app = App { .. };
//   rest::serve(cfg, app) { cx => handle(cx) };
fn serve<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    return http::serve(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        on_event(ev, st, app, out, spill) { cx => H(cx) };
    };
}

// serve on goose-http's epoll loop, http::serve_epoll, rather than its
// io_uring loop.
fn serve_epoll<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    return http::serve_epoll(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        on_event(ev, st, app, out, spill) { cx => H(cx) };
    };
}

// serve for a program that keeps no per-request state.
fn serve<A, H>(cfg: http::Config, app: A&) -> http::Error {
    return serve(cfg, app, NoState { .. }) { cx => H(cx) };
}

fn serve_epoll<A, H>(cfg: http::Config, app: A&) -> http::Error {
    return serve_epoll(cfg, app, NoState { .. }) { cx => H(cx) };
}

// serve for a program that keeps no state.
fn serve<H>(cfg: http::Config) -> http::Error {
    var none = NoState { .. };
    return serve(cfg, none, NoState { .. }) { cx => H(cx) };
}

fn serve_epoll<H>(cfg: http::Config) -> http::Error {
    var none = NoState { .. };
    return serve_epoll(cfg, none, NoState { .. }) { cx => H(cx) };
}

// What serve does with each of goose-http's events: H(cx) at REQUEST, at the
// first message of a reply, and at the END of a gathered body; the later
// pieces of a reply relay sends on itself; and 504 when a reply doesn't come
// in time. A reply cut short by its time limit leaves the response open, and
// goose-http closes the connection.
inline fn on_event<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&) {
    if ev.kind == http::WAKE && (ev.tag & REPLY_CONT) != 0 {
        relay_piece(out, ev.data, (ev.tag & REPLY_MORE) != 0);
    } else if ev.kind == http::TIMEOUT {
        if !out.stream.open { write_error(out, st.state, 504, "timeout", "", -1, ""); }
    } else if ev.kind == http::REQUEST || ev.kind == http::WAKE {
        var scratch: u8[>..] = [];
        let wake = ev.kind == http::WAKE;
        st.body.pending = !wake && !ev.whole;
        let mark = out.buf.len;
        var none = NoRouter { .. };
        var cx = Cx<S, A, NoRouter> { req: ev.req, body: if wake { "" } else { ev.data }, out: out, state: st.state,
                                      app: app, scratch: scratch, kind: ev.kind, reply: if wake { ev.data } else { "" },
                                      tag: ev.tag & REPLY_TAG, more: (ev.tag & REPLY_MORE) != 0,
                                      gather: st.body, router: none };
        H(cx);
        if st.body.pending && st.body.limit > 0 {
            if out.buf.len == mark { gather_head(st.body, ev.req, spill); } else { st.body.limit = 0; }
        }
    } else if st.body.limit > 0 {
        if ev.kind == http::BODY {
            guard gather_piece(st.body, ev.data, spill) else {
                release(st.body, spill);
                out.keep_alive = false;
                write_error(out, st.state, 413, "payload_too_large", "", -1, "");
                return;
            }
        } else if ev.kind == http::END {
            on_whole(st, app, out, spill) { cx => H(cx) };
        } else if ev.kind == http::CLOSED {
            release(st.body, spill);
        }
    }
}

// H(cx) for a gathered body, with the head parsed again from its copy.
inline fn on_whole<S, A, H>(st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&) {
    let g = st.body;
    let req, status = http::parse(spill[g.at..g.at + g.head], g.head, g.len);
    st.body.pending = false;
    var scratch: u8[>..] = [];
    var none = NoRouter { .. };
    var cx = Cx<S, A, NoRouter> { req: req, body: spill[g.at + g.head..g.at + g.len], out: out, state: st.state,
                                  app: app, scratch: scratch, kind: http::REQUEST, gather: st.body,
                                  router: none };
    H(cx);
    release(st.body, spill);
}

// Starts g's run with the head rebuilt from req, whose bytes goose-http
// reuses once its handler returns.
fn gather_head(g: Gather&, req: const http::Request&, spill: u8[>..]&) {
    var head: u8[>..] = [];
    head.append(req.method);
    head.push(' ');
    head.append(req.target);
    head.append(" HTTP/1.");
    format(head, req.minor);
    head.append("\r\n");
    head.append(req.fields);
    head.append("\r\n");
    g.head = head.len;
    gather_piece(g, head, spill);
}

// Appends data to g's run, growing it, unless the body would pass g's limit.
fn gather_piece(g: Gather&, data: const u8[:], spill: u8[>..]&) -> bool {
    let n = g.len + data.len;
    guard n - g.head <= g.limit else { return false; }
    if n > g.cap {
        let cap = max(max(n, g.cap * 2), 16384);
        let run = spill.realloc_slice(spill[g.at..g.at + g.cap], cap);
        g.at = spill.index_of(run[0]);
        g.cap = cap;
    }
    copy_into(spill[g.at + g.len..g.at + n], data);
    g.len = n;
    return true;
}

fn release(g: Gather&, spill: u8[>..]&) {
    if g.cap > 0 { spill.free_slice(spill[g.at..g.at + g.cap]); }
    g = Gather { .. };
}

// The request's body, of at most limit bytes: a longer one fails the route
// with 413 payload_too_large. The first call's limit holds for the request.
// A body that hasn't come with the head leaves the route without an answer:
// serve gathers it and calls the handler again with it whole, so a route
// runs twice up to its first rest::body.
fn body<S, A, R>(cx: Cx<S, A, R>&, limit: i64 = BODY_LIMIT) -> const u8[:] {
    var g .= cx.gather;
    guard g else {
        if cx.body.len > limit { fail(cx, 413, "payload_too_large"); }
        return cx.body;
    }
    if g.limit == 0 { g.limit = limit; }
    if g.pending {
        if !cx.req.chunked && cx.req.body > g.limit { fail(cx, 413, "payload_too_large"); }
        return [Failure { status: 0, at: -1, code: "", detail: "", challenge: "" }] from attempt;
    }
    if cx.body.len > g.limit { fail(cx, 413, "payload_too_large"); }
    return cx.body;
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
    let failed = attempt(F);
    for f in failed {
        // Status 0 is rest::body leaving to gather the body, unanswered.
        if cx.out.buf.len == mark && f.status != 0 {
            write_error(cx.out, cx.state, f.status, f.code, f.detail, f.at, "", f.challenge);
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
// the request says it's application/json, 413 past rest::body's limit, and
// 400 invalid_body for a body R refused or one with more after its value.
// Generated from_request overloads call it.
inline fn json_body<R>(cx) {
    guard http::has_type(cx.req, "application/json") else { fail(cx, 415, "unsupported_media_type"); }
    var r = json::reader(body(cx));
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
// takes: OPTIONS with 204 and an Allow, any other method with 405 and that
// Allow. The Allow is that of the program's routes before dispatch, in
// rest::routes, then those of mine, the generated path's, that theirs lacks.
fn no_method(cx, mine: const u8[:]) {
    let theirs = allow_before(cx);
    guard theirs.len > 0 else { allowed(cx, mine); return; }
    var both: u8[>..] = [];
    both.append(theirs);
    var at = 0;
    while at < mine.len {
        var end = at;
        while end < mine.len && mine[end] != ',' { end++; }
        if !has_method(theirs, mine[at..end]) {
            both.append(", ");
            both.append(mine[at..end]);
        }
        at = end + 2;
    }
    allowed(cx, both);
}

// The Allow of the routes rest::routes' block tried, "" outside one.
fn allow_before<S, A>(cx: const Cx<S, A, http::Router>&) -> const u8[:] { cx.router.allow }

fn allow_before<S, A>(cx: const Cx<S, A, NoRouter>&) -> const u8[:] { "" }

fn allowed(cx, allow: const u8[:]) {
    if cx.req.method == "OPTIONS" {
        http::start(cx.out, 204);
        http::field(cx.out, "Allow", allow);
        http::finish(cx.out, http::NO_TYPE, "");
    } else {
        write_error(cx.out, cx.state, 405, "method_not_allowed", "", -1, allow);
    }
}

// Whether allow, methods with ", " between, lists method.
fn has_method(allow: const u8[:], method: const u8[:]) -> bool {
    var at = 0;
    while at < allow.len {
        var end = at;
        while end < allow.len && allow[end] != ',' { end++; }
        if allow[at..end] == method { return true; }
        at = end + 2;
    }
    return false;
}

// Answers a request whose path no route matched, as otherwise does: an
// unknown method 501, a path with a dot-segment or an escaped control byte
// 400, OPTIONS * 204, and anything else 404.
fn no_route(cx, method: const u8[:], path: const u8[:]) {
    if !http::known_method(method) {
        write_error(cx.out, cx.state, 501, "not_implemented", "", -1, "");
    } else if !http::is_routable(path) {
        write_error(cx.out, cx.state, 400, "bad_path", "", -1, "");
    } else if method == "OPTIONS" && path == "*" {
        http::start(cx.out, 204);
        http::finish(cx.out, http::NO_TYPE, "");
    } else {
        write_error(cx.out, cx.state, 404, "not_found", "", -1, "");
    }
}

// no_route for a request whose method is known and whose path is routable,
// as the generated routers have checked by then: OPTIONS * 204, and 404. A
// path that only the program's routes before dispatch matched gets
// no_method's answer with their Allow.
fn not_found(cx, method: const u8[:], path: const u8[:]) {
    let theirs = allow_before(cx);
    if theirs.len > 0 {
        allowed(cx, theirs);
    } else if method == "OPTIONS" && path == "*" {
        http::start(cx.out, 204);
        http::finish(cx.out, http::NO_TYPE, "");
    } else {
        write_error(cx.out, cx.state, 404, "not_found", "", -1, "");
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
    http::finish(cx.out, http::JSON, body);
}

// Answers status with body, JSON the program wrote itself, such as a
// record's prebuilt at startup.
fn json_bytes(cx, status: i32, body: const u8[:]) {
    http::start(cx.out, status);
    http::finish(cx.out, http::JSON, body);
}

// finish's fields for rest::text. http::TEXT names no charset, which leaves a
// client to guess one for anything past ASCII.
const TEXT_UTF8: u8[57] = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ";

// Answers status with s as UTF-8 text.
fn text(cx, status: i32, s: const u8[:]) {
    http::start(cx.out, status);
    http::finish(cx.out, TEXT_UTF8, s);
}

// Answers status without a body: 204 and 304 without Content-Length, and any
// other status with Content-Length: 0.
fn empty(cx, status: i32) {
    http::start(cx.out, status);
    http::finish(cx.out, http::NO_TYPE, "");
}

// Answers a request no route took, as http::otherwise does, with each error in
// the JSON shape: an unknown method 501 not_implemented, a path the router
// refused 400 bad_path, a path no route matched 404 not_found, and another
// method of a path that did 405 method_not_allowed, with Allow. OPTIONS gets
// 204 with that Allow, or for "*" without one. Inside rest::routes, as
// rest::otherwise(cx); a program that builds its own http::router passes it.
fn otherwise<S, A>(cx: Cx<S, A, http::Router>&) { otherwise(cx, cx.router); }

fn otherwise(cx, r: const http::Router&) {
    if !http::known_method(r.method) {
        write_error(cx.out, cx.state, 501, "not_implemented", "", -1, "");
    } else if r.bad {
        write_error(cx.out, cx.state, 400, "bad_path", "", -1, "");
    } else if r.method == "OPTIONS" && (r.path == "*" || r.allow.len > 0) {
        http::start(cx.out, 204);
        if r.allow.len > 0 { http::field(cx.out, "Allow", r.allow); }
        http::finish(cx.out, http::NO_TYPE, "");
    } else if r.allow.len == 0 {
        write_error(cx.out, cx.state, 404, "not_found", "", -1, "");
    } else {
        write_error(cx.out, cx.state, 405, "method_not_allowed", "", -1, r.allow);
    }
}

// Answers an error with the body error_body writes for the type of st, the
// per-request state, an Allow field when allow isn't empty, and a
// WWW-Authenticate field when challenge isn't.
fn write_error(out: http::Reply, st, status: i32, code: const u8[:], detail: const u8[:], at: i64,
               allow: const u8[:], challenge: const u8[:] = "") {
    var body: u8[>..] = [];
    error_body(body, st, status, code, detail, at);
    http::start(out, status);
    if allow.len > 0 { http::field(out, "Allow", allow); }
    if challenge.len > 0 { http::field(out, "WWW-Authenticate", challenge); }
    http::finish(out, http::JSON, body);
}

// The error shape: {"error": code}, with "detail" when detail isn't empty,
// and "at" when at isn't negative. A program writes its own shape with an
// overload for its per-request state's type, which wins over this generic
// one: fn rest::error_body(body: u8[>..]&, st: const app::St&, status: i32,
// code: const u8[:], detail: const u8[:], at: i64).
fn error_body(body: u8[>..]&, st, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
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
}
