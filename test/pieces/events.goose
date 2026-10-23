// plod::pause: events sent over time after plod::begin, a client that goes
// between them, goose-http's TIMEOUT at once, a TIMEOUT that doesn't pause
// again, a pause at MORE, and a pause without a response begun.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";
import expect from "../";

// n events in all; at_more pauses at MORE rather than in the route.
enum Use { None, Events { n: i64, at_more: bool } }

struct St { use: Use = Use.None, sent: i64 = 0 }

// What the case function saw, in order: T, M, C.
struct App { log: u8[>..]& }

fn resume(w: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

// At TIMEOUT, the next event, and a pause, or the end after the nth; n of 0
// sends one at the TIMEOUT and leaves the rest to MORE, which ends.
fn resume(w: Use.Events, cx) {
    if cx.kind == http::TIMEOUT {
        cx.app.log.append("T ");
        event(cx);
        if w.n == 0 { return; }
        if cx.state.sent == w.n { plod::end(cx); } else { plod::pause(cx, 1000); }
    } else if cx.kind == http::MORE {
        cx.app.log.append("M ");
        if w.at_more && cx.state.sent < w.n {
            event(cx);
            plod::pause(cx, 1000);
        } else {
            plod::end(cx);
        }
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("C ");
    }
}

fn event(cx) {
    cx.state.sent++;
    plod::send(cx, str("data: ", cx.state.sent, "\n\n"));
}

fn stream(n: i64, wakes: const plod::Wake[:], at_more: bool = false, begun: bool = true) -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = plod::serve_one("GET /events HTTP/1.1\r\n\r\n", app, St { .. }, wakes) { cx =>
        if plod::resumed(cx) {
            resume(cx.state.use, cx);
        } else if begun {
            plod::begin(cx, 200, "text/event-stream", -1, Use.Events { n: n, at_more: at_more });
            if !at_more {
                event(cx);
                plod::pause(cx, 1000);
            }
        } else {
            plod::pause(cx, 1000);
        }
    };
    return out, log;
}

fn main() {
    let t = plod::Wake { timeout: true };
    let three, l1 = stream(3, [t, t]);
    expect::same(expect::status_of(three), "HTTP/1.1 200 OK", "events");
    expect::same(expect::body_of(three), "9\r\ndata: 1\n\n\r\n9\r\ndata: 2\n\n\r\n9\r\ndata: 3\n\n\r\n0\r\n\r\n",
                 "events' body");
    expect::same(l1, "T T ", "events' calls");
    // The client goes during the second pause: CLOSED, and no end.
    let gone, l2 = stream(3, [t]);
    expect::same(expect::body_of(gone), "9\r\ndata: 1\n\n\r\n9\r\ndata: 2\n\n\r\n", "gone");
    expect::same(l2, "T C ", "gone's calls");
    // goose-http's TIMEOUT at once, with no timer for the pause: the end.
    let early, l3 = stream(3, [plod::Wake { timeout: true, early: true }]);
    expect::same(expect::body_of(early), "9\r\ndata: 1\n\n\r\n0\r\n\r\n", "early");
    expect::same(l3, "C ", "early's calls");
    // A TIMEOUT that sends and doesn't pause: MORE next.
    let more, l4 = stream(0, [t]);
    expect::same(expect::body_of(more), "9\r\ndata: 1\n\n\r\n9\r\ndata: 2\n\n\r\n0\r\n\r\n", "no pause");
    expect::same(l4, "T M ", "no pause's calls");
    // Paused at MORE.
    let at_more, l5 = stream(2, [t], true);
    expect::same(expect::body_of(at_more), "9\r\ndata: 1\n\n\r\n9\r\ndata: 2\n\n\r\n0\r\n\r\n", "at MORE");
    expect::same(l5, "M T ", "at MORE's calls");
    // No response begun.
    let none, l6 = stream(1, [], false, false);
    expect::same(expect::body_of(none), "{\"error\":\"not_sending\"}", "not sending");
    print("plod::pause: ok");
}
