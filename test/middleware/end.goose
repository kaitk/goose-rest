// The middleware's fields on an answer at a body's END, through
// rest::serve_one: a body whole with its head, and one in pieces.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../";
import expect from "../";
import common;

// Answers a body read in pieces at its END, through serve_one.
fn upload(which: const u8[:], n: i64) -> u8[>..] {
    var text = str("POST /up HTTP/1.1\r\nHost: x\r\nOrigin: https://a.example\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a'); }
    var app = rest::NoState { .. };
    let to = Lane { lane: http::Lane { .. }, mark: Use.Report };
    return rest::serve_one(text, app, St { .. }) { cx =>
        if rest::resumed(cx) { resume(cx.state.use, cx); } else { later_route(cx, "upload", which, to); }
    };
}

fn main() {
    // Whole with its head, and in pieces.
    for n in [100, 20000] {
        let size = str(n);
        let created = str("Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", size.len, "\r\n\r\n", size);
        expect::same(upload("cors", n), str("HTTP/1.1 201 Created\r\n", ALLOWED, created));
        let both = upload("both", n);
        expect::same(expect::status_of(both), "HTTP/1.1 201 Created");
        expect::same(timing_in(both, 0), str(ALLOWED, created));
    }
    print("the middleware at a body's END: ok");
}
