// Spike 10's prototype of task 050's calls: a use case is a variant of the
// program's fixed-mode enum, which is both the job a lane runs and what the
// route waits with, in cx.state.use. In namespace spike10, beside the
// package's plod, which has calls of these names since spike 11's shape
// went into it. See README.md.
namespace spike10;

import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod;

// The tag of a reply that says the job failed, and holds a Refusal: the
// package's plod::REPLY_REFUSED, so that the package's on_event sees it.
let JOB_FAILED: i32 = 0x10000000;

// What a fail on a lane replies: Failure's status and code, fixed, so that
// it crosses as a flat value.
struct Refusal { status: i32 = 0, code: u8[..64] = "" }

// Sends u, a variant of the program's use-case enum, to the least busy
// thread of lane, and waits for its reply with u in cx.state.use. The job
// crosses as cx.state.use: u is of its variant's type, and the lane reads
// the enum.
fn ask(cx, lane: const http::Lane&, u, ms: i64 = 5000) {
    if plod::is_waiting(cx) { plod::fail(cx, 500, "already_waiting"); }
    cx.state.use = u;
    let back = http::later(cx.out, ms);
    guard http::lane_send_value(lane, 0, asking(back, http::mail_slot_size(back), cx.state.use)) == http::SENT else {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        plod::fail(cx, 503, "unavailable");
    }
}

fn asking<U>(back: http::MailAddress, piece: i64, job: U) -> plod::Ask<U> {
    return plod::Ask<U> { reply: back, piece: piece, job: job };
}

// A lane thread's loop over jobs of the use-case enum U: F(u, a) for each,
// with u the job and a what reply_value answers. A fail in F, as in a
// route, replies the failure in place of the answer.
//
//   spike10::lane<Use>(box) { u, a => run(u, db, a); };
inline fn lane<U, F>(box: http::Box) {
    http::lane(box) { tag, bytes =>
        var a = default<plod::Ask<U>>();
        if http::mail_value(bytes, a) {
            let failed = plod::attempt() { F(a.job, a); };
            for f in failed { reply_value(a, Refusal { status: f.status, code: f.code }, JOB_FAILED); }
        }
    };
}

// Replies v, a flat value, with tag, to the route that asked a, in one
// message.
fn reply_value(a, v, tag: i32 = 0) -> bool {
    loop {
        let sent = http::mail_send(a.reply, tag, plod::value_bytes(v));
        if sent == http::SENT { return true; }
        if sent == http::STALE || sent == http::TOO_LONG { return false; }
        sleep_ms(1);
    }
}

// plod::route for a route's later calls: a reply that says its job failed
// fails the route with the job's status and code, before F, the resume,
// runs.
//
//   spike10::on_reply(cx) { resume(cx.state.use, cx); };
inline fn on_reply<F>(cx) {
    plod::route(cx) {
        if cx.kind == http::WAKE && cx.refused {
            let r = answer<Refusal>(cx);
            plod::fail(cx, r.status, r.code);
        }
        F();
    };
}

// The flat value the job replied, or 502 bad_reply for a reply that isn't one.
fn answer<T>(cx) -> T {
    var v = default<T>();
    guard !cx.more && http::mail_value(cx.reply, v) else { plod::fail(cx, 502, "bad_reply"); }
    return v;
}
