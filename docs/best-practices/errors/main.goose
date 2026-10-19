// docs/best-practices/errors.md: goose-rest's one error shape, a domain's
// errors in its errors.goose, and the errors several domains answer in
// common/errors.goose.
//
//   goose build -o build/errors docs/best-practices/errors/main.goose
//   build/errors 8080
//   curl -s localhost:8080/projects/2
import std;
import os;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../../";
import projects.routes;

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/projects") {
            rest::route(cx) { projects::routes(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
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
