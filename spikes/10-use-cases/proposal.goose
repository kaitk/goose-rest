// Spike 10's prototype of task 050's calls, beside the package's own in
// namespace rest: a use case is a variant of the program's fixed-mode enum,
// which is both the job a lane runs and what the route waits with, in
// cx.state.use. See README.md.
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

// Sends u, a variant of the program's use-case enum, to the least busy
// thread of lane, and waits for its reply with u in cx.state.use, as ask
// does with its tag, job, and w. The job crosses as cx.state.use: u is of
// its variant's type, and the lane reads the enum.
fn ask(cx, lane: const http::Lane&, u, ms: i64 = 5000) {
    if is_waiting(cx) { fail(cx, 500, "already_waiting"); }
    cx.state.use = u;
    let back = http::later(cx.out, ms);
    guard http::lane_send_value(lane, 0, asking(back, http::mail_slot_size(back), cx.state.use)) == http::SENT else {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        fail(cx, 503, "unavailable");
    }
}

fn asking<U>(back: http::MailAddress, piece: i64, job: U) -> Ask<U> {
    return Ask<U> { reply: back, piece: piece, job: job };
}

// A lane thread's loop over jobs of the use-case enum U: F(u, a) for each,
// with u the job and a what reply_value answers. A fail in F, as in a
// route, replies the failure in place of the answer.
//
//   rest::lane<Use>(box) { u, a => run(u, db, a); };
inline fn lane<U, F>(box: http::Box) {
    http::lane(box) { tag, bytes =>
        let a, ok = asked<U>(bytes);
        if ok {
            let failed = attempt() { F(a.job, a); };
            for f in failed { reply_value(a, Refusal { status: f.status, code: f.code }, JOB_FAILED); }
        }
    };
}

// rest::route for a route's later calls: a reply that says its job failed
// fails the route with the job's status and code, before F, the resume,
// runs.
//
//   rest::on_reply(cx) { resume(cx.state.use, cx); };
inline fn on_reply<F>(cx) {
    route(cx) {
        if cx.kind == http::WAKE && cx.tag == JOB_FAILED {
            let r = answer<Refusal>(cx);
            fail(cx, r.status, r.code);
        }
        F();
    };
}

// The flat value the job replied, or 502 bad_reply for a reply that isn't one.
fn answer<T>(cx) -> T {
    let v, ok = read_reply<T>(cx);
    guard ok else { fail(cx, 502, "bad_reply"); }
    return v;
}
