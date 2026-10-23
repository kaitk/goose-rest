import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../";
import expect from "../";
import common;

struct App { log: u8[>..]& }

fn handle(cx) {
    if plod::resumed(cx) {
        if cx.kind == http::TIMEOUT {
            cx.app.log.append("T ");
            plod::sse_event(cx, "tick", "ok");
            plod::end(cx);
        } else if cx.kind == http::CLOSED {
            cx.app.log.append("C ");
        } else {
            abort("unexpected SSE event");
        }
    } else {
        plod::sse_begin(cx, Use.Events);
        if cx.out.head { return; }
        plod::sse_comment(cx, "alive");
        plod::pause(cx, 1000);
    }
}

fn main() {
    var log: u8[>..] = [];
    var app = App { log: log };
    let get = plod::serve_one(expect::request("GET", "/events"), app, St { .. },
                              [plod::Wake { timeout: true }]) { cx => handle(cx); };
    expect::same(get, str("HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nX-Accel-Buffering: no\r\n",
                          "Transfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n",
                          "9\r\n: alive\n\n\r\n16\r\nevent: tick\ndata: ok\n\n\r\n0\r\n\r\n"), "paused stream");
    expect::same(log, "T ", "one timeout, no MORE or CLOSED after end");
    log.clear();
    let head = plod::serve_one(expect::request("HEAD", "/events"), app, St { .. }) { cx => handle(cx); };
    expect::same(head, str("HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nX-Accel-Buffering: no\r\n",
                           "Transfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n"), "HEAD");
    expect::same(log, "", "HEAD has no later calls");
    let closed = plod::serve_one(expect::request("GET", "/events"), app, St { .. }) { cx => handle(cx); };
    expect::same(expect::body_of(closed), "9\r\n: alive\n\n\r\n", "client leaves during pause");
    expect::same(log, "C ", "CLOSED during pause");
    print("SSE stream: ok");
}
