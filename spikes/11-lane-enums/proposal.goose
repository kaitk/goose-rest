// Spike 11's prototype of task 050's calls with one enum per lane, beside
// the package's own in namespace rest. A lane is typed by its enum of jobs,
// so that ask takes only that enum's variants. The route waits with the
// lane's mark, a variant of the program's Use, in cx.state.use, and the
// lane's reply carries the job back, which the mark's resume dispatches on.
// See README.md.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";

// The tag of a reply that says the job failed, and holds a Refusal. A
// sketch: it takes a value within REPLY_TAG, where the package would give it
// a bit of its own.
let JOB_FAILED: i32 = 0x10000000;

// What a fail on a lane replies: Failure's status and code, fixed, so that
// it crosses as a flat value.
struct Refusal { status: i32 = 0, code: u8[..64] = "" }

// A lane whose jobs are variants of the enum U, and mark, the variant of
// the program's Use that a route waiting on it holds.
struct Lane<U, M> { lane: http::Lane, mark: M }

// Opens a lane of the thread_fn W, as http::lane_open does, for jobs of U.
//
//   writer: rest::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, writer),
fn lane_open<U, M, W>(cfg: http::LaneConfig, mark: M) -> Lane<U, M> {
    return Lane<U, M> { lane: http::lane_open(cfg, W), mark: mark };
}

fn lane_stop(lane) { http::lane_stop(lane.lane); }

// Sends job, a variant of the lane's U, to the least busy thread of lane,
// and waits for its reply with the lane's mark in cx.state.use. A variant
// of another lane's enum doesn't compile. The job's inputs cross in the mail
// alone, and come back with the reply.
fn ask<U, M>(cx, lane: const Lane<U, M>&, job: U, ms: i64 = 5000) {
    if is_waiting(cx) { fail(cx, 500, "already_waiting"); }
    cx.state.use = lane.mark;
    let back = http::later(cx.out, ms);
    let piece = http::mail_slot_size(back);
    guard http::lane_send_value(lane.lane, 0, Ask<U> { reply: back, piece: piece, job: job }) == http::SENT else {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        fail(cx, 503, "unavailable");
    }
}

// The job as a lane's run gets it: the Ask, and whether run replied.
struct Took<U> { reply: http::MailAddress = http::MailAddress { .. }, piece: i64 = 0, job: U, replied: bool = false }

// A lane thread's loop over jobs of U: F(u, a) for each, with u the job and
// a what done answers. A fail in F, as in a route, replies the failure in
// place of the answer, and an F that returns without either replies 500
// no_reply, so that the route doesn't wait until its time runs out.
//
//   rest::lane<Writes>(box) { u, a => run(u, db, a); };
inline fn lane<U, F>(box: http::Box) {
    http::lane(box) { tag, bytes =>
        let asked, ok = asked<U>(bytes);
        if ok {
            var a = Took<U> { reply: asked.reply, piece: asked.piece, job: asked.job };
            let failed = attempt() { F(a.job, &a); };
            for f in failed { reply_value(a, Refusal { status: f.status, code: f.code }, JOB_FAILED); }
            if failed.len == 0 && !a.replied { reply_value(a, Refusal { status: 500, code: "no_reply" }, JOB_FAILED); }
        }
    };
}

// Replies v, a flat value, to the route that asked a, after the job itself:
// a two-byte length, the job's image, and v's.
fn done(a, v) -> bool {
    let job = value_bytes(a.job);
    var image: u8[>..] = [];
    image.push((job.len & 0xFF) as u8);
    image.push((job.len >> 8) as u8);
    image.append(job);
    image.append(value_bytes(v));
    a.replied = true;
    return reply(a, image);
}

// rest::route for a route's later calls: a reply that says its job failed
// fails the route with the job's status and code, before F, the resume,
// runs. Once the route has answered, cx.state.use is Use's first variant
// again.
//
//   rest::on_reply(cx) { resume(cx.state.use, cx); };
inline fn on_reply<F>(cx) {
    route(cx) {
        if cx.kind == http::WAKE && cx.tag == JOB_FAILED {
            cleared(cx.state.use);
            let r, ok = read_reply<Refusal>(cx);
            guard ok else { fail(cx, 502, "bad_reply"); }
            fail(cx, r.status, r.code);
        }
        F();
        if !is_waiting(cx) { cleared(cx.state.use); }
    };
}

fn cleared<T>(x: T&) { x = default<T>(); }

// The job the reply carries back, of the lane's U: what a mark's resume
// dispatches on.
//
//   fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
fn job<U>(cx) -> U {
    let u, ok = echoed<U>(cx.reply);
    guard ok else { fail(cx, 502, "bad_reply"); }
    return u;
}

// The job at the front of a reply's bytes, and whether there is one.
fn echoed<U>(bytes: const u8[:]) -> U, bool {
    var u = default<U>();
    let n = echo_len(bytes);
    let ok = n >= 0 && http::mail_value(bytes[2..2 + n], u);
    return u, ok;
}

// The flat value done replied after the job, or 502 bad_reply for a reply
// that isn't one.
fn answer<T>(cx) -> T {
    var v = default<T>();
    let n = echo_len(cx.reply);
    guard !cx.more && n >= 0 && http::mail_value(cx.reply[2 + n..], v) else { fail(cx, 502, "bad_reply"); }
    return v;
}

// The length of the job's image at the front of a reply, or -1.
fn echo_len(bytes: const u8[:]) -> i64 {
    guard bytes.len >= 2 else { return -1; }
    let n: i64 = bytes[0] | ((bytes[1] as i64) << 8);
    return if 2 + n <= bytes.len { n } else { -1 };
}
