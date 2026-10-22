// rest::ws_upgrade on an HTTP/2 stream, which can't switch protocols: 501
// not_implemented in goose-rest's error shape, nothing promised from the
// gather pool, and no later call.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import rest from "../../";
import rest.websocket;
import expect from "../";

enum Use { None, Ws }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

fn main() {
    let text = str("GET /ws HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",
                   "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n");
    let req, status = http::parse(text);
    assert(status == 200);
    var app = rest::NoState { .. };
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<St> { state: St { .. } };
    http::gather_budget(http::GATHER_BUDGET);
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: http::H2_MINOR, head: false,
                              stream: stream };
    rest::deliver(http::Event { kind: http::REQUEST, req: req, data: "", whole: true, trailers: "" }, st, app, reply) { cx =>
        if rest::resumed(cx) { print("a later call"); } else { rest::ws_upgrade(cx, cx.state.ws, Use.Ws); }
    };
    expect::same(expect::status_of(out), "HTTP/1.1 501 Not Implemented", "h2's answer");
    expect::same(expect::body_of(out), "{\"error\":\"not_implemented\"}", "its body");
    assert(st.ex.mode == 0 && http::gather_promised == 0);
    print("rest::ws_upgrade on h2: ok");
}
