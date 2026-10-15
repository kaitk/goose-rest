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
// what the extractors decode, which lasts until the handler returns. kind
// is the event the handler is called for: http::REQUEST for a request, and
// for each later call (rest::resumed) the event's, such as http::WAKE when
// a route that asked another thread gets its reply, with reply, tag, and
// more holding it (waiting.goose), or http::BODY with a piece in body
// (pieces.goose). req is empty after REQUEST.
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
    // The request's exchange, under serve; null elsewhere.
    ex: Exchange? = null,
    // What the middleware decided for an answer at a later call, under
    // serve; null elsewhere.
    kept: Kept? = null,
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
                       kind: cx.kind, reply: cx.reply, tag: cx.tag, more: cx.more, ex: cx.ex,
                       kept: cx.kept, router: r };
    F(&c);   // a block given the local itself gets a copy of it
}

// The per-request state, or the worker's, of a program that keeps none.
struct NoState { unused: bool = false }

// The most bytes of a body rest::body takes unless a route says otherwise.
let BODY_LIMIT = 1024 * 1024;

// What a route asked serve for past its first call, Exchange.mode's bits:
// the body gathered whole (rest::body), its pieces (rest::body_in_pieces), MORE for
// a response it sends in pieces (rest::begin, rest::file), and the bytes of
// a connection it upgraded (rest::upgrade), the four LATER names. KEPT says
// the exchange keeps what its middleware decided for a later answer.
let GATHERING: u8 = 1;
let RECEIVING: u8 = 2;
let SENDING: u8 = 4;
let UPGRADED: u8 = 8;
let LATER: u8 = 15;
let KEPT: u8 = 16;

// What serve keeps of a request past the handler's first call. A body
// gathered for rest::body is a run of the worker's spill from at, of cap
// bytes, that holds the head rebuilt (head bytes) and then the body so
// far; a body received in pieces counts its bytes so far in len. With KEPT,
// at and cap are instead the run stash_kept wrote, and head the length of
// its fields: a route keeps it only once its body is gathered.
struct Exchange {
    pending: bool = false,   // the body hasn't come whole
    mode: u8 = 0,
    limit: i64 = 0,          // the first rest::body's or rest::body_in_pieces's limit, 0 before it
    at: i64 = 0,
    len: i64 = 0,
    cap: i64 = 0,
    head: i64 = 0,
}

// goose-http's state for each request: the program's, and the exchange's.
struct Slot<S> { state: S, ex: Exchange = Exchange { .. } }

// Serves cfg with goose-http's loop, calling H(cx) for each request, and again
// for each later event a route asked for: a reply from another thread
// (waiting.goose), or a piece of a body, room to send more, or an upgraded
// connection's bytes (pieces.goose). app, the worker's state, is in cx.app,
// and the per-request state, starting from fresh, in cx.state. A body that
// doesn't come with its head is gathered when a route asks for it
// (rest::body), and H runs again once it's whole. Each worker calls serve,
// so the spill, a local of this call, is that worker's own.
//
//   var app = App { .. };
//   rest::serve(cfg, app) { cx => handle(cx) };
fn serve<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    return http::serve(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out, spill) { cx => H(cx) };
        // Here, not in on_event: a function holding a call given a block
        // that stays a call isn't inlined.
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, spill, mark) { cx => H(cx) }; }
    };
}

// serve on goose-http's epoll loop, http::serve_epoll, rather than its
// io_uring loop.
fn serve_epoll<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    return http::serve_epoll(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out, spill) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, spill, mark) { cx => H(cx) }; }
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

// What serve does with each of goose-http's events: H(cx) at REQUEST and at
// the first message of a reply; the later pieces of a reply relay sends on
// itself; and 504 when a reply doesn't come in time. A reply cut short by its
// time limit leaves the response open, and goose-http closes the connection.
// An answer after REQUEST gets the fields its middleware kept (stash_kept).
// Returns out.buf.len from before its call to H, or -1 for none, for
// on_later, which the caller then calls for a route that reads, sends, or
// upgrades (Exchange.mode).
inline fn on_event<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&) -> i64 {
    if ev.kind == http::WAKE && (ev.tag & REPLY_CONT) != 0 {
        relay_piece(out, ev.data, (ev.tag & REPLY_MORE) != 0);
        return -1;
    }
    if ev.kind == http::TIMEOUT {
        var fields: u8[>..] = [];
        var o = out;
        o.common = kept_fields(out.common, st.ex, spill, fields);
        let from = out.buf.len;
        if !out.stream.open { write_error(o, st.state, 504, "timeout", "", -1, ""); }
        settle_kept(st.ex, o, from, spill);
        drop_kept(st.ex, spill);
        return -1;
    }
    if ev.kind == http::CLOSED { drop_kept(st.ex, spill); }
    var mark: i64 = -1;
    if ev.kind == http::REQUEST || ev.kind == http::WAKE {
        var scratch: u8[>..] = [];
        var fields: u8[>..] = [];
        var kept = Kept { .. };
        let wake = ev.kind == http::WAKE;
        st.ex.pending = !wake && !ev.whole;
        mark = out.buf.len;
        var o = out;
        if wake { o.common = kept_fields(out.common, st.ex, spill, fields); }
        var none = NoRouter { .. };
        var cx = Cx<S, A, NoRouter> { req: ev.req, body: if wake { "" } else { ev.data }, out: o, state: st.state,
                                      app: app, scratch: scratch, kind: ev.kind, reply: if wake { ev.data } else { "" },
                                      tag: ev.tag & REPLY_TAG, more: (ev.tag & REPLY_MORE) != 0,
                                      ex: st.ex, kept: kept, router: none };
        H(cx);
        if wake {
            settle_kept(st.ex, o, mark, spill);
        } else if kept.taken {
            let at, n, len = stash_kept(kept, scratch, out.common, ev.req, spill);
            keep_run(st.ex, at, n, len);
        }
    }
    return mark;
}

// on_later's kind for the call with a gathered body, which H gets as
// http::REQUEST.
let GATHERED: u8 = 254;

// The calls to H that follow a route's rest::body, body_in_pieces, begin, file, or
// upgrade (Exchange.mode): one for ev, when it comes after the request's
// first call, and then those each call leads to, as a body that came whole
// passed on as a BODY and an END, or CLOSED for a route that ended early.
// mark is out.buf.len from before on_event's call to H for ev, a REQUEST or
// a WAKE, or -1 for none. Its loop calls H at one place, since the
// program's handler is inlined at each call to H. Goose still inlines
// on_later where it's called once, as goose-http's loop calls serve's block
// once in each place: no Goose construct keeps it out of line
// (docs/goose-findings.md).
fn on_later<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&, mark: i64) {
    var fields: u8[>..] = [];
    var o = out;
    o.common = kept_fields(out.common, st.ex, spill, fields);
    let from = out.buf.len;
    var k = if mark >= 0 { after(ev, st, o, spill, ev.kind, mark) } else { arrived(ev, st, o, spill) };
    while k != http::NO_EVENT {
        let before = out.buf.len;
        let gathered = k == GATHERED;
        if gathered { st.ex.pending = false; }
        let g = st.ex;
        let head = head_of(ev.req, gathered, g, spill);
        var scratch: u8[>..] = [];
        var kept = Kept { .. };
        var none = NoRouter { .. };
        // CLOSED's answer goes nowhere: the response has ended, or been cut.
        var sink: u8[>..] = [];
        var keep = out.keep_alive;
        var stream = out.stream;
        let r = if k == http::CLOSED {
            http::Reply { buf: sink, common: "", keep_alive: keep, minor: out.minor, head: out.head, stream: stream,
                          fd: out.fd }
        } else {
            o
        };
        var cx = Cx<S, A, NoRouter> { req: head,
                                      body: if gathered { spill[g.at + g.head..g.at + g.len] }
                                            else if k == http::BODY { ev.data } else { "" },
                                      out: r, state: st.state, app: app, scratch: scratch,
                                      kind: if gathered { http::REQUEST } else { k }, ex: st.ex, kept: kept,
                                      router: none };
        H(cx);
        // Stashed before after releases the gathered run, which head points into.
        var at: i64 = -1;
        var n: i64 = 0;
        var len: i64 = 0;
        if gathered && kept.taken { at, n, len = stash_kept(kept, scratch, out.common, head, spill); }
        k = after(ev, st, o, spill, k, before);
        keep_run(st.ex, at, n, len);
    }
    settle_kept(st.ex, o, from, spill);
}

// What the middleware around a route decided at its request (rest::cors,
// rest::timed), for the answer if the route leaves it to a later call: the
// fields its answers get after the status line, the innermost middleware's,
// at from..to in cx.scratch, and timed's start and log.
struct Kept {
    from: i64 = 0,
    to: i64 = 0,
    taken: bool = false,
    timed: bool = false,
    log: bool = false,
    begun: i64 = 0,
}

// A kept run's start before its fields: begun's 8 bytes, then a byte of
// KEPT_TIMED and KEPT_LOG.
let KEPT_HEAD = 9;
let KEPT_TIMED: u8 = 1;
let KEPT_LOG: u8 = 2;

// Copies what k holds into a new run of the spill: begun, the flags, its
// fields in scratch past base, the loop's common fields, which are the
// current ones at the later answer, and for the log req's method and
// target. Returns the run's start and length, and the length of its fields.
fn stash_kept(k: const Kept&, scratch: const u8[:], base: const u8[:], req: const http::Request&,
              spill: u8[>..]&) -> i64, i64, i64 {
    let all = scratch[k.from..k.to];
    let fields = if k.taken && starts_with(all, base) { all[base.len..] } else { "" };
    let line = if k.timed && k.log { req.method.len + 1 + req.target.len } else { 0 };
    let run = spill.alloc_slice(KEPT_HEAD + fields.len + line);
    for i in 8 { run[i] = ((k.begun >> (i * 8)) & 0xFF) as u8; }
    run[8] = (if k.timed { KEPT_TIMED } else { 0 }) | (if k.log { KEPT_LOG } else { 0 });
    var at = KEPT_HEAD;
    copy_into(run[at..at + fields.len], fields);
    at += fields.len;
    if line > 0 {
        copy_into(run[at..at + req.method.len], req.method);
        run[at + req.method.len] = ' ';
        copy_into(run[at + req.method.len + 1..], req.target);
    }
    return spill.index_of(run[0]), run.len, fields.len;
}

// Makes x keep the run at, of n bytes, that stash_kept wrote; nothing for
// an at of -1.
fn keep_run(x: Exchange&, at: i64, n: i64, len: i64) {
    guard at >= 0 else { return; }
    x.at = at;
    x.cap = n;
    x.head = len;
    x.mode |= KEPT;
}

// common, or with KEPT, common and then the fields x kept, onto fields,
// which the result then points into.
fn kept_fields(common: const u8[:], x: const Exchange&, spill: const u8[:], fields: u8[>..]&) -> const u8[:] {
    guard (x.mode & KEPT) != 0 else { return common; }
    fields.append(common);
    fields.append(spill[x.at + KEPT_HEAD..x.at + KEPT_HEAD + x.head]);
    return fields;
}

// Ends what x kept once out's buffer has an answer from from, its head
// first: fills in its Server-Timing and writes timed's log line, then frees
// the run. Frees it also once the exchange owes the route no more calls,
// as when goose-http answers 500 for a route that didn't.
fn settle_kept(x: Exchange&, out: http::Reply, from: i64, spill: u8[>..]&) {
    guard (x.mode & KEPT) != 0 else { return; }
    if out.buf.len == from {
        guard !out.stream.waiting && (x.mode & LATER) == 0 else { return; }
        drop_kept(x, spill);
        return;
    }
    let run = spill[x.at..x.at + x.cap];
    let flags = run[8];
    if (flags & KEPT_TIMED) != 0 {
        var begun: i64 = 0;
        for i in 8 {
            let b: i64 = run[i];
            begun |= b << (i * 8);
        }
        var ms: u8[..32] = [];
        format_ms(ms, clock_ns() - begun);
        let fields = run[KEPT_HEAD..KEPT_HEAD + x.head];
        let at = find(fields, TIMING);
        if at >= 0 { fill_timing(out, from, out.common.len - fields.len + at, ms); }
        if (flags & KEPT_LOG) != 0 {
            write_stderr(str(run[KEPT_HEAD + x.head..], " ", out.stream.status, " ", out.buf.len - from, " ", ms, "\n"));
        }
    }
    drop_kept(x, spill);
}

// Frees the run x kept, if any.
fn drop_kept(x: Exchange&, spill: u8[>..]&) {
    guard (x.mode & KEPT) != 0 else { return; }
    spill.free_slice(spill[x.at..x.at + x.cap]);
    x.at = 0;
    x.cap = 0;
    x.head = 0;
    x.mode &= ~KEPT;
}

// What on_later calls H with for ev, an event after the request's first
// call, http::NO_EVENT for nothing, and what serve does itself: a gathered
// body's pieces, and the limit of one gathered or received. Past its limit
// a body gets 413 and the connection closes, as http::body_within does.
fn arrived<S>(ev: http::Event, st: Slot<S>&, out: http::Reply, spill: u8[>..]&) -> u8 {
    let x .= st.ex;
    let k = ev.kind;
    if x.mode & GATHERING != 0 {
        if k == http::BODY {
            guard gather_piece(x, ev.data, spill) else {
                release(x, spill);
                out.keep_alive = false;
                write_error(out, st.state, 413, "payload_too_large", "", -1, "");
                return http::NO_EVENT;
            }
        } else if k == http::END {
            return GATHERED;
        } else if k == http::CLOSED {
            release(x, spill);
        }
        return http::NO_EVENT;
    }
    if k == http::CLOSED { return k; }
    if k == http::BODY && (x.mode & RECEIVING) != 0 {
        x.len += ev.data.len;
        guard x.len <= x.limit else {
            out.keep_alive = false;
            if out.stream.open {
                out.stream.open = false;
            } else {
                write_error(out, st.state, 413, "payload_too_large", "", -1, "");
            }
            return http::CLOSED;
        }
        return k;
    }
    if (k == http::BODY && (x.mode & UPGRADED) != 0) || (k == http::END && (x.mode & RECEIVING) != 0) ||
       (k == http::MORE && (x.mode & SENDING) != 0) {
        return k;
    }
    return http::NO_EVENT;
}

// What follows a call to H for k, which wrote out.buf from before: the
// gathering rest::body left the route for, the BODY and END of a body that
// came whole, or CLOSED for a route that answered before its body's END or
// that rest::route cut short (route), as the end of its exchange.
fn after<S>(ev: http::Event, st: Slot<S>&, out: http::Reply, spill: u8[>..]&, k: u8, before: i64) -> u8 {
    let x .= st.ex;
    if k == http::CLOSED {
        x.mode &= KEPT;
        return http::NO_EVENT;
    }
    if (x.mode & GATHERING) != 0 {
        guard k == GATHERED else {
            if out.buf.len == before { gather_head(x, ev.req, spill); } else { x.mode &= ~GATHERING; }
            return http::NO_EVENT;
        }
        release(x, spill);
    }
    let open = out.stream.open;
    if k == http::END { x.mode &= ~RECEIVING; }
    if (x.mode & (SENDING | UPGRADED)) != 0 && !open { return http::CLOSED; }
    if (x.mode & RECEIVING) != 0 {
        if out.buf.len > before && !open { return http::CLOSED; }
        if !x.pending && k == http::REQUEST { return if ev.data.len > 0 { http::BODY } else { http::END }; }
        if !x.pending && k == http::BODY { return http::END; }
    }
    return http::NO_EVENT;
}

// The head of the request H is called for: req, or for a gathered body, the
// head parsed again from its copy in the spill.
fn head_of(req: const http::Request&, gathered: bool, x: const Exchange&, spill: const u8[:]) -> http::Request {
    guard gathered else { return req; }
    let r, status = http::parse(spill[x.at..x.at + x.head], x.head, x.len);
    return r;
}

// Starts g's run with the head rebuilt from req, whose bytes goose-http
// reuses once its handler returns.
fn gather_head(g: Exchange&, req: const http::Request&, spill: u8[>..]&) {
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
fn gather_piece(g: Exchange&, data: const u8[:], spill: u8[>..]&) -> bool {
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

// Frees g's run of the spill, and stops gathering.
fn release(g: Exchange&, spill: u8[>..]&) {
    if g.cap > 0 { spill.free_slice(spill[g.at..g.at + g.cap]); }
    g.at = 0;
    g.len = 0;
    g.cap = 0;
    g.head = 0;
    g.mode &= ~GATHERING;
}

// The request's body, of at most limit bytes: a longer one fails the route
// with 413 payload_too_large. The first call's limit holds for the request.
// A body that hasn't come with the head leaves the route without an answer:
// serve gathers it and calls the handler again with it whole, so a route
// runs twice up to its first rest::body. After rest::body_in_pieces, 500
// body_already_read.
fn body<S, A, R>(cx: Cx<S, A, R>&, limit: i64 = BODY_LIMIT) -> const u8[:] {
    var g .= cx.ex;
    guard g else {
        if cx.body.len > limit { fail(cx, 413, "payload_too_large"); }
        return cx.body;
    }
    guard (g.mode & RECEIVING) == 0 else { fail(cx, 500, "body_already_read"); }
    if g.limit == 0 { g.limit = limit; }
    if g.pending {
        if !cx.req.chunked && cx.req.body > g.limit { fail(cx, 413, "payload_too_large"); }
        g.mode |= GATHERING;
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
// calls fails. The first answer wins: a failure after the handler wrote an
// answer leaves it as it is, and one with a response open, its head sent,
// cuts it short: the response stays unended and the connection closes, so
// the client sees it end early. route can't take an answer back, since
// shrinking the write buffer is refused while a slice of the request is live
// (spec §5.1: a parameter's slices may point into any array of their type).
inline fn route<F>(cx) {
    let mark = cx.out.buf.len;
    let failed = attempt(F);
    for f in failed {
        // Status 0 is rest::body leaving to gather the body, unanswered.
        if f.status == 0 {
        } else if cx.out.stream.open {
            cx.out.stream.open = false;
            cx.out.keep_alive = false;
        } else if cx.out.buf.len == mark {
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
