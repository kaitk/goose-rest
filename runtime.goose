// The runtime: a request's context, routes that fail from any depth below
// them, and answers in JSON, every error in one shape, goose-rest's or the
// program's (docs/reference.md, "Errors").
namespace rest;

import std;
import json;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";

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
    // More follows: at a WAKE, more of the reply (rest::relay); at serve's
    // REQUEST, more of the body than came with the head (rest::body).
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

// Runs F(c) as the request's one route, c being cx with a router over its
// request, so that the block's rest::get and its kin, rest::scope,
// rest::param, and rest::route take c alone. When the block leaves the
// request unanswered, with nothing awaited, routes answers it as
// rest::otherwise does: 404, 405 with Allow, OPTIONS, and 501. A generated
// dispatch inside the block answers with the Allow of the routes tried
// before it.
//
//   rest::routes(cx) { cx =>
//       rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
//   };
inline fn routes<S, A, F>(cx: Cx<S, A, NoRouter>&) {
    let mark = cx.out.buf.len;
    var r = http::router(cx.req);
    var c = Cx<S, A, http::Router> { req: cx.req, body: cx.body, out: cx.out, state: cx.state,
                       app: cx.app, scratch: cx.scratch,
                       kind: cx.kind, reply: cx.reply, refused: cx.refused, more: cx.more, ex: cx.ex,
                       kept: cx.kept, router: r };
    routed(c) {
        // A block, or a function's untyped parameter, given the local
        // itself gets a copy of it, which gcc keeps where the call stays one.
        F(&c);
        settle(&c, mark);
    };
}

// Answers as rest::otherwise does when the routes tried since mark left the
// request unanswered.
fn settle(cx, mark: i64) {
    guard unanswered(cx, mark) else { return; }
    otherwise(cx);
}

// Marks the request taken: the router's bad, which http::on and rest::scope
// check first, so that the routes and scopes after it in rest::routes'
// block don't match. Outside rest::routes, nothing.
fn taken<S, A>(cx: Cx<S, A, http::Router>&) { cx.router.bad = true; }

fn taken<S, A>(cx: Cx<S, A, NoRouter>&) {}

// Whether no route before has taken the request, for a generated dispatch
// after a program's own routes.
fn untaken<S, A>(cx: const Cx<S, A, http::Router>&) -> bool { !cx.router.bad }

fn untaken<S, A>(cx: const Cx<S, A, NoRouter>&) -> bool { true }

// Runs F, inside rest::routes as a route of its own: a failure inside F is
// answered there, and a request F leaves unanswered gets rest::routes'
// answer there, so that both are answered inside the middleware that calls
// scoped, with the fields it adds. The request is then taken. Middleware
// that adds fields to answers, or answers itself, runs its block in it;
// outside rest::routes, scoped only runs F.
//
//   inline fn branded<F>(cx) {
//       let common = cx.out.common;
//       cx.out.common = BRAND;   // "X-Brand: acme\r\n"
//       rest::scoped(cx) { F(); };
//       cx.out.common = common;
//   }
inline fn scoped<S, A, F>(cx: Cx<S, A, http::Router>&) {
    let mark = cx.out.buf.len;
    routed(cx) { F(); };
    settle(cx, mark);
    taken(cx);
}

inline fn scoped<S, A, F>(cx: Cx<S, A, NoRouter>&) { F(); }

// Whether cx's response is still unwritten from mark, with no reply, body,
// or room to send awaited, as serve's settle_kept tells.
fn unanswered(cx, mark: i64) -> bool {
    guard cx.out.buf.len == mark && !cx.out.stream.waiting else { return false; }
    var x .= cx.ex;
    return !(x && (x.mode & LATER) != 0);
}

// The request state, or the worker state, of a program that keeps none.
struct NoState { unused: bool = false }

// The most bytes of a body rest::body takes unless a route says otherwise.
let BODY_LIMIT = 1024 * 1024;

// The worker's gather budget is goose-http's, http::gather_budget, which a
// program sets in main before http::run. It bounds the bodies rest::body
// gathers, heads included, the replies rest::ask waits for, at its reply
// limit each, and what the middleware keeps for an answer at a later call.
// A body the budget can't promise its bytes gets 503 unavailable with
// Retry-After at its head, and a rest::ask the same before its job is sent.
// Bodies read with rest::body_in_pieces, and replies relayed, take nothing
// beyond their promise.
//
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
// ASKED says the exchange holds a promise for the reply rest::ask waits for,
// which collects a reply_value's pieces (collect_reply). PAUSED says the
// route paused before beginning a response (rest::pause).
let GATHERING: u16 = 1;
let RECEIVING: u16 = 2;
let SENDING: u16 = 4;
let UPGRADED: u16 = 8;
let LATER: u16 = 15;
let KEPT: u16 = 16;
let OFFERED: u16 = 32;
let CODED: u16 = 64;
let ASKED: u16 = 128;
let PAUSED: u16 = 256;

// What serve keeps of a request past the handler's first call. run is a run
// of the worker's gather pool: a body gathered for rest::body, the head
// rebuilt (run.head bytes) and then the body so far, or with KEPT, what
// stash_kept wrote, run.head being the length of its fields: a route keeps
// it only once its body is gathered. A body received in pieces counts its
// bytes down from limit, which a route reading pieces keeps fields beside.
// With ASKED, reply is the entry of replies that holds the reply's promise
// and its run.
struct Exchange {
    mode: u16 = 0,
    limit: i64 = 0,          // the first rest::body's or rest::body_in_pieces's limit, 0 before it
    run: http::Gather = http::Gather { .. },
    reply: i64 = 0,
}

// Each worker's runs for the replies its routes wait for, found by
// Exchange.reply: a Gather in every exchange would cost every connection's
// slot 40 bytes for routes that never ask.
reusable var replies: http::Gather[>..] = [];

// goose-http's state for each request: the program's, and the exchange's.
struct Slot<S> { state: S, ex: Exchange = Exchange { .. } }

// Serves cfg with goose-http's loop, calling H(cx) for each request, and again
// for each later event a route asked for: a reply from another thread
// (waiting.goose), or a piece of a body, room to send more, or an upgraded
// connection's bytes (pieces.goose). app, the worker state, is in cx.app,
// and the request state, starting from fresh, in cx.state. A body that
// doesn't come with its head is gathered when a route asks for it
// (rest::body), and H runs again once it's whole, within the worker's
// gather budget (http::gather_budget).
//
//   var app = App { .. };
//   rest::serve(cfg, app) { cx => handle(cx) };
fn serve<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    return http::serve(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        // Here, not in on_event: a function holding a call given a block
        // that stays a call isn't inlined.
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
    };
}

// serve on goose-http's epoll loop, http::serve_epoll, rather than its
// io_uring loop. Its block repeats serve's: shared as an inline fn, gcc
// emitted it out of line, about 200 more instructions per request on Linux
// (2026-10-22).
fn serve_epoll<A, S, H>(cfg: http::Config, app: A&, fresh: S) -> http::Error {
    return http::serve_epoll(cfg, Slot<S> { state: fresh }) { ev, st, out =>
        let mark = on_event(ev, st, app, out) { cx => H(cx) };
        if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, mark) { cx => H(cx) }; }
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
// sends on itself; and 504 when a reply doesn't come in time, or 503 when
// goose-http had no room for the wait, except on an upgraded connection,
// whose route on_later calls with the TIMEOUT. A reply cut short by its
// time limit leaves the response open, and goose-http closes the
// connection. An answer after REQUEST gets the fields its middleware kept
// (stash_kept). Returns out.buf.len from before its call to H, or after a
// reply past its limit, or -1 for none, for on_later, which the caller then
// calls for a route that reads, sends, or upgrades (Exchange.mode).
inline fn on_event<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply) -> i64 {
    if ev.kind == http::WAKE && (ev.tag & (REPLY_CONT | REPLY_VALUE)) != 0 {
        if (ev.tag & REPLY_VALUE) == 0 {
            relay_piece(out, ev.data, (ev.tag & REPLY_MORE) != 0);
            return -1;
        }
        // A reply past its limit, with ASKED cleared, goes on to after,
        // which gives CLOSED to a route whose response it cut.
        if (ev.tag & (REPLY_CONT | REPLY_MORE)) != 0 && !collect_reply(st, ev.data, ev.tag, out) {
            return if (st.ex.mode & ASKED) != 0 { -1 } else { out.buf.len };
        }
    }
    // A TIMEOUT tagged NO_ROOM is goose-http's, given at once for want of a
    // timer: a refusal at admission, 503, where a wait that ran out gets 504.
    // A pause's own goes to H below, as a WAKE does, so that the handler is
    // inlined at one call here.
    if ev.kind == http::TIMEOUT {
        let paused = (st.ex.mode & PAUSED) != 0;
        let no_room = (ev.tag & http::NO_ROOM) != 0;
        st.ex.mode &= ~PAUSED;
        guard paused && !no_room else {
            let refused = paused || no_room;
            drop_reply(st.ex);
            end_wait(st, out, if refused { 503 } else { 504 }, if refused { "unavailable" } else { "timeout" }, false,
                     if refused { RETRY_AFTER } else { "" });
            return -1;
        }
    }
    if ev.kind == http::CLOSED {
        drop_kept(st.ex);
        drop_reply(st.ex);
    }
    var mark: i64 = -1;
    if ev.kind == http::REQUEST || ev.kind == http::WAKE || ev.kind == http::TIMEOUT {
        var scratch: u8[>..] = [];
        var fields: u8[>..] = [];
        var kept = Kept { .. };
        let wake = ev.kind != http::REQUEST;
        mark = out.buf.len;
        var o = out;
        if wake { o.common = kept_fields(out.common, st.ex, fields); }
        // The wait's reply, which H reads, and frees after it: H may ask again.
        var done: i64 = -1;
        if wake && (st.ex.mode & ASKED) != 0 {
            done = st.ex.reply;
            st.ex.mode &= ~ASKED;
        }
        var none = NoRouter { .. };
        var cx = Cx<S, A, NoRouter> { req: ev.req, body: if wake { "" } else { ev.data }, out: o, state: st.state,
                                      app: app, scratch: scratch, kind: ev.kind,
                                      reply: if wake { collected(done, ev.data, ev.tag) } else { "" },
                                      refused: wake && (ev.tag & REPLY_REFUSED) != 0,
                                      more: if wake { (ev.tag & REPLY_MORE) != 0 } else { !ev.whole },
                                      ex: st.ex, kept: kept, router: none };
        H(cx);
        if wake {
            settle_kept(st.ex, o, mark);
            if done >= 0 { free_reply(done); }
        } else if kept.taken {
            if stash_kept(kept, scratch, out.common, ev.req, st.ex.run) {
                st.ex.mode |= KEPT;
            } else {
                refuse_kept(st, out, scratch[kept.from..kept.to]);
            }
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
fn on_later<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, mark: i64) {
    var fields: u8[>..] = [];
    var o = out;
    o.common = kept_fields(out.common, st.ex, fields);
    let from = out.buf.len;
    var k = if mark >= 0 { after(ev, st, o, ev.kind, mark) } else { arrived(ev, st, o) };
    while k != http::NO_EVENT {
        let before = out.buf.len;
        let gathered = k == GATHERED;
        let g = st.ex.run;
        let head = head_of(ev.req, gathered, g);
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
                                      body: if gathered { http::gathered[g.at + g.head..g.at + g.len] }
                                            else if k == http::BODY { ev.data } else { "" },
                                      out: r, state: st.state, app: app, scratch: scratch,
                                      kind: if gathered { http::REQUEST } else { k }, ex: st.ex, kept: kept,
                                      router: none };
        H(cx);
        // Stashed before after releases the gathered run, which head points into.
        var stash = http::Gather { .. };
        if gathered && kept.taken && !stash_kept(kept, scratch, out.common, head, stash) {
            refuse_kept(st, out, scratch[kept.from..kept.to]);
        }
        k = after(ev, st, o, k, before);
        if stash.most > 0 {
            st.ex.run = stash;
            st.ex.mode |= KEPT;
        }
    }
    // A route that stopped the wait at a later call, or ended, as with
    // rest::end on an upgraded connection, whose wait goose-http clears only
    // once the handler returns, gets no more of the reply it collected. A
    // route that receives its body has no stream open, and still waits.
    if !out.stream.waiting || (!out.stream.open && (st.ex.mode & LATER) == 0) { drop_reply(st.ex); }
    settle_kept(st.ex, o, from);
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

// Copies what k holds into g, a run of the gather pool promised its exact
// size: begun, the flags, its fields in scratch past base, the loop's common
// fields, which are the current ones at the later answer, and for the log
// req's method and target, with g.head the length of its fields. Returns
// false, keeping nothing, when the worker's budget can't promise the run.
fn stash_kept(k: const Kept&, scratch: const u8[:], base: const u8[:], req: const http::Request&,
              g: http::Gather&) -> bool {
    let all = scratch[k.from..k.to];
    let fields = if k.taken && starts_with(all, base) { all[base.len..] } else { "" };
    let line = if k.timed && k.log { req.method.len + 1 + req.target.len } else { 0 };
    guard http::gather_promise(g, KEPT_HEAD + fields.len + line) else { return false; }
    var head: u8[..KEPT_HEAD] = [];
    for i in 8 { head.push(((k.begun >> (i * 8)) & 0xFF) as u8); }
    head.push((if k.timed { KEPT_TIMED } else { 0 }) | (if k.log { KEPT_LOG } else { 0 }));
    http::gather_piece(g, head);
    http::gather_piece(g, fields);
    if line > 0 {
        http::gather_piece(g, req.method);
        http::gather_piece(g, " ");
        http::gather_piece(g, req.target);
    }
    g.head = fields.len;
    return true;
}

// Answers 503 unavailable, with common for its fields, for a route that
// left its answer to a later call when the worker's budget can't keep what
// its middleware decided for it: the wait ends, and a route reading its body
// gets CLOSED (after).
fn refuse_kept<S>(st: Slot<S>&, out: http::Reply, common: const u8[:]) {
    out.stream.waiting = false;
    out.stream.rearm = false;
    drop_reply(st.ex);
    var o = out;
    o.common = common;
    write_error(o, st.state, 503, "unavailable", "", -1, "", "", RETRY_AFTER);
}

// common, or with KEPT, common and then the fields x kept, onto fields,
// which the result then points into.
fn kept_fields(common: const u8[:], x: const Exchange&, fields: u8[>..]&) -> const u8[:] {
    guard (x.mode & KEPT) != 0 else { return common; }
    fields.append(common);
    fields.append(http::gathered[x.run.at + KEPT_HEAD..x.run.at + KEPT_HEAD + x.run.head]);
    return fields;
}

// Ends what x kept once out's buffer has an answer from from, its head
// first: fills in its Server-Timing and writes timed's log line, then frees
// the run. Frees it also once the exchange owes the route no more calls,
// as when goose-http answers 500 for a route that didn't.
fn settle_kept(x: Exchange&, out: http::Reply, from: i64) {
    guard (x.mode & KEPT) != 0 else { return; }
    if out.buf.len == from {
        guard !out.stream.waiting && (x.mode & LATER) == 0 else { return; }
        drop_kept(x);
        return;
    }
    let run = http::gathered[x.run.at..x.run.at + x.run.len];
    let flags = run[8];
    if (flags & KEPT_TIMED) != 0 {
        var begun: i64 = 0;
        for i in 8 {
            let b: i64 = run[i];
            begun |= b << (i * 8);
        }
        var ms: u8[..32] = [];
        format_ms(ms, clock_ns() - begun);
        let fields = run[KEPT_HEAD..KEPT_HEAD + x.run.head];
        let at = find(fields, TIMING);
        if at >= 0 { fill_timing(out, from, out.common.len - fields.len + at, ms); }
        if (flags & KEPT_LOG) != 0 {
            write_stderr(str(run[KEPT_HEAD + x.run.head..], " ", out.stream.status, " ", out.buf.len - from, " ", ms,
                             "\n"));
        }
    }
    drop_kept(x);
}

// Frees the run x kept, if any.
fn drop_kept(x: Exchange&) {
    guard (x.mode & KEPT) != 0 else { return; }
    http::release_gather(x.run);
    x.mode &= ~KEPT;
}

// What on_later calls H with for ev, an event after the request's first
// call, http::NO_EVENT for nothing, and what serve does itself: a gathered
// body's pieces, and the limit of one gathered or received. Past its limit
// a body gets 413 and the connection closes, as http::body_within does.
fn arrived<S>(ev: http::Event, st: Slot<S>&, out: http::Reply) -> u8 {
    let x .= st.ex;
    let k = ev.kind;
    if x.mode & GATHERING != 0 {
        if k == http::BODY {
            // The run was promised the limit, which only a chunked body can pass.
            guard http::gather_piece(x.run, ev.data) else {
                release(x);
                out.keep_alive = false;
                write_error(out, st.state, 413, "payload_too_large", "", -1, "");
                return http::NO_EVENT;
            }
        } else if k == http::END {
            return GATHERED;
        } else if k == http::CLOSED {
            release(x);
        }
        return http::NO_EVENT;
    }
    if k == http::CLOSED { return k; }
    // A response begun can't be answered with 504: the route gets its
    // TIMEOUT, unless goose-http gave it at once, having no timer
    // (NO_ROOM): then the response ends.
    if k == http::TIMEOUT && (x.mode & SENDING) != 0 && out.stream.open {
        guard (ev.tag & http::NO_ROOM) == 0 else {
            if (x.mode & CODED) != 0 { end_coded(x, out, ""); } else { http::end(out); }
            x.mode &= KEPT;
            return http::CLOSED;
        }
        return k;
    }
    if k == http::BODY && (x.mode & RECEIVING) != 0 {
        x.limit -= ev.data.len;
        guard x.limit >= 0 else {
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
fn after<S>(ev: http::Event, st: Slot<S>&, out: http::Reply, k: u8, before: i64) -> u8 {
    let x .= st.ex;
    if k == http::CLOSED {
        if (x.mode & CODED) != 0 { release_coded(x, out.fd); }
        drop_reply(x);
        x.mode &= KEPT;
        return http::NO_EVENT;
    }
    if (x.mode & GATHERING) != 0 {
        // An answer after rest::body left the route, as a middleware's, ends
        // the gathering.
        guard k == GATHERED else {
            if out.buf.len > before { release(x); }
            return http::NO_EVENT;
        }
        release(x);
    }
    let open = out.stream.open;
    if k == http::END { x.mode &= ~RECEIVING; }
    if (x.mode & (SENDING | UPGRADED)) != 0 && !open { return http::CLOSED; }
    if (x.mode & RECEIVING) != 0 {
        if out.buf.len > before && !open { return http::CLOSED; }
        // A body that came whole with its REQUEST goes on as a BODY and an END.
        if ev.whole && k == http::REQUEST { return if ev.data.len > 0 { http::BODY } else { http::END }; }
        if ev.kind == http::REQUEST && k == http::BODY { return http::END; }
    }
    return http::NO_EVENT;
}

// The head of the request H is called for: req, or for a gathered body, the
// head parsed again from its copy in g's run.
fn head_of(req: const http::Request&, gathered: bool, g: const http::Gather&) -> http::Request {
    guard gathered else { return req; }
    let r, status = http::parse(http::gathered[g.at..g.at + g.head], g.head, g.len);
    return r;
}

// The most bytes of a reply rest::ask takes unless a route says otherwise:
// its promise from the worker's gather budget while it waits.
let REPLY_LIMIT: i64 = 64 * 1024;

// Promises the reply x waits for up to most bytes of the worker's gather
// pool, in an entry of replies, or returns false where the budget can't.
fn promise_reply(x: Exchange&, most: i64) -> bool {
    let i = replies.alloc_index(http::Gather { .. });
    guard http::gather_promise(replies[i], most) else {
        replies.free(i);
        return false;
    }
    x.reply = i;
    x.mode |= ASKED;
    return true;
}

// Adds data, a piece with tag of a reply its lane marked REPLY_VALUE, to the
// run that collects it, up to the most rest::ask promised it, and has the
// route wait for the next piece while more follows, with the time limit
// rest::ask gave. Returns true once the reply is whole, for on_event to
// call the handler with it, and false while more follows, or for a reply
// past its limit: then the run is freed and the route answered 502
// reply_too_large, or cut short with its response begun, and the later
// pieces find the exchange no longer waiting.
fn collect_reply<S>(st: Slot<S>&, data: const u8[:], tag: i32, out: http::Reply) -> bool {
    let x .= st.ex;
    guard (x.mode & ASKED) != 0 && http::gather_piece(replies[x.reply], data) else {
        drop_reply(x);
        end_wait(st, out, 502, "reply_too_large", true);
        return false;
    }
    guard (tag & REPLY_MORE) == 0 else {
        http::later(out, out.stream.wait_ms);
        return false;
    }
    return true;
}

// The reply in the entry done of replies, for a last piece with tag, or else
// data, the message, as a refusal is.
fn collected(done: i64, data: const u8[:], tag: i32) -> const u8[:] {
    guard done >= 0 && (tag & REPLY_VALUE) != 0 && replies[done].len > 0 else { return data; }
    let g = replies[done];
    return http::gathered[g.at..g.at + g.len];
}

// Frees the promise and the run of the reply x waits for, if any.
fn drop_reply(x: Exchange&) {
    guard (x.mode & ASKED) != 0 else { return; }
    free_reply(x.reply);
    x.mode &= ~ASKED;
}

fn free_reply(i: i64) {
    http::release_gather(replies[i]);
    replies.free(i);
}

// Answers status and code for a route whose wait ended without a reply for
// it, with the fields its middleware kept, which it then frees. A response
// begun, or an upgraded connection, isn't answered: with cut, it's cut
// short, as a failure cuts it (route), and without, the route gets the
// event (on_later).
fn end_wait<S>(st: Slot<S>&, out: http::Reply, status: i32, code: const u8[:], cut: bool,
               retry_after: const u8[:] = "") {
    var fields: u8[>..] = [];
    var o = out;
    o.common = kept_fields(out.common, st.ex, fields);
    let from = out.buf.len;
    if !out.stream.open {
        write_error(o, st.state, status, code, "", -1, "", "", retry_after);
    } else if cut {
        out.stream.open = false;
        out.keep_alive = false;
    }
    settle_kept(st.ex, o, from);
    drop_kept(st.ex);
}

// Frees x's gathered run, and stops gathering.
fn release(x: Exchange&) {
    http::release_gather(x.run);
    x.mode &= ~GATHERING;
}

// The request's body, of at most limit bytes: a longer one fails the route
// with 413 payload_too_large. The first call's limit holds for the request.
// A body that hasn't come with the head leaves the route without an answer:
// serve gathers it and calls the handler again with it whole, so a route
// runs twice up to its first rest::body. A body the worker's gather budget
// can't promise its bytes, a Content-Length's or a chunked body's limit,
// with its head, fails with 503 unavailable and Retry-After (http::gather_budget). After
// rest::body_in_pieces, 500 body_already_read, and at a later call than the
// request's, 500 body_too_late: the head that gathering needs has gone by
// then.
fn body<S, A, R>(cx: Cx<S, A, R>&, limit: i64 = BODY_LIMIT) -> const u8[:] {
    var g .= cx.ex;
    guard g else {
        if cx.body.len > limit { fail(cx, 413, "payload_too_large"); }
        return cx.body;
    }
    guard cx.kind == http::REQUEST else { fail(cx, 500, "body_too_late"); }
    guard (g.mode & RECEIVING) == 0 else { fail(cx, 500, "body_already_read"); }
    if g.limit == 0 { g.limit = limit; }
    if cx.more {
        if !cx.req.chunked && cx.req.body > g.limit { fail(cx, 413, "payload_too_large"); }
        if !http::gather_head(g.run, cx.req, g.limit) { unavailable(cx); }
        g.mode |= GATHERING;
        return [Failure { status: 0, at: -1, code: "", detail: "", challenge: "" }] from attempt;
    }
    if cx.body.len > g.limit { fail(cx, 413, "payload_too_large"); }
    return cx.body;
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
// calls fails. Inside rest::routes, F joins the request's one route there:
// a function that fails returns to the innermost route, and a route inside
// a route keeps both out of line.
inline fn route<S, A, F>(cx: Cx<S, A, NoRouter>&) { routed(cx) { F(); }; }

inline fn route<S, A, F>(cx: Cx<S, A, http::Router>&) { F(); }

// The route around F. The first answer wins: a failure after the handler
// wrote an answer leaves it as it is, and one with a response open, its head
// sent, cuts it short: the response stays unended and the connection closes,
// so the client sees it end early. routed can't take an answer back, since
// shrinking the write buffer is refused while a slice of the request is live
// (spec §5.1: a parameter's slices may point into any array of their type).
inline fn routed<F>(cx) {
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

// Leaves the enclosing route with 503 unavailable and Retry-After, for what
// the worker's gather budget can't promise.
fn unavailable(cx) {
    return [Failure { status: 503, at: -1, code: str("unavailable"), detail: "", challenge: "", retry: true }]
        from attempt;
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

// Answers a request whose method is unknown, or whose path the router
// refuses, as otherwise does: 501 or 400.
fn no_route(cx, method: const u8[:], path: const u8[:]) {
    unrouted(cx, http::unrouted(method, path, http::is_routable(path), ""), "");
}

// Answers a request whose method is known and whose path is routable, as
// the generated routers have checked by then, and that no route matched, as
// otherwise does: inside rest::routes, with the Allow of the program's routes
// before dispatch.
fn not_found<S, A>(cx: Cx<S, A, http::Router>&, method: const u8[:], path: const u8[:]) {
    unrouted(cx, http::unrouted(cx.router), cx.router.allow);
}

fn not_found<S, A>(cx: Cx<S, A, NoRouter>&, method: const u8[:], path: const u8[:]) {
    unrouted(cx, http::unrouted(method, path, true, ""), "");
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
// 204 with that Allow, or for "*" without one. After a route that took the
// request, it answers nothing. rest::routes answers so itself when its block
// doesn't; a program that builds its own http::router passes it.
fn otherwise<S, A>(cx: Cx<S, A, http::Router>&) { otherwise(cx, cx.router); }

fn otherwise(cx, r: const http::Router&) {
    // bad marks a taken request as well as a path the router refused.
    guard !r.bad || !http::is_routable(http::path_of(cx.req.target)) else { return; }
    unrouted(cx, http::unrouted(r), r.allow);
}

// Answers a request no route took with status, http::unrouted's, and allow
// in Allow for a 204 or 405, each error in the program's shape. Each arm
// writes a constant status, which the inline writers fold.
fn unrouted(cx, status: i32, allow: const u8[:]) {
    match status {
        204 => {
            http::start(cx.out, 204);
            if allow.len > 0 { http::field(cx.out, "Allow", allow); }
            http::finish(cx.out, http::NO_TYPE, "");
        },
        405 => write_error(cx.out, cx.state, 405, "method_not_allowed", "", -1, allow),
        501 => write_error(cx.out, cx.state, 501, "not_implemented", "", -1, ""),
        400 => write_error(cx.out, cx.state, 400, "bad_path", "", -1, ""),
        _ => write_error(cx.out, cx.state, 404, "not_found", "", -1, ""),
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
    http::finish(out, error_type(st), body);
}

// finish's fields for errors, selected by the request state's type as
// error_body is. The default stays a compile-time constant.
inline fn error_type(st) -> const u8[:] { http::JSON }

// RFC 9457's about:blank problem, using the response's own reason phrase.
// The hook has no request path, so instance is left to a program's writer.
fn problem_body(body: u8[>..]&, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
    let line = http::status_line(status);
    let title = if line.len > 0 { line[13..^2] } else { "" };
    body.append("{\"type\":\"about:blank\",\"title\":");
    http::json_string(body, title);
    body.append(",\"status\":");
    format(body, status);
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
