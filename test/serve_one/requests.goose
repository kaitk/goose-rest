// plod::serve_one: a request answered as plod::serve answers it, without
// Host and with its own, HEAD, goose-http's refusal, a failure, no answer,
// and a failure that cuts a response short.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";

fn main() {
    fn hello(text: const u8[:]) -> u8[>..] {
        return plod::serve_one(text) { cx => plod::text(cx, 200, "hello"); };
    }
    expect::same(hello("GET / HTTP/1.1\r\n\r\n"),
                 "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\nhello", "no Host");
    expect::same(expect::body_of(hello("GET / HTTP/1.1\r\nhost: x\r\n\r\n")), "hello", "own Host");
    expect::same(hello("HEAD / HTTP/1.1\r\n\r\n"),
                 "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\n", "HEAD");
    expect::same(expect::status_of(hello("GET /\r\n\r\n")), "HTTP/1.1 400 Bad Request", "refused");
    // The block runs inside plod::route, so it may fail.
    expect::same(plod::serve_one("GET / HTTP/1.1\r\n\r\n") { cx => plod::fail(cx, 403, "forbidden"); },
                 "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"forbidden\"}",
                 "fail");
    expect::same(expect::status_of(plod::serve_one("GET / HTTP/1.1\r\n\r\n") { cx => }),
                 "HTTP/1.1 500 Internal Server Error", "no answer");
    // A failure with a response open cuts it short: no error inside it, no
    // last chunk.
    let cut = plod::serve_one("GET / HTTP/1.1\r\n\r\n") { cx =>
        http::begin(cx.out, 200, -1);
        http::send(cx.out, "abc");
        plod::fail(cx, 500, "broken");
    };
    expect::same(expect::body_of(cut), "3\r\nabc\r\n", "cut short");
    print("plod::serve_one's requests: ok");
}
