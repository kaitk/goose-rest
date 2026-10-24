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
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../../";
import projects.structs;
import projects.routes;

struct App { projects: projects::Project[>..]& }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/projects") { projects::routes(cx); };
    };
}

thread_fn worker(cfg: http::Config) {
    var projects: projects::Project[>..] = [];
    var app = App { projects: projects };
    let e = plod::serve(cfg, app) { cx => handle(cx) };
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
