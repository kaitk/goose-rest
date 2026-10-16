// The middleware's fields on an answer at a later call: a route behind
// rest::cors, rest::timed, or both, that asks another thread and answers
// its reply at WAKE, or 504 at TIMEOUT, and one that gathers its body first.
import std;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../";
import expect from "../";
import common;

// What serve answers to text, whose route asks, given the reply, or TIMEOUT
// for none: the REQUEST, the body's pieces when it doesn't come whole, and
// then the WAKE. common is the loop's fields, another at the WAKE, as Date's
// value changes. The exchange keeps nothing after.
fn answered_later(text: const u8[:], which: const u8[:], reply: const u8[:], timeout: bool = false,
                  what: const u8[:] = "ask") -> u8[>..] {
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    let to = http::address(box, 0);
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    let body = text[req.len..];
    let whole = what != "gathered";
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<St> { state: St { .. } };
    reusable[] var spill: u8[>..] = [];
    var runs: rest::Run[>..] = [];
    var budget = rest::Budget { size: rest::GATHER_BUDGET, runs: runs };
    var app = rest::NoState { .. };
    let first = http::Reply { buf: out, common: "Server: t\r\n", keep_alive: keep, minor: 1, head: false,
                              stream: stream };
    fn send(kind: u8, data: const u8[:]) {
        rest::deliver(http::Event { kind: kind, req: req, data: data, whole: whole, trailers: "" }, st, app, first, spill, budget)
            { cx => later_route(cx, what, which, to); };
    }
    send(http::REQUEST, if whole { body } else { "" });
    if !whole {
        send(http::BODY, body);
        send(http::END, "");
    }
    if !stream.waiting || out.len > 0 { print(which, " ", what, ": ", out); assert(false); }
    let n = http::mail_take(box) { key, tag, bytes => assert(tag == 1); };
    assert(n == 1);
    sleep_ms(2);
    stream.waiting = false;
    let none = http::Request { .. };
    let later = http::Reply { buf: out, common: "Server: t2\r\n", keep_alive: keep, minor: 1, head: false,
                              stream: stream };
    rest::deliver(http::Event { kind: if timeout { http::TIMEOUT } else { http::WAKE }, req: none, data: reply,
                                whole: false, trailers: "" }, st, app, later, spill, budget) { cx =>
        if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { later_route(cx, what, which, to); }
    };
    assert(st.ex.mode == 0 && st.ex.cap == 0);
    return out;
}

fn main() {
    let get = expect::request("GET", "/report", "Origin: https://a.example\r\n");
    let got = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 6\r\n\r\ngot ok";
    expect::same(answered_later(get, "cors", "ok"), str("HTTP/1.1 200 OK\r\nServer: t2\r\n", ALLOWED, got));
    // Without Origin, nothing kept.
    let plain = expect::request("GET", "/report");
    expect::same(answered_later(plain, "cors", "ok"), str("HTTP/1.1 200 OK\r\nServer: t2\r\n", got));
    // Timed from the request, which came 2 ms before the reply.
    let timed = answered_later(plain, "timed", "ok");
    expect::same(expect::status_of(timed), "HTTP/1.1 200 OK");
    expect::same(timing_in(timed, 2), got);
    let both = answered_later(get, "both", "ok");
    expect::same(timing_in(both, 2), str(ALLOWED, got));
    // TIMEOUT's 504.
    let late = answered_later(get, "both", "", true);
    expect::same(expect::status_of(late), "HTTP/1.1 504 Gateway Timeout");
    expect::same(timing_in(late, 2),
                 str(ALLOWED, "Content-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}"));
    // A body gathered first, and then the ask.
    let posted = str("POST /report HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nContent-Length: 5\r\n\r\nhello");
    expect::same(answered_later(posted, "cors", "ok", false, "gathered"),
                 str("HTTP/1.1 200 OK\r\nServer: t2\r\n", ALLOWED, got));
    print("the middleware at WAKE and TIMEOUT: ok");
}
