// rest::serve_one: a request's bytes answered as rest::serve answers them,
// a long body gathered and the route run again with it whole, a request
// without Host, and goose-http's refusals. scripts/test-unit.sh runs this
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

fn main() {
    test_bodies();
    test_requests();
    print("test_serve_one: ok");
}
