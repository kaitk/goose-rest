// Waiting on another thread: a route asks a lane, such as a database's, with
// rest::ask, and resumes when its reply comes. Each lane takes its own
// fixed-mode enum of jobs, one variant per use case, and its threads run
// them through the program's run case functions. Goose can't keep a
// function to call later, so the request state keeps the lane's mark, a
// variant of the program's Use, and the reply carries the job back, which
// the mark's resume dispatches on again (spike 11):
//
//   enum Writes { EntryCreate { project: i64, started: i64, stopped: i64 } }
//   enum Use { None, Write }
//   struct St { use: Use = Use.None }
//
//   rest::ask(cx, cx.app.writer, Writes.EntryCreate { .. });          // the route
//   fn run(u: Writes.EntryCreate, w: Writer&, a) { rest::reply_value(a, e); }   // on the lane
//   fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
//   fn resume(u: Writes.EntryCreate, cx) { rest::json(cx, 201, rest::answer<Entry>(cx)); }
//
//   rest::serve(cfg, app, St { .. }) { cx =>
//       if rest::resumed(cx) { rest::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
//   };
//
// The job crosses in a rest::Ask, with the address the reply goes to and
// the size of a reply message, read with http::mail_slot_size. The lane's
// thread replies with rest::reply_value, whose pieces the worker collects
// whole before the resume runs, or rest::reply, in pieces of at most that
// size, which rest::relay sends on as they come; before work worth
// skipping, rest::still_wanted says whether the route still waits. A
// rest::fail on the lane refuses the job, which fails the route with its
// status and code. A route that never asks keeps nothing on the connection
// beyond its state.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.5.0";

// A reply message's tag: REPLY_REFUSED for a job its lane refused, which
// holds a Refusal; REPLY_VALUE on every piece of a reply_value, which the
// worker collects whole before it calls the handler; REPLY_MORE when more of
// the reply follows; REPLY_CONT on every piece after the first.
let REPLY_VALUE: i32 = 0x08000000;
let REPLY_REFUSED: i32 = 0x10000000;
let REPLY_CONT: i32 = 0x20000000;
let REPLY_MORE: i32 = 0x40000000;

// A lane whose jobs are variants of the enum U, and mark, the variant of the
// program's Use that a route waiting on it holds in cx.state.use. U is in no
// field: it types the jobs ask takes.
struct Lane<U, M> { lane: http::Lane, mark: M }

// What a lane's thread takes its jobs of U with: rest::lane_open passes it
// to each thread, and rest::lane reads U from it. U is in no field: the
// thread's parameter names it, and thread_spawn checks it against the lane's,
// so a thread that runs another lane's jobs doesn't compile.
struct Jobs<U> { unused: bool = false }

// Opens a lane of jobs of U, as http::lane_open opens one, of the thread_fn
// W, given a where a is passed:
// thread_fn W(box: http::Box, jobs: rest::Jobs<U>[, a: A]).
//
//   writer: rest::lane_open<Writes>(http::LaneConfig { slots: 64, .. }, Use.Write, writer),
fn lane_open<U, M, W>(cfg: http::LaneConfig, mark: M) -> Lane<U, M> {
    return Lane<U, M> { lane: http::lane_open(cfg, Jobs<U> { .. }, W), mark: mark };
}

fn lane_open<U, M, W>(cfg: http::LaneConfig, mark: M, a) -> Lane<U, M> {
    return Lane<U, M> { lane: http::lane_spawn(cfg) { b => thread_spawn(W, b, Jobs<U> { .. }, a) }, mark: mark };
}

// A lane of jobs of U of box alone, with no thread, as http::lane_of: for a
// test that plays the lane.
fn lane_of<U, M>(box: http::Box, mark: M) -> Lane<U, M> {
    return Lane<U, M> { lane: http::lane_of(box), mark: mark };
}

// Stops lane's threads and waits for them (http::lane_stop).
fn lane_stop<U, M>(lane: const Lane<U, M>&) { http::lane_stop(lane.lane); }

// A job as it crosses to the thread that runs it.
struct Ask<U> { reply: http::MailAddress = http::MailAddress { .. }, piece: i64 = 0, job: U }

// Whether the route waits on rest::ask now, as an upgraded connection's
// route can at a BODY, where a second ask would fail.
fn is_waiting(cx) -> bool { cx.out.stream.waiting }

// Sends job, a variant of the lane's U, to the least busy thread of lane,
// and waits for its reply for at most ms milliseconds, with the lane's mark
// in cx.state.use. A variant of another lane's enum doesn't compile. The
// handler is called again when the reply comes, or answers 504 timeout if
// it doesn't. Fails with 503 unavailable when every thread's box is full, or
// the lane is stopped, with 500 job_too_large, before the job is sent, when
// the job and its length don't fit one message of a reply, which carries
// them at its front, and with 500 already_waiting when the route waits
// already, as at an upgraded connection's BODY during a wait: goose-http's
// exchange has one wait, which a second job's reply would share. Needs
// Config.mail_slots and max_waiting: past max_waiting, or without them,
// goose-http has no room for the wait, and the route gets 503 unavailable
// with Retry-After at once. On an upgraded connection, the mark's resume gets
// the client's bytes as BODY while it waits, and TIMEOUT in place of 504 or
// 503. Under serve, the reply is promised most bytes of the worker's gather
// budget (Config) while the route waits, a reply_value's pieces collected
// within them: a budget that can't promise them fails the route with 503
// unavailable and Retry-After before the job is sent, and a reply_value
// past them gets 502 reply_too_large.
fn ask<U, M>(cx, lane: const Lane<U, M>&, job: U, ms: i64 = 5000, most: i64 = REPLY_LIMIT) {
    if is_waiting(cx) { fail(cx, 500, "already_waiting"); }
    let back = http::later(cx.out, ms);
    let piece = http::mail_slot_size(back);
    if piece >= 0 && echo_head_len(job) > piece {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        fail(cx, 500, "job_too_large");
    }
    var x .= cx.ex;
    if x && !promise_reply(x, most) {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        unavailable(cx);
    }
    guard http::lane_send_value(lane.lane, 0, Ask<U> { reply: back, piece: piece, job: job }) == http::SENT else {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        if x { drop_reply(x); }
        fail(cx, 503, "unavailable");
    }
    cx.state.use = lane.mark;
}

// Whether the handler is called after a request's first call: for a reply
// (http::WAKE), or for a later event of a route that reads, sends, or
// upgrades in pieces (pieces.goose), with cx.kind saying which.
fn resumed(cx) -> bool { cx.kind != http::REQUEST }

// What a lane's run gets as a: the job, where its reply goes, and whether
// run replied. played, under rest::play, takes the reply in place of the
// mail.
struct Asked<U> {
    reply: http::MailAddress = http::MailAddress { .. },
    piece: i64 = 0,
    job: U,
    replied: bool = false,
    played: Played? = null,
}

// A lane thread's loop over jobs of U, as http::lane's: F(u, a) for each,
// with u the job, which run's case functions dispatch on, and a what
// reply_value answers. A rest::fail in F refuses the job, which fails the
// route with the same status and code, and an F that returns without either
// refuses it with 500 no_reply, so that the route doesn't wait until its
// time runs out.
//
//   thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
//       var w = Writer { .. };
//       rest::lane(box, jobs) { u, a => run(u, w, a); };
//   }
inline fn lane<U, F>(box: http::Box, jobs: Jobs<U>) {
    http::lane(box) { tag, bytes => lane_job(jobs, bytes) { u, a => F(u, a); }; };
}

// One job of a lane's loop, from the bytes of its message: for a thread that
// writes its own loop, as one doing timed work between jobs does, and for a
// test that reads the job a route sent, with a rest::Jobs<U> of its own. A
// message that isn't an Ask<U> is dropped.
inline fn lane_job<U, F>(jobs: Jobs<U>, bytes: const u8[:]) {
    var asked = default<Ask<U>>();
    if http::mail_value(bytes, asked) {
        var a = Asked<U> { reply: asked.reply, piece: asked.piece, job: asked.job };
        run_job(&a) { u, a => F(u, a); };
    }
}

// F(a.job, a), and the refusal of a job F failed or left unanswered.
inline fn run_job<U, F>(a: Asked<U>&) {
    let failed = attempt() { F(a.job, a); };
    for f in failed { refuse(a, f.status, f.code); }
    if failed.len == 0 && !a.replied && still_wanted(a) { refuse(a, 500, "no_reply"); }
}

// Whether the route that asked a still waits for its reply: false once its
// client has gone, its wait has timed out, or its worker has stopped. A
// lane checks it before work worth skipping. It's a snapshot: the route can
// still go before the reply, which reply then reports.
fn still_wanted<U>(a: const Asked<U>&) -> bool {
    if a.played { return true; }
    return http::mail_live(a.reply);
}

// Replies v, a flat value, to the route that asked a, after the job: what
// rest::answer reads. Returns false when the route has gone, as reply does.
// Its pieces are marked REPLY_VALUE, and the worker collects them whole in
// its gather pool, within the most rest::ask promised, before the resume
// runs.
fn reply_value<U>(a: Asked<U>&, v) -> bool { reply_tagged(a, value_bytes(v), REPLY_VALUE) }

// Replies data to the route that asked a, after the job, in pieces of at
// most the size a carries, which rest::relay sends on as they come. A piece
// that finds the box full is sent again after a millisecond: the worker's
// box is shared by all its waiting routes. Returns false when the worker's
// box has closed, as when it stopped, when a piece is longer than its slots,
// or when the exchange's key is stale, as after its client closes or its
// wait times out; a send checks the key before a slot, so the retry on a
// full box ends then too. A send already in flight may still be accepted
// and dropped by the worker.
fn reply<U>(a: Asked<U>&, data: const u8[:]) -> bool { reply_tagged(a, data, 0) }

// reply's work, with tag on each piece.
fn reply_tagged<U>(a: Asked<U>&, data: const u8[:], tag: i32) -> bool {
    a.replied = true;
    return send_reply(a, echo_head(a.job), data, tag);
}

// A reply starts with its job: the length of the job's image in ECHO_HEAD
// bytes, least significant first, then the image.
let ECHO_HEAD = 4;

fn echo_head<U>(job: U) -> u8[>..] {
    var head: u8[>..] = [0, 0, 0, 0];
    var one = [job];
    one.to_bytes(head);
    let n = head.len - ECHO_HEAD;
    for i in ECHO_HEAD { head[i] = ((n >> (i * 8)) & 0xFF) as u8; }
    return head;
}

// The length echo_head gives job, without writing its image: a view of the
// job's bytes, after the image's ULEB128 length.
fn echo_head_len<U>(job: U) -> i64 {
    let one = [job];
    let n = bytes_of(one).len;
    var uleb: i64 = 1;
    while (n >> (uleb * 7)) > 0 { uleb++; }
    return ECHO_HEAD + uleb + n;
}

// Replies a refusal of a's job with status and code: the status's 4 bytes,
// least significant first, and then the code, cut to fit one message, so
// that the worker reads it whole.
fn refuse<U>(a: Asked<U>&, status: i32, code: const u8[:]) -> bool {
    a.replied = true;
    var image: u8[>..] = [];
    for i in 4 { image.push(((status >> (i * 8)) & 0xFF) as u8); }
    let room = if a.played { code.len } else { max(a.piece - 4, 0) };
    image.append(code[..min(code.len, room)]);
    return send_reply(a, image, "", REPLY_REFUSED);
}

// The status and code of a refusal's bytes, and whether they're one.
fn refusal_of(bytes: const u8[:]) -> i32, const u8[:], bool {
    guard bytes.len >= 4 else { return 0, "", false; }
    var status: i32 = 0;
    for i in 4 { status |= (bytes[i] as i32) << (i * 8); }
    return status, bytes[4..], true;
}

// Sends head and then data, with tag, to the route that asked a, in pieces,
// each after the first with REPLY_CONT and tag's REPLY_VALUE: reply's work.
// A piece is a slice of head or of data, or the one piece that holds the end
// of head and the start of data, copied together.
fn send_reply<U>(a: Asked<U>&, head: const u8[:], data: const u8[:], tag: i32) -> bool {
    var p .= a.played;
    if p {
        p.tag = tag;
        p.data.append(head);
        p.data.append(data);
        return true;
    }
    let piece = max(a.piece, 1);
    let h = head.len;
    let total = h + data.len;
    var at = 0;
    var t = tag;
    loop {
        let end = min(at + piece, total);
        let more = end < total;
        var joined: u8[>..] = [];
        if at < h && end > h {
            joined.append(head[at..]);
            joined.append(data[..end - h]);
        }
        let part = if end <= h { head[at..end] } else if at >= h { data[at - h..end - h] } else { joined[..] };
        loop {
            let sent = http::mail_send(a.reply, if more { t | REPLY_MORE } else { t }, part);
            if sent == http::SENT { break; }
            if sent == http::STALE || sent == http::TOO_LONG { return false; }
            sleep_ms(1);
        }
        guard more else { return true; }
        at = end;
        t = REPLY_CONT | (tag & REPLY_VALUE);
    }
}

// The bytes of v, a flat value, as a reply carries it.
fn value_bytes(v) -> u8[>..] {
    var one = [v];
    var image: u8[>..] = [];
    one.to_bytes(image);
    return image;
}

// rest::route for a route's later calls: a reply that says its job was
// refused fails the route with the refusal's status and code before F, the
// resume, runs. cx.state.use stays as the route left it, so a CLOSED after
// an early answer reaches the variant that holds what to release.
//
//   rest::on_reply(cx) { resume(cx.state.use, cx); };
inline fn on_reply<F>(cx) {
    route(cx) {
        if cx.refused {
            let status, code, ok = refusal_of(cx.reply);
            guard ok && !cx.more && status >= 100 else { fail(cx, 502, "bad_reply"); }
            fail(cx, status, code);
        }
        F();
    };
}

// The job a reply carries back, of the lane's U: what a mark's resume
// dispatches on. Fails with 500 not_a_reply at another event than WAKE, as
// an upgraded connection's BODY during the wait, and with 502 bad_reply for
// a reply that doesn't start with a job of U.
//
//   fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
fn job<U>(cx) -> U {
    guard cx.kind == http::WAKE else { fail(cx, 500, "not_a_reply"); }
    let u, ok = echoed<U>(cx.reply);
    guard ok else { fail(cx, 502, "bad_reply"); }
    return u;
}

// The job at the front of a reply's bytes, and whether there is one.
fn echoed<U>(bytes: const u8[:]) -> U, bool {
    var u = default<U>();
    let n = echo_len(bytes);
    let ok = n >= 0 && http::mail_value(bytes[ECHO_HEAD..ECHO_HEAD + n], u);
    return u, ok;
}

// The flat value reply_value replied after the job, or 502 bad_reply for a
// reply that isn't one, as one that rest::reply sent in pieces.
fn answer<T>(cx) -> T {
    var v = default<T>();
    let n = echo_len(cx.reply);
    guard !cx.more && n >= 0 && http::mail_value(cx.reply[ECHO_HEAD + n..], v) else { fail(cx, 502, "bad_reply"); }
    return v;
}

// The length of the job's image at the front of a reply, or -1.
fn echo_len(bytes: const u8[:]) -> i64 {
    guard bytes.len >= ECHO_HEAD else { return -1; }
    var n: i64 = 0;
    for i in ECHO_HEAD { n |= (bytes[i] as i64) << (i * 8); }
    return if ECHO_HEAD + n <= bytes.len { n } else { -1 };
}

// Answers status with the reply's bytes after the job as the body, of
// content_type: whole when the reply came in one message, or else as a
// chunked response, a chunk per piece, which rest::serve sends on as the
// pieces come. 502 bad_reply for a first piece that doesn't hold the job.
fn relay(cx, status: i32, content_type: const u8[:]) {
    let n = echo_len(cx.reply);
    guard n >= 0 else { fail(cx, 502, "bad_reply"); }
    let data = cx.reply[ECHO_HEAD + n..];
    if !cx.more {
        http::respond(cx.out, status, content_type, data);
        return;
    }
    http::begin(cx.out, status, -1);
    http::field(cx.out, "Content-Type", content_type);
    relay_piece(cx.out, data, true);
}

// Sends a piece of a reply relay began, and waits for the next while more
// follows, with the time limit ask gave.
fn relay_piece(out: http::Reply, data: const u8[:], more: bool) {
    guard out.stream.open else { return; }
    http::send(out, data);
    if more { http::later(out, out.stream.wait_ms); } else { http::end(out); }
}
