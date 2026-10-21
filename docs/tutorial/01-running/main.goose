// docs/tutorial/01-running.md: one route, and a failure from below it.
//
//   goose build -o build/hello docs/tutorial/01-running/main.goose
//   build/hello 8080
//   curl -s localhost:8080/hello/goose
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../../";

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/hello/:name") { hello(cx, rest::param(cx, "name")); };
    };
}

fn hello(cx, name: const u8[:]) {
    rest::text(cx, 200, greeting(cx, name));
}

fn greeting(cx, name: const u8[:]) -> u8[>..] {
    // Answers 400, and leaves every caller up to the route around hello.
    guard name.len <= 20 else { rest::fail(cx, 400, "name_too_long"); }
    return str("hello, ", name);
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
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
    let cfg = http::Config { port: port as i32, .. };
    http::run(cfg, worker);
}
