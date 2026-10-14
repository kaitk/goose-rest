// A JSON API from a schema: api.json describes it, goose-rest gen writes
// api_gen.goose from it (types, readers, writers, extractors, and dispatch),
// and app.goose holds the handlers. One worker, since workers share nothing
// and the projects live in the worker.
//
//   build/goose-rest gen examples/schema/api.json -o examples/schema/api_gen.goose
//   goose build -o build/examples/schema examples/schema/main.goose
//   build/examples/schema 8080
//   curl -s 'localhost:8080/v1/projects?limit=10'
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "../../";
import .api_gen;
import .app;

thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var live: bool[>..] = [];
    var app = app::App { projects: projects, live: live, token: "secret" };
    let e = rest::serve(cfg, app) { cx =>
        rest::timed(cx) {
            rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) { api::dispatch(cx); };
        };
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
    let cfg = http::Config { port: port as i32, workers: 1, max_body: api::MAX_BODY, .. };
    thread_wait(thread_spawn(worker, cfg));
}
