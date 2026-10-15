// docs/tutorial/01-running.md: one route, and a failure from below it.
//
//   goose build -o build/hello docs/tutorial/01-running/main.goose
//   build/hello 8080
//   curl -s localhost:8080/hello/goose
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../../";

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/hello/:name") {
            rest::route(cx) { hello(cx, rest::param(cx, "name")); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn hello(cx, name: const u8[:]) {
    rest::text(cx, 200, greeting(cx, name));
}

fn greeting(cx, name: const u8[:]) -> u8[>..] {
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
