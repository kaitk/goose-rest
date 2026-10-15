// rest::serve_one with a route that waits, given its replies or its
// timeout: a value and its tag, a relay in one piece and in several, two
// waits in turn, and a wait with no wake left.
import std;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../";
import expect from "../";

// A route that asks the test's box, and answers from what comes back.
enum Waiting {
    None,
    Relay,
    Value,
    First,
    Second { first: i64 },
}

struct St { waiting: Waiting = Waiting.None }

struct App { to: http::MailAddress }

let ECHO: i32 = 1;

fn handle(cx) {
    if rest::resumed(cx) {
        resume(cx.state.waiting, cx);
    } else if cx.req.target == "/relay" {
        rest::ask(cx, cx.app.to, ECHO, 0, Waiting.Relay);
    } else if cx.req.target == "/value" {
        rest::ask(cx, cx.app.to, ECHO, 0, Waiting.Value, 200);
    } else {
        rest::ask(cx, cx.app.to, ECHO, 0, Waiting.First);
    }
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Relay, cx) { rest::relay(cx, 200, "text/plain"); }

fn resume(w: Waiting.Value, cx) {
    let v, ok = rest::read_reply<i64>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::text(cx, 200, str(v, " ", cx.tag));
}

// Two waits in turn: the second asks again with the first's reply.
fn resume(w: Waiting.First, cx) {
    let v, ok = rest::read_reply<i64>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::ask(cx, cx.app.to, ECHO, v, Waiting.Second { first: v });
}

fn resume(w: Waiting.Second, cx) {
    let v, ok = rest::read_reply<i64>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::text(cx, 200, str(w.first + v));
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: http::address(box, 0) };
    let relay = "GET /relay HTTP/1.1\r\n\r\n";
    let value = "GET /value HTTP/1.1\r\n\r\n";

    // A reply in one piece, and its tag.
    let one = rest::value_bytes(42);
    expect::same(expect::body_of(rest::serve_one(value, app, St { .. }, [rest::Wake { data: one, tag: 9 }]) { cx =>
        handle(cx)
    }), "42 9", "a value");
    expect::same(rest::serve_one(relay, app, St { .. }, [rest::Wake { data: "abcdefghij" }]) { cx => handle(cx) },
                 "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nabcdefghij", "one piece");

    // A reply longer than the box's messages comes in pieces, which relay
    // sends on as chunks; a value can't be read from them.
    let small = http::Config { mail_size: 4, .. };
    expect::same(rest::serve_one(relay, app, St { .. }, [rest::Wake { data: "abcdefghij" }], small) { cx => handle(cx) },
                 "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n4\r\nabcd\r\n4\r\nefgh\r\n2\r\nij\r\n0\r\n\r\n",
                 "several pieces");
    expect::same(expect::body_of(rest::serve_one(value, app, St { .. }, [rest::Wake { data: one }], small) { cx =>
        handle(cx)
    }), "{\"error\":\"bad_reply\"}", "a value in pieces");

    // The wait's end instead of a reply.
    expect::same(rest::serve_one(value, app, St { .. }, [rest::Wake { timeout: true }]) { cx => handle(cx) },
                 "HTTP/1.1 504 Gateway Timeout\r\nContent-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}",
                 "timeout");

    // Two waits in turn, and a wait with no wake left.
    let two = rest::value_bytes(2);
    expect::same(expect::body_of(rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. },
                                                 [rest::Wake { data: one }, rest::Wake { data: two }]) { cx =>
        handle(cx)
    }), "44", "two waits");
    expect::same(expect::status_of(rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. }, [rest::Wake { data: one }])
                                   { cx => handle(cx) }), "HTTP/1.1 500 Internal Server Error", "no wake left");

    // Each ask sent its job to the box.
    let n = http::mail_take(box) { key, tag, bytes =>
        let a, ok = rest::asked<i64>(bytes);
        assert(ok && tag == ECHO);
    };
    assert(n == 9);
    http::mail_close(box);
    print("rest::serve_one's waits: ok");
}
