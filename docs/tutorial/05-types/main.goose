// docs/tutorial.md, section 5: the same routes as 05-reader, with the types,
// readers, and writers generated from api.json, a schema without paths.
//
//   build/goose-rest gen docs/tutorial/05-types/api.json -o docs/tutorial/05-types/api_gen.goose
import std;
import os;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../../../";
import .api_gen;

struct App { projects: api::Project[>..]& }

fn handle(cx, app: App&) {
    var r = http::router(cx.req);
    if http::on(r, "POST", "/projects") {
        rest::route(cx) {
            let body = rest::take<api::ProjectCreate>(cx);
            let p .= app.projects.push(api::Project {
                id: app.projects.len + 1, name: body.name, has_color: body.has_color, color: body.color,
            });
            rest::json(cx, 201, p);
        };
    } else if http::on(r, "GET", "/projects/:id") {
        rest::route(cx) {
            let id = rest::param_int(cx, r, "id");
            guard id >= 1 && id <= app.projects.len else { rest::fail(cx, 404, "project_not_found"); }
            rest::json(cx, 200, app.projects[id - 1]);
        };
    } else {
        rest::otherwise(cx, r);
    }
}

thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var app = App { projects: projects };
    let e = rest::serve(cfg) { cx => handle(cx, app) };
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
    thread_wait(thread_spawn(worker, cfg));
}
