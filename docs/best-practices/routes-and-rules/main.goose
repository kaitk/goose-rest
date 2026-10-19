// docs/best-practices/routes-and-rules.md: a route that extracts, calls one
// rule, and answers, and the rule it calls, which takes typed input and
// returns a result or an error, with no cx. One worker, as the projects
// live in its memory in place of a database.
//
//   goose build -o build/routes-and-rules docs/best-practices/routes-and-rules/main.goose
//   build/routes-and-rules 8080
//   curl -s -d name=goose localhost:8080/projects
import std;
import os;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../../";
import projects.structs;
import projects.routes;

struct App { projects: projects::Project[>..]& }

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
    var projects: projects::Project[>..] = [];
    var app = App { projects: projects };
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
