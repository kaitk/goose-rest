// An upgraded connection under rest::serve: GET /echo with "Upgrade: echo"
// gets 101, and then each byte the client sends comes back, until a piece
// that holds "bye", after which the server closes the connection. A
// WebSocket would frame its messages on top of this.
//
//   goose build -o build/examples/upgrade examples/upgrade/main.goose
//   build/examples/upgrade 8080
//   printf 'GET /echo HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\nhello\nbye\n' |
//       curl -s telnet://localhost:8080
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.1";
import rest from "../../";

enum Use { None, Echo }

struct St { use: Use = Use.None, bytes: i64 = 0 }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "GET", "/echo") {
            rest::route(cx) { echo(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn echo(cx) {
    // Only a request that asks to switch to "echo"; any other gets 426.
    guard http::upgrade_of(cx.req) == "echo" else { rest::fail(cx, 426, "upgrade_required"); }
    // Answers 101. From here the connection is the route's: the client's
    // bytes come to resume(Use.Echo) as BODY, and rest::send writes raw.
    rest::upgrade(cx, "echo", Use.Echo);
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// Each piece of the client's bytes, back as they are.
fn resume(u: Use.Echo, cx) {
    if cx.kind == http::BODY {
        cx.state.bytes += cx.body.len;
        rest::send(cx, cx.body);
        // rest::end closes an upgraded connection.
        if find(cx.body, "bye") >= 0 { rest::end(cx); }
    } else if cx.kind == http::CLOSED {
        // The client closed first; a route that ends gets no CLOSED.
        write_stderr(str("echo: the client closed after ", cx.state.bytes, " bytes\n"));
    }
}

thread_fn worker(cfg: http::Config) {
    var app = rest::NoState { .. };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::on_reply(cx) { resume(cx.state.use, cx); };
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
