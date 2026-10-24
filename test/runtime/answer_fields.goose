// plod::bytes, and the answers' block forms, whose fields plod::field and
// plod::set_cookie write, byte for byte.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: 3\r\n\r\nabc") { cx =>
        plod::bytes(cx, 200, "application/octet-stream", "abc");
    };
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nhi") { cx => plod::bytes(cx, 200, "", "hi"); };
    answers(GET, "HTTP/1.1 200 OK\r\nX-Cache: HIT\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                 "{\"id\":7,\"name\":\"one\"}") { cx =>
        plod::json(cx, 200, Project { id: 7, name: "one" }) { plod::field(cx, "X-Cache", "HIT"); };
    };
    answers(GET, "HTTP/1.1 200 OK\r\nX-A: 1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}") { cx =>
        plod::json_bytes(cx, 200, "{}") { plod::field(cx, "X-A", "1"); };
    };
    answers(GET, "HTTP/1.1 201 Created\r\nLocation: /p/7\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok") { cx =>
        plod::text(cx, 201, "ok") { plod::field(cx, "Location", "/p/7"); };
    };
    answers(GET, "HTTP/1.1 204 No Content\r\nSet-Cookie: sid=1; Path=/\r\n\r\n") { cx =>
        plod::empty(cx, 204) { plod::set_cookie(cx, http::Cookie { name: "sid", value: "1", path: "/" }); };
    };
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nETag: \"v1\"\r\nContent-Length: 1\r\n\r\nx") { cx =>
        plod::bytes(cx, 200, "image/png", "x") { plod::field(cx, "ETag", "\"v1\""); };
    };
    // A value that would split the response is refused, and nothing written.
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok") { cx =>
        plod::text(cx, 200, "ok") { assert(!plod::field(cx, "X-Bad", "a\r\nX-Evil: 1")); };
    };
    failed_inside();
    print("plod::bytes and the answers' fields: ok");
}

// A failure inside an answer's block cuts the response short, its head
// unended, and closes the connection.
fn failed_inside() {
    let req, status = http::parse(GET);
    assert(status == 200);
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = plod::NoState { .. };
    var scratch: u8[>..] = [];
    var app = plod::NoState { .. };
    var none = plod::NoRouter { .. };
    var cx = plod::Cx<plod::NoState, plod::NoState, plod::NoRouter> { req: req, body: "", out: http::Reply { buf: out,
                        common: "", keep_alive: keep, minor: 1, head: false, stream: st }, state: state, app: app,
                        scratch: scratch, router: none };
    plod::route(cx) {
        plod::text(cx, 200, "ok") { plod::fail(cx, 403, "denied"); };
    };
    expect::same(out, "HTTP/1.1 200 OK\r\n");
    assert(!keep);
    assert(!st.open);
}
