// docs/best-practices/state.md: data known at build time in a global, and
// what one worker counts in its own state. One worker, so that the count
// below is the server's.
//
//   goose build -o build/state docs/best-practices/state/main.goose
//   build/state 8080
//   curl -s localhost:8080/holidays
import std;
import os;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../../";
import .app;

thread_fn worker(cfg: http::Config) {
    // Each worker's own App, which its routes reach as cx.app.
    var app = App { lookups: 0 };
    let e = rest::serve(cfg, app) { cx => handle(cx) };
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
