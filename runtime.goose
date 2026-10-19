// The runtime: a request's context, routes that fail from any depth below
// them, and answers in JSON, every error in one shape, goose-rest's or the
// program's (docs/reference.md, "Errors").
namespace rest;

import std;
import json;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";

// A request's context: its head, its body, where its answer goes, the
// application's request state, which goose-http keeps in the
// connection's slot and starts from fresh for each request, the worker's
// state, app, which every request of the worker shares, and scratch for
// what the extractors decode, which lasts until the handler returns. kind
// is the event the handler is called for: http::REQUEST for a request, and
// for each later call (rest::resumed) the event's, such as http::WAKE when
// a route that asked another thread gets its reply, with reply, refused, and
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
    refused: bool = false,
    more: bool = false,
    // The request's exchange, under serve; null elsewhere.
    ex: Exchange? = null,
    // What the middleware decided for an answer at a later call, under
    // serve; null elsewhere.
    kept: Kept? = null,
    // The worker's budget for bodies being gathered, under serve; null
    // elsewhere.
    budget: Budget? = null,
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
                       kind: cx.kind, reply: cx.reply, refused: cx.refused, more: cx.more, ex: cx.ex,
                       kept: cx.kept, budget: cx.budget, router: r };
    F(&c);   // a block given the local itself gets a copy of it
}

// The request state, or the worker state, of a program that keeps none.
struct NoState { unused: bool = false }

// The most bytes of a body rest::body takes unless a route says otherwise.
let BODY_LIMIT = 1024 * 1024;

// goose-rest's settings for serve, beside goose-http's http::Config.
// gather_budget is the most bytes a worker's spill, which keeps its
// high-water mark for the worker's life, reaches for the bodies it gathers
// for rest::body, heads included, and the replies of rest::reply_value it
// collects from pieces: a body that the spill can't place within it gets 503
// unavailable with Retry-After, at its head for a body with a
// Content-Length, or once a chunked body grows past it, and a reply 502
// reply_too_large. Bodies read with rest::body_in_pieces, and replies
// relayed, don't count.
struct Config { gather_budget: i64 = GATHER_BUDGET }

// 63 bodies at goose-http's default max_body of 1 MB at once, with their
// heads, or three at a 16 MB limit, in each worker.
let GATHER_BUDGET: i64 = 64 * 1024 * 1024;

// A run of the spill in use, a gathered body's, a reply's being collected,
// or what an exchange's middleware kept; a cap of 0 is a free entry of
// Budget.runs.
struct Run { at: i64 = 0, cap: i64 = 0 }

// A worker's spill as its gather budget sees it: size, the most bytes it
// may reach, len, its length, and the runs in use, whose places say where
// the spill puts the next run (spill_end). The middleware's kept runs, about
// 100 bytes each, are placed without a check.
struct Budget { size: i64, len: i64 = 0, runs: Run[>..]& }

// The seconds a 503 past the budget asks a client to wait, the fewest the
// field can say: the budget frees as soon as a body being gathered is
// answered.
let RETRY_AFTER = "1";

// What a route asked serve for past its first call, Exchange.mode's bits:
// the body gathered whole (rest::body), its pieces (rest::body_in_pieces), MORE for
// a response it sends in pieces (rest::begin, rest::file), and the bytes of
// a connection it upgraded (rest::upgrade), the four LATER names. KEPT says
// the exchange keeps what its middleware decided for a later answer.
// OFFERED says the handler runs inside rest::compressed, and CODED that the
// response rest::begin began there holds an encoder (compression.goose).
// COLLECTING says the exchange collects a reply_value's pieces in a run of
// the spill (collect_reply).
let GATHERING: u8 = 1;
let RECEIVING: u8 = 2;
let SENDING: u8 = 4;
let UPGRADED: u8 = 8;
let LATER: u8 = 15;
let KEPT: u8 = 16;
let OFFERED: u8 = 32;
let CODED: u8 = 64;
let COLLECTING: u8 = 128;

// What serve keeps of a request past the handler's first call. A body
// gathered for rest::body is a run of the worker's spill from at, of cap
// bytes, that holds the head rebuilt (head bytes) and then the body so
// far; a body received in pieces counts its bytes so far in len. With KEPT,
// at and cap are instead the run stash_kept wrote, and head the length of
// its fields: a route keeps it only once its body is gathered. With
// COLLECTING, due is instead where the run of a reply being collected
// starts: an exchange has one wait, a pause's or a reply's, and a pause sets
// due afresh.
struct Exchange {
    pending: bool = false,   // the body hasn't come whole
    mode: u8 = 0,
    limit: i64 = 0,          // the first rest::body's or rest::body_in_pieces's limit, 0 before it
    at: i64 = 0,
    len: i64 = 0,
    cap: i64 = 0,
    head: i64 = 0,
    due: i64 = 0,            // the clock_ns from which a TIMEOUT is rest::pause's own, not goose-http's at once
}

// goose-http's state for each request: the program's, and the exchange's.
struct Slot<S> { state: S, ex: Exchange = Exchange { .. } }

// Serves cfg with goose-http's loop, calling H(cx) for each request, and again
// for each later event a route asked for: a reply from another thread
// (waiting.goose), or a piece of a body, room to send more, or an upgraded
// connection's bytes (pieces.goose). app, the worker state, is in cx.app,
// and the request state, starting from fresh, in cx.state. A body that
// doesn't come with its head is gathered when a route asks for it
// (rest::body), and H runs again once it's whole, within limits'
// gather_budget. Each worker calls serve, so the spill, a local of this
// call, and its budget are that worker's own.
//
//   var app = App { .. };
//   rest::serve(cfg, app) { cx => handle(cx) };
fn serve<A, S, H>(cfg: http::Config, app: A&, fresh: S, limits: Config = Config { .. }) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    var runs: Run[>..] = [];
    var budget = Budget { size: limits.gather_budget, runs: runs };
    return http::serve(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out, spill, budget) { cx => H(cx) };
        // Here, not in on_event: a function holding a call given a block
        // that stays a call isn't inlined.
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, spill, budget, mark) { cx => H(cx) }; }
    };
}

// serve on goose-http's epoll loop, http::serve_epoll, rather than its
// io_uring loop.
fn serve_epoll<A, S, H>(cfg: http::Config, app: A&, fresh: S, limits: Config = Config { .. }) -> http::Error {
    reusable[] var spill: u8[>..] = [];
    var runs: Run[>..] = [];
    var budget = Budget { size: limits.gather_budget, runs: runs };
    return http::serve_epoll(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out, spill, budget) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, spill, budget, mark) { cx => H(cx) }; }
    };
}

// serve for a program that keeps no request state.
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
// the first message of a reply, or for a reply_value in pieces at its last,
// once collect_reply has collected them; the later pieces of a reply relay
// sends on itself; and 504 when a reply doesn't come in time, except on an
// upgraded connection, whose route on_later calls with the TIMEOUT. A reply
// cut short by its time limit leaves the response open, and goose-http
// closes the connection.
// An answer after REQUEST gets the fields its middleware kept (stash_kept).
// Returns out.buf.len from before its call to H, or -1 for none, for
// on_later, which the caller then calls for a route that reads, sends, or
// upgrades (Exchange.mode).
inline fn on_event<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&,
                            budget: Budget&) -> i64 {
    if ev.kind == http::WAKE && (ev.tag & (REPLY_CONT | REPLY_VALUE)) != 0 {
        if (ev.tag & REPLY_VALUE) == 0 {
            relay_piece(out, ev.data, (ev.tag & REPLY_MORE) != 0);
            return -1;
        }
        if (ev.tag & (REPLY_CONT | REPLY_MORE)) != 0 && !collect_reply(st, ev.data, ev.tag, out, spill, budget) {
            return -1;
        }
    }
    if ev.kind == http::TIMEOUT {
        drop_reply(st.ex, spill, budget);
        end_wait(st, out, spill, budget, 504, "timeout", false);
        return -1;
    }
    if ev.kind == http::CLOSED {
        drop_kept(st.ex, spill, budget);
        drop_reply(st.ex, spill, budget);
    }
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
                                      app: app, scratch: scratch, kind: ev.kind,
                                      reply: if wake { collected(st.ex, ev.data, ev.tag, spill) } else { "" },
                                      refused: wake && (ev.tag & REPLY_REFUSED) != 0, more: (ev.tag & REPLY_MORE) != 0,
                                      ex: st.ex, kept: kept, budget: budget, router: none };
        // A rest::pause in H sets due afresh: the run starts where it did.
        let run = st.ex.due;
        H(cx);
        if wake {
            settle_kept(st.ex, o, mark, spill, budget);
            drop_run(st.ex, run, spill, budget);
        } else if kept.taken {
            let at, n, len = stash_kept(kept, scratch, out.common, ev.req, spill, budget);
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
fn on_later<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&, budget: Budget&,
                     mark: i64) {
    var fields: u8[>..] = [];
    var o = out;
    o.common = kept_fields(out.common, st.ex, spill, fields);
    let from = out.buf.len;
    var k = if mark >= 0 { after(ev, st, o, spill, budget, ev.kind, mark) } else { arrived(ev, st, o, spill, budget) };
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
                                      budget: budget, router: none };
        H(cx);
        // Stashed before after releases the gathered run, which head points into.
        var at: i64 = -1;
        var n: i64 = 0;
        var len: i64 = 0;
        if gathered && kept.taken { at, n, len = stash_kept(kept, scratch, out.common, head, spill, budget); }
        k = after(ev, st, o, spill, budget, k, before);
        keep_run(st.ex, at, n, len);
    }
    // A route that stopped the wait at a later call, as with rest::end on an
    // upgraded connection, gets no more of the reply it collected.
    if !out.stream.waiting { drop_reply(st.ex, spill, budget); }
    settle_kept(st.ex, o, from, spill, budget);
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
// target, and records it in budget. Returns the run's start and length, and
// the length of its fields.
fn stash_kept(k: const Kept&, scratch: const u8[:], base: const u8[:], req: const http::Request&,
              spill: u8[>..]&, budget: Budget&) -> i64, i64, i64 {
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
    track(budget, spill.index_of(run[0]), run.len, spill.len);
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
fn settle_kept(x: Exchange&, out: http::Reply, from: i64, spill: u8[>..]&, budget: Budget&) {
    guard (x.mode & KEPT) != 0 else { return; }
    if out.buf.len == from {
        guard !out.stream.waiting && (x.mode & LATER) == 0 else { return; }
        drop_kept(x, spill, budget);
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
    drop_kept(x, spill, budget);
}

// Frees the run x kept, if any.
fn drop_kept(x: Exchange&, spill: u8[>..]&, budget: Budget&) {
    guard (x.mode & KEPT) != 0 else { return; }
    spill.free_slice(spill[x.at..x.at + x.cap]);
    untrack(budget, x.at);
    x.at = 0;
    x.cap = 0;
    x.head = 0;
    x.mode &= ~KEPT;
}

// What on_later calls H with for ev, an event after the request's first
// call, http::NO_EVENT for nothing, and what serve does itself: a gathered
// body's pieces, and the limit of one gathered or received. Past its limit
// a body gets 413 and the connection closes, as http::body_within does, and
// a gathered one past the budget 503.
fn arrived<S>(ev: http::Event, st: Slot<S>&, out: http::Reply, spill: u8[>..]&, budget: Budget&) -> u8 {
    let x .= st.ex;
    let k = ev.kind;
    if x.mode & GATHERING != 0 {
        if k == http::BODY {
            let status = gather_piece(x, ev.data, spill, budget);
            guard status == 0 else {
                release(x, spill, budget);
                out.keep_alive = false;
                if status == 413 {
                    write_error(out, st.state, 413, "payload_too_large", "", -1, "");
                } else {
                    write_error(out, st.state, 503, "unavailable", "", -1, "", "", RETRY_AFTER);
                }
                return http::NO_EVENT;
            }
        } else if k == http::END {
            return GATHERED;
        } else if k == http::CLOSED {
            release(x, spill, budget);
        }
        return http::NO_EVENT;
    }
    if k == http::CLOSED { return k; }
    // A response begun can't be answered with 504: the route gets its
    // TIMEOUT, unless goose-http gave it at once, before the time
    // rest::pause asked for, having no timer: then the response ends.
    if k == http::TIMEOUT && (x.mode & SENDING) != 0 && out.stream.open {
        guard clock_ns() >= x.due else {
            if (x.mode & CODED) != 0 { end_coded(x, out, ""); } else { http::end(out); }
            x.mode &= KEPT;
            return http::CLOSED;
        }
        return k;
    }
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
    // An upgraded connection's TIMEOUT can't be answered with 504, its 101
    // being sent: the route gets it.
    if ((k == http::BODY || k == http::TIMEOUT) && (x.mode & UPGRADED) != 0) ||
       (k == http::END && (x.mode & RECEIVING) != 0) || (k == http::MORE && (x.mode & SENDING) != 0) {
        return k;
    }
    return http::NO_EVENT;
}

// What follows a call to H for k, which wrote out.buf from before: the
// gathering rest::body left the route for, the BODY and END of a body that
// came whole, or CLOSED for a route that answered before its body's END or
// that rest::route cut short (route), as the end of its exchange.
fn after<S>(ev: http::Event, st: Slot<S>&, out: http::Reply, spill: u8[>..]&, budget: Budget&, k: u8,
            before: i64) -> u8 {
    let x .= st.ex;
    if k == http::CLOSED {
        if (x.mode & CODED) != 0 { release_coded(x, out.fd); }
        x.mode &= KEPT;
        return http::NO_EVENT;
    }
    if (x.mode & GATHERING) != 0 {
        guard k == GATHERED else {
            if out.buf.len == before { gather_head(x, ev.req, spill, budget); } else { x.mode &= ~GATHERING; }
            return http::NO_EVENT;
        }
        release(x, spill, budget);
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

// The run a chunked body's gathering starts with, which doubles as it fills.
let CHUNKED_RUN = 16384;

// The bytes of the run req's body is gathered into at first: the head
// gather_head rebuilds, and the body's length, or for a chunked body
// CHUNKED_RUN in all.
fn run_size(req: const http::Request&) -> i64 {
    let head = req.method.len + 1 + req.target.len + " HTTP/1.x\r\n".len + req.fields.len + 2;
    return if req.chunked { max(head, CHUNKED_RUN) } else { head + req.body };
}

// Starts g's run with the head rebuilt from req, whose bytes goose-http
// reuses once its handler returns, and records it in budget. A body with a
// Content-Length gets a run of the head and the body's exact size, which
// never grows or moves; a chunked one, of CHUNKED_RUN bytes. rest::body has
// checked that it fits.
fn gather_head(g: Exchange&, req: const http::Request&, spill: u8[>..]&, budget: Budget&) {
    var head: u8[>..] = [];
    head.append(req.method);
    head.push(' ');
    head.append(req.target);
    head.append(" HTTP/1.");
    format(head, req.minor);
    head.append("\r\n");
    head.append(req.fields);
    head.append("\r\n");
    let cap = run_size(req);
    let run = spill.alloc_slice(cap);
    copy_into(run[..head.len], head);
    g.at = spill.index_of(run[0]);
    g.cap = cap;
    g.head = head.len;
    g.len = head.len;
    track(budget, g.at, cap, spill.len);
}

// Appends data to g's run, doubling it when it's full, or growing it only as
// far as data needs when a doubled run would take the spill past the budget.
// Returns 0, or 413 for a body that would pass g's limit, or 503 for one
// that the spill can't hold within the budget.
fn gather_piece(g: Exchange&, data: const u8[:], spill: u8[>..]&, budget: Budget&) -> i32 {
    let n = g.len + data.len;
    guard n - g.head <= g.limit else { return 413; }
    let at, cap = grow_run(g.at, g.cap, n, spill, budget);
    guard cap > 0 else { return 503; }
    g.at = at;
    g.cap = cap;
    copy_into(spill[g.at + g.len..g.at + n], data);
    g.len = n;
    return 0;
}

// The run at at, of cap bytes, or a new one for a cap of 0, made to hold n
// bytes, and recorded in budget: as it is when it holds them already, or
// else doubled, or grown only as far as n when a doubled run would take the
// spill past the budget. Returns its start and its capacity, or a capacity
// of 0, the run left as it was, when the spill can't hold n bytes within the
// budget.
fn grow_run(at: i64, cap: i64, n: i64, spill: u8[>..]&, budget: Budget&) -> i64, i64 {
    guard n > cap else { return at, cap; }
    var want = max(n, cap * 2);
    if placed_end(budget, at, cap, want) > budget.size { want = n; }
    guard placed_end(budget, at, cap, want) <= budget.size else { return at, 0; }
    var start: i64 = 0;
    if cap > 0 {
        let run = spill.realloc_slice(spill[at..at + cap], want);
        untrack(budget, at);
        start = spill.index_of(run[0]);
    } else {
        let run = spill.alloc_slice(want);
        start = spill.index_of(run[0]);
    }
    track(budget, start, want, spill.len);
    return start, want;
}

// The length the spill has once the run at at, of cap bytes, grows to n, or
// once it places a new run of n for a cap of 0.
fn placed_end(b: const Budget&, at: i64, cap: i64, n: i64) -> i64 {
    return if cap > 0 { grown_end(b, at, cap, n) } else { spill_end(b, n, -1) };
}

// A collected reply's run starts with the reply's length and the run's
// capacity, 8 bytes each, least significant first.
let REPLY_HEAD = 16;

// Adds data, a piece with tag of a reply its lane marked REPLY_VALUE, to the
// run of the spill the exchange collects it in, from x.due with COLLECTING,
// and has the route wait for the next piece while more follows, with the
// time limit rest::ask gave. Returns true once the reply is whole, for
// on_event to call the handler with it, and false while more follows, or
// for a reply the spill can't hold within the budget: then the run is freed
// and the route answered 502 reply_too_large, or cut short with its response
// begun, and the later pieces find the exchange no longer waiting.
fn collect_reply<S>(st: Slot<S>&, data: const u8[:], tag: i32, out: http::Reply, spill: u8[>..]&,
                    budget: Budget&) -> bool {
    let x .= st.ex;
    var at: i64 = 0;
    var cap: i64 = 0;
    var len: i64 = 0;
    if (x.mode & COLLECTING) != 0 {
        at = x.due;
        len = word(spill, at);
        cap = word(spill, at + 8);
    }
    let n = REPLY_HEAD + len + data.len;
    let start, room = grow_run(at, cap, n, spill, budget);
    guard room > 0 else {
        drop_reply(x, spill, budget);
        end_wait(st, out, spill, budget, 502, "reply_too_large", true);
        return false;
    }
    copy_into(spill[start + REPLY_HEAD + len..start + n], data);
    set_word(spill, start, len + data.len);
    set_word(spill, start + 8, room);
    x.due = start;
    x.mode |= COLLECTING;
    guard (tag & REPLY_MORE) == 0 else {
        http::later(out, out.stream.wait_ms);
        return false;
    }
    return true;
}

// The reply x collected, for a last piece with tag, or else data, the
// message, as a refusal is.
fn collected(x: const Exchange&, data: const u8[:], tag: i32, spill: const u8[:]) -> const u8[:] {
    guard (x.mode & COLLECTING) != 0 && (tag & REPLY_VALUE) != 0 else { return data; }
    let from = x.due + REPLY_HEAD;
    return spill[from..from + word(spill, x.due)];
}

// Frees the run of the reply x collects, if any.
fn drop_reply(x: Exchange&, spill: u8[>..]&, budget: Budget&) { drop_run(x, x.due, spill, budget); }

// drop_reply for a run that starts at at, which due holds unless a pause has
// set it since: then due keeps the pause's deadline.
fn drop_run(x: Exchange&, at: i64, spill: u8[>..]&, budget: Budget&) {
    guard (x.mode & COLLECTING) != 0 else { return; }
    spill.free_slice(spill[at..at + word(spill, at + 8)]);
    untrack(budget, at);
    if x.due == at { x.due = 0; }
    x.mode &= ~COLLECTING;
}

fn word(b: const u8[:], at: i64) -> i64 {
    var v: i64 = 0;
    for i in 8 {
        let byte: i64 = b[at + i];
        v |= byte << (i * 8);
    }
    return v;
}

fn set_word(b: u8[>..]&, at: i64, v: i64) {
    for i in 8 { b[at + i] = ((v >> (i * 8)) & 0xFF) as u8; }
}

// Answers status and code for a route whose wait ended without a reply for
// it, with the fields its middleware kept, which it then frees. A response
// begun, or an upgraded connection, isn't answered: with cut, it's cut
// short, as a failure cuts it (route), and without, the route gets the
// event (on_later).
fn end_wait<S>(st: Slot<S>&, out: http::Reply, spill: u8[>..]&, budget: Budget&, status: i32, code: const u8[:],
               cut: bool) {
    var fields: u8[>..] = [];
    var o = out;
    o.common = kept_fields(out.common, st.ex, spill, fields);
    let from = out.buf.len;
    if !out.stream.open {
        write_error(o, st.state, status, code, "", -1, "");
    } else if cut {
        out.stream.open = false;
        out.keep_alive = false;
    }
    settle_kept(st.ex, o, from, spill, budget);
    drop_kept(st.ex, spill, budget);
}

// Frees g's run of the spill, and stops gathering.
fn release(g: Exchange&, spill: u8[>..]&, budget: Budget&) {
    if g.cap > 0 {
        spill.free_slice(spill[g.at..g.at + g.cap]);
        untrack(budget, g.at);
    }
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
// runs twice up to its first rest::body. A body the worker's spill can't
// place within its gather budget fails with 503 unavailable and Retry-After
// (Config). After rest::body_in_pieces, 500 body_already_read.
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
        if !fits(cx.budget, run_size(cx.req)) {
            return [Failure { status: 503, at: -1, code: str("unavailable"), detail: "", challenge: "", retry: true }]
                from attempt;
        }
        g.mode |= GATHERING;
        return [Failure { status: 0, at: -1, code: "", detail: "", challenge: "" }] from attempt;
    }
    if cx.body.len > g.limit { fail(cx, 413, "payload_too_large"); }
    return cx.body;
}

// Whether the spill can place a run of n bytes within budget; any without
// one.
fn fits(budget: const Budget?, n: i64) -> bool {
    guard budget else { return true; }
    return spill_end(budget, n, -1) <= budget.size;
}

// The length the spill has once it places a run of n bytes, as
// alloc_slice places it (spec §5.4): every byte of the spill outside the
// runs in use is free, so at the first start, 0 or a run's end, with n free
// bytes after it, or else after the last run, growing the spill. skip, a
// run's start or -1, is left out, as realloc_slice frees a run it moves.
fn spill_end(b: const Budget&, n: i64, skip: i64) -> i64 {
    if free_at(b, 0, n, skip) { return b.len; }
    var last: i64 = 0;
    for r in b.runs {
        if r.cap > 0 && r.at != skip {
            if free_at(b, r.at + r.cap, n, skip) { return b.len; }
            last = max(last, r.at + r.cap);
        }
    }
    return max(b.len, last + n);
}

// Whether the n bytes from at are inside the spill and in no run but skip.
fn free_at(b: const Budget&, at: i64, n: i64, skip: i64) -> bool {
    guard at + n <= b.len else { return false; }
    for r in b.runs {
        if r.cap > 0 && r.at != skip && r.at < at + n && at < r.at + r.cap { return false; }
    }
    return true;
}

// The length the spill has once the run at at, of cap bytes, grows to n, as
// realloc_slice grows it: in place when no run follows it or the free bytes
// after it hold the growth, or else moved where spill_end places it.
fn grown_end(b: const Budget&, at: i64, cap: i64, n: i64) -> i64 {
    var next: i64 = -1;
    for r in b.runs {
        if r.cap > 0 && r.at > at && (next < 0 || r.at < next) { next = r.at; }
    }
    if next < 0 { return max(b.len, at + n); }
    if next - at >= n { return b.len; }
    return spill_end(b, n, at);
}

// Records the run the spill handed out at at, of cap bytes, and its length
// len after.
fn track(b: Budget&, at: i64, cap: i64, len: i64) {
    b.len = len;
    for i in b.runs.len {
        if b.runs[i].cap == 0 {
            b.runs[i] = Run { at: at, cap: cap };
            return;
        }
    }
    b.runs.push(Run { at: at, cap: cap });
}

// Records that the run at at is free.
fn untrack(b: Budget&, at: i64) {
    for i in b.runs.len {
        if b.runs[i].cap > 0 && b.runs[i].at == at {
            b.runs[i].cap = 0;
            return;
        }
    }
}

// What fail answers with: challenge, when not empty, goes in a
// WWW-Authenticate field, and retry asks for a Retry-After. Its text is
// owned: a long-distance return can't carry a slice of the request
// (docs/goose-findings.md).
struct Failure { status: i32, at: i64, code: u8[], detail: u8[], challenge: u8[], retry: bool = false }

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
            write_error(cx.out, cx.state, f.status, f.code, f.detail, f.at, "", f.challenge,
                        if f.retry { RETRY_AFTER } else { "" });
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
// request state, an Allow field when allow isn't empty, a
// WWW-Authenticate field when challenge isn't, and a Retry-After when
// retry_after isn't.
fn write_error(out: http::Reply, st, status: i32, code: const u8[:], detail: const u8[:], at: i64,
               allow: const u8[:], challenge: const u8[:] = "", retry_after: const u8[:] = "") {
    var body: u8[>..] = [];
    error_body(body, st, status, code, detail, at);
    http::start(out, status);
    if allow.len > 0 { http::field(out, "Allow", allow); }
    if challenge.len > 0 { http::field(out, "WWW-Authenticate", challenge); }
    if retry_after.len > 0 { http::field(out, "Retry-After", retry_after); }
    http::finish(out, http::JSON, body);
}

// The error shape: {"error": code}, with "detail" when detail isn't empty,
// and "at" when at isn't negative. A program writes its own shape with an
// overload for its request state's type, which wins over this generic
// one: fn rest::error_body(body: u8[>..]&, st: const app::St&, status: i32,
// code: const u8[:], detail: const u8[:], at: i64).
fn error_body(body: u8[>..]&, st, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
    body.append("{\"error\":");
    http::json_string(body, code);
    if detail.len > 0 {
        body.append(",\"detail\":");
        http::json_string(body, detail);
    }
    if at >= 0 {
        body.append(",\"at\":");
        format(body, at);
    }
    body.push('}');
}
