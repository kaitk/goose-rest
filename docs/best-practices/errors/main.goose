// docs/best-practices/errors.md: Plod's one error shape, a domain's
// errors in its errors.goose, and the errors several domains answer in
// common/errors.goose.
//
//   goose build -o build/errors docs/best-practices/errors/main.goose
//   build/errors 8080
//   curl -s localhost:8080/projects/2
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../../";
import projects.routes;

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/projects") { projects::routes(cx); };
    };
}

thread_fn worker(cfg: http::Config) {
    let e = plod::serve(cfg) { cx => handle(cx) };
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
