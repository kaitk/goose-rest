// A WebSocket route that publishes one batch per drain credit: it sends a
// message and calls http::after_drain at the upgrade, gets http::DRAINED
// once goose-http's loop has sent it, and sends the next until the third,
// then gets CLOSED when the connection ends. Event by event, as goose-http
// gives them.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "../../";
import plod.websocket;
import expect from "../";

enum Use { None, Publish }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. }, sent: i64 = 0 }

struct App { log: u8[>..]& }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::routes(cx) { cx =>
            plod::get(cx, "/feed") {
                plod::ws_upgrade(cx, cx.state.ws, Use.Publish);
                publish(cx);
            };
        };
    }
}

fn publish(cx) {
    guard cx.state.sent < 3 else { return; }
    cx.state.sent++;
    http::ws_send(cx.out, http::WS_TEXT, str("batch ", cx.state.sent));
    assert(http::after_drain(cx.out));
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Publish, cx) {
    format(cx.app.log, "[", cx.kind, "]");
    if cx.kind == http::DRAINED { publish(cx); }
    plod::ws_read(cx, cx.state.ws) { op, data => };
}

fn main() {
    let text = str("GET /feed HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",
                   "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n");
    let req, status = http::parse(text);
    assert(status == 200);
    var log: u8[>..] = [];
    var app = App { log: log };
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = plod::Slot<St> { state: St { .. } };
    http::gather_budget(http::GATHER_BUDGET);
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: stream };
    fn send(kind: u8) {
        plod::deliver(http::Event { kind: kind, req: req, data: "", whole: kind == http::REQUEST, trailers: "" },
                      st, app, reply) { cx => handle(cx); };
    }
    send(http::REQUEST);
    expect::same(expect::status_of(out), "HTTP/1.1 101 Switching Protocols", "the upgrade");
    let head = find(out, "\r\n\r\n") + 4;
    for i in 3 { send(http::DRAINED); }
    expect::same(out[head..], "\x81\x07batch 1\x81\x07batch 2\x81\x07batch 3", "one batch per credit");
    assert(!http::after_drain(reply));
    send(http::CLOSED);
    assert(http::gather_promised == 0);
    print("route calls: ", log);
}
