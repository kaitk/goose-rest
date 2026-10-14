// Waiting on another thread: a route asks a thread, such as a database's,
// with rest::ask, and resumes when its reply comes. Goose can't keep a
// function to call later, so the per-request state keeps what the route
// needs in a field waiting, a fixed-mode enum of the program's, and the
// handler resumes through a case function per variant (spike 06):
//
//   enum Waiting { None, Report { org: i64 } }
//   struct St { waiting: Waiting = Waiting.None }
//
//   var app = rest::NoState { .. };
//   rest::serve(cfg, app, St { .. }) { cx =>
//       if rest::woken(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
//   };
//
// The job crosses in a rest::Ask, with the address the reply goes to and
// the size of a reply message, which a sender can't learn from the address
// (goose-http's task 028). The thread replies with rest::answer, in pieces
// of at most that size, and rest::relay sends them on as they come. A route
// that never asks keeps nothing on the connection beyond its state.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.3.1";

// A reply message's tag: the sender's tag in REPLY_TAG's bits; REPLY_MORE
// when more of the reply follows; REPLY_CONT on every piece after the first.
let REPLY_TAG: i32 = 0x1FFFFFFF;
let REPLY_CONT: i32 = 0x20000000;
let REPLY_MORE: i32 = 0x40000000;

// A job as it crosses to the thread that answers it.
struct Ask<J> { reply: http::MailAddress = http::MailAddress { .. }, piece: i64 = 0, job: J }

// Sends job, a flat value, with tag to the thread at to, and waits for its
// reply for at most ms milliseconds, with w in cx.state.waiting. The handler
// is called again when the reply comes, or answers 504 timeout if it doesn't.
// Fails with 503 unavailable when the thread's box is full or closed. Needs
// Config.mail_slots and max_waiting; without them the route gets 504 at
// once.
fn ask<J>(cx, to: http::MailAddress, tag: i32, job: J, w, ms: i64 = 5000) {
    cx.state.waiting = w;
    let reply = http::later(cx.out, ms);
    guard http::mail_send_value(to, tag, Ask<J> { reply: reply, piece: cx.slot, job: job }) == http::SENT else {
        cx.out.stream.waiting = false;
        cx.out.stream.rearm = false;
        fail(cx, 503, "unavailable");
    }
}

// Whether the handler is called for a reply, not a request.
fn woken(cx) -> bool { cx.kind == http::WAKE }

// The job a message holds, as rest::ask sent it, and whether it is one.
fn asked<J>(bytes: const u8[:]) -> Ask<J>, bool {
    var a = default<Ask<J>>();
    let ok = http::mail_value(bytes, a);
    return a, ok;
}

// Replies data, with tag, to the route that asked a, in pieces of at most
// the size a carries. A piece that finds the box full is sent again after a
// millisecond: the worker's box is shared by all its waiting routes.
// Returns false when the worker's box has closed, as when it stopped, when
// a piece is longer than its slots, or when the exchange's key is stale,
// as after its client closes or its wait times out. A send already in
// flight may still be accepted and dropped by the worker.
fn answer(a, data: const u8[:], tag: i32 = 0) -> bool {
    let piece = max(a.piece, 1);
    var at = 0;
    var t = tag & REPLY_TAG;
    loop {
        let end = min(at + piece, data.len);
        let more = end < data.len;
        loop {
            let sent = http::mail_send(a.reply, if more { t | REPLY_MORE } else { t }, data[at..end]);
            if sent == http::SENT { break; }
            if sent == http::STALE || sent == http::TOO_LONG { return false; }
            sleep_ms(1);
        }
        guard more else { return true; }
        at = end;
        t = REPLY_CONT;
    }
}

// Replies v, a flat value, as answer does, for rest::reply_value.
fn answer_value(a, v, tag: i32 = 0) -> bool {
    var one = [v];
    var image: u8[>..] = [];
    one.to_bytes(image);
    return answer(a, image, tag);
}

// The flat value answer_value sent, and whether the reply is one. A value
// whose image is larger than a reply message comes in pieces, which this
// can't read: raise Config.mail_size to its size.
fn reply_value<T>(cx) -> T, bool {
    var v = default<T>();
    guard !cx.more else { return v, false; }
    let ok = http::mail_value(cx.reply, v);
    return v, ok;
}

// Answers status with the reply's bytes as the body, of content_type: whole
// when the reply came in one message, or else as a chunked response, a chunk
// per piece, which rest::serve sends on as the pieces come.
fn relay(cx, status: i32, content_type: const u8[:]) {
    if !cx.more {
        http::respond(cx.out, status, content_type, cx.reply);
        return;
    }
    http::begin(cx.out, status, -1);
    http::field(cx.out, "Content-Type", content_type);
    relay_piece(cx.out, cx.reply, true);
}

// Sends a piece of a reply relay began, and waits for the next while more
// follows, with the time limit ask gave.
fn relay_piece(out: http::Reply, data: const u8[:], more: bool) {
    guard out.stream.open else { return; }
    http::send(out, data);
    if more { http::later(out, out.stream.wait_ms); } else { http::end(out); }
}
