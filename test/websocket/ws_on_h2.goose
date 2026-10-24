// plod::ws_upgrade on an HTTP/2 stream, which can't switch protocols: 501
// not_implemented in Plod's error shape, nothing promised from the
// gather pool, and no later call.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "../../";
import plod.websocket;
import expect from "../";

enum Use { None, Ws }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

fn main() {
    let text = str("GET /ws HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",
                   "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n");
    let req, status = http::parse(text);
    assert(status == 200);
    var app = plod::NoState { .. };
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = plod::Slot<St> { state: St { .. } };
    http::gather_budget(http::GATHER_BUDGET);
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: http::H2_MINOR, head: false,
                              stream: stream };
    plod::deliver(http::Event { kind: http::REQUEST, req: req, data: "", whole: true, trailers: "" }, st, app, reply) { cx =>
        if plod::resumed(cx) { print("a later call"); } else { plod::ws_upgrade(cx, cx.state.ws, Use.Ws); }
    };
    expect::same(expect::status_of(out), "HTTP/1.1 501 Not Implemented", "h2's answer");
    expect::same(expect::body_of(out), "{\"error\":\"not_implemented\"}", "its body");
    assert(st.ex.mode == 0 && http::gather_promised == 0);
    print("plod::ws_upgrade on h2: ok");
}
