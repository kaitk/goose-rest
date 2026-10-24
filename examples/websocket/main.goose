// A WebSocket under plod::serve, with the optional plod.websocket module: GET
// /ws opens one, and each message the client sends comes back. A ping gets
// its pong and a Close its Close from goose-http, after which the route
// gets CLOSED.
//
//   goose build -o build/examples/websocket examples/websocket/main.goose
//   build/examples/websocket 8080
//   websocat ws://localhost:8080/ws
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "../../";
import plod.websocket;

enum Use { None, Echo }

// The connection's WebSocket lives in the request state, from the upgrade to
// CLOSED.
struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };
    };
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

// Each message back as it came; CLOSED goes to ws_read too, which gives the
// gather pool the WebSocket's bytes back.
fn resume(u: Use.Echo, cx) {
    plod::ws_read(cx, cx.state.ws) { op, data => http::ws_send(cx.out, op, data); };
}

thread_fn worker(cfg: http::Config) {
    var app = plod::NoState { .. };
    let e = plod::serve(cfg, app, St { .. }) { cx =>
        if plod::resumed(cx) {
            plod::on_reply(cx) { resume(cx.state.use, cx); };
        } else {
            handle(cx);
        }
    };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, workers: 1, .. };
    http::run(cfg, worker);
}
