// plod::ws_upgrade and plod::ws_read under serve_one: a text message echoed,
// a message in two fragments joined, a ping answered, and the client's
// Close answered, after which the route gets CLOSED and the gather pool has
// its bytes back; then a subprotocol named in the 101, and the refusals in
// Plod's error shape, a protocol that isn't a field value's among them.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "../../";
import plod.websocket;
import expect from "../";

enum Use { None, Echo }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

struct App { log: u8[>..]& }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::routes(cx) { cx =>
            plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };
            plod::get(cx, "/chat") {
                let offered, _ = http::field_of(cx.req, "sec-websocket-protocol");
                plod::ws_upgrade(cx, cx.state.ws, Use.Echo, if find(offered, "chat") >= 0 { "chat" } else { "" });
            };
            // A protocol that isn't a field value: 400, as http::ws_upgrade answers it.
            plod::get(cx, "/bad") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo, "chat\r\nX: y"); };
        };
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Echo, cx) {
    if cx.kind == http::CLOSED { cx.app.log.append("[CLOSED]"); }
    plod::ws_read(cx, cx.state.ws) { op, data =>
        format(cx.app.log, "[", op, " ", data, "]");
        http::ws_send(cx.out, op, data);
    };
}

let KEY = "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n";
let ASKED = "Connection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\n";

// A frame as a client sends it, masked.
fn frame(out: u8[>..]&, first: u8, data: const u8[:]) {
    let mask: u8[4] = [1, 2, 3, 4];
    out.push(first);
    out.push(0x80 | data.len as! u8);
    out.append(mask);
    for b, i in data { out.push(b ^ mask[i & 3]); }
}

fn served(text: const u8[:], budget: i64 = http::GATHER_BUDGET) -> u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    http::gather_budget(budget);
    let out = plod::serve_one(text, app, St { .. }) { cx =>
        handle(cx);
    };
    if log.len > 0 { print("  log: ", log); }
    return out;
}

fn main() {
    var frames: u8[>..] = [];
    frame(frames, 0x81, "hello");
    frame(frames, 0x01, "hel");   // a text message in two fragments
    frame(frames, 0x80, "lo!");
    frame(frames, 0x89, "p");     // a ping
    frame(frames, 0x88, "\x03\xe8");
    let out = served(str(expect::request("GET", "/ws", str(ASKED, KEY)), frames));
    expect::same(out, str("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",
                          "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
                          "\x81\x05hello\x81\x06hello!\x8a\x01p\x88\x02\x03\xe8"), "the echo");
    assert(http::gather_promised == 0);
    print("echo: ok");

    let chat = served(expect::request("GET", "/chat", str(ASKED, KEY, "Sec-WebSocket-Protocol: chat, superchat\r\n")));
    assert(find(chat, "\r\nSec-WebSocket-Protocol: chat\r\n\r\n") > 0);
    assert(http::gather_promised == 0);
    print("chat: ok");

    print(served(expect::request("GET", "/ws")));
    print(served(expect::request("GET", "/ws", "Connection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 8\r\n")));
    print(served(expect::request("GET", "/ws", str(ASKED, "Sec-WebSocket-Key: short\r\n"))));
    print(served(expect::request("GET", "/ws", str(ASKED, KEY)), 1024));
    print(served(expect::request("GET", "/bad", str(ASKED, KEY))));
    assert(http::gather_promised == 0);
}
