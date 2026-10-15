// rest::serve_one: a request's bytes answered as rest::serve answers them,
// a long body gathered and the route run again with it whole, a request
// without Host, goose-http's refusals, and a route that waits given its
// replies or its timeout. scripts/test-unit.sh runs this
// through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

fn same(got: const u8[:], want: const u8[:], what: const u8[:]) {
    if got != want {
        print(what, ":\ngot:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn put(n: i64) -> u8[>..] {
    var text = str("PUT /up HTTP/1.1\r\nHost: x\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a' + (i % 26) as u8); }
    return text;
}

// A route that counts its runs up to its rest::body, then answers with the
// body's length and the runs.
fn upload(text: const u8[:], limit: i64 = rest::BODY_LIMIT) -> u8[>..], i64 {
    var runs = 0;
    let out = rest::serve_one(text) { cx =>
        runs++;
        let data = rest::body(cx, limit);
        rest::text(cx, 200, str(data.len, " ", data[data.len - 1..]));
    };
    return out, runs;
}

fn test_bodies() {
    // A body that fits in the read buffer with its head comes whole.
    let short, once = upload(put(100));
    same(body_of(short), "100 v", "short body");
    assert(once == 1);
    // A longer one comes in pieces, gathered, and the route runs again.
    let long, twice = upload(put(100000));
    same(body_of(long), "100000 d", "long body");
    assert(twice == 2);
    // Past rest::body's limit: refused from its Content-Length, in the first run.
    let big, runs = upload(put(100000), 50000);
    same(body_of(big), "{\"error\":\"payload_too_large\"}", "past the limit");
    assert(runs == 1);
    // Past the server's max_body: goose-http refuses it before the route.
    same(status_of(upload(put(2000000))), "HTTP/1.1 413 Content Too Large", "past max_body");
}

fn test_requests() {
    fn hello(text: const u8[:]) -> u8[>..] {
        return rest::serve_one(text) { cx => rest::text(cx, 200, "hello"); };
    }
    same(hello("GET / HTTP/1.1\r\n\r\n"),
         "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\nhello", "no Host");
    same(body_of(hello("GET / HTTP/1.1\r\nhost: x\r\n\r\n")), "hello", "own Host");
    same(hello("HEAD / HTTP/1.1\r\n\r\n"),
         "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\n", "HEAD");
    same(status_of(hello("GET /\r\n\r\n")), "HTTP/1.1 400 Bad Request", "refused");
    // The block runs inside rest::route, so it may fail.
    same(rest::serve_one("GET / HTTP/1.1\r\n\r\n") { cx => rest::fail(cx, 403, "forbidden"); },
         "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"forbidden\"}",
         "fail");
    same(status_of(rest::serve_one("GET / HTTP/1.1\r\n\r\n") { cx => }), "HTTP/1.1 500 Internal Server Error",
         "no answer");
    // A failure with a response open cuts it short: no error inside it, no
    // last chunk.
    let cut = rest::serve_one("GET / HTTP/1.1\r\n\r\n") { cx =>
        http::begin(cx.out, 200, -1);
        http::send(cx.out, "abc");
        rest::fail(cx, 500, "broken");
    };
    same(body_of(cut), "3\r\nabc\r\n", "cut short");
}

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

fn test_replies() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: http::address(box, 0) };
    let relay = "GET /relay HTTP/1.1\r\n\r\n";
    let value = "GET /value HTTP/1.1\r\n\r\n";

    // A reply in one piece, and its tag.
    let one = rest::value_bytes(42);
    same(body_of(rest::serve_one(value, app, St { .. }, [rest::Wake { data: one, tag: 9 }]) { cx => handle(cx) }),
         "42 9", "a value");
    same(rest::serve_one(relay, app, St { .. }, [rest::Wake { data: "abcdefghij" }]) { cx => handle(cx) },
         "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nabcdefghij", "one piece");

    // A reply longer than the box's messages comes in pieces, which relay
    // sends on as chunks; a value can't be read from them.
    let small = http::Config { mail_size: 4, .. };
    same(rest::serve_one(relay, app, St { .. }, [rest::Wake { data: "abcdefghij" }], small) { cx => handle(cx) },
         "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n4\r\nabcd\r\n4\r\nefgh\r\n2\r\nij\r\n0\r\n\r\n",
         "several pieces");
    same(body_of(rest::serve_one(value, app, St { .. }, [rest::Wake { data: one }], small) { cx => handle(cx) }),
         "{\"error\":\"bad_reply\"}", "a value in pieces");

    // The wait's end instead of a reply.
    same(rest::serve_one(value, app, St { .. }, [rest::Wake { timeout: true }]) { cx => handle(cx) },
         "HTTP/1.1 504 Gateway Timeout\r\nContent-Type: application/json\r\nContent-Length: 19\r\n\r\n{\"error\":\"timeout\"}",
         "timeout");

    // Two waits in turn, and a wait with no wake left.
    let two = rest::value_bytes(2);
    same(body_of(rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. }, [rest::Wake { data: one }, rest::Wake { data: two }])
                 { cx => handle(cx) }), "44", "two waits");
    same(status_of(rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, St { .. }, [rest::Wake { data: one }]) { cx => handle(cx) }),
         "HTTP/1.1 500 Internal Server Error", "no wake left");

    // Each ask sent its job to the box.
    let n = http::mail_take(box) { key, tag, bytes =>
        let a, ok = rest::asked<i64>(bytes);
        assert(ok && tag == ECHO);
    };
    assert(n == 9);
    http::mail_close(box);
}

fn main() {
    test_bodies();
    test_requests();
    test_replies();
    print("test_serve_one: ok");
}
