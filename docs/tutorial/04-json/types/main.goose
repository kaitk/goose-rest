// docs/tutorial/04-json.md: the same routes as reader/, with the types,
// readers, and writers generated from api.json, a schema without paths.
//
//   build/goose-rest gen docs/tutorial/04-json/types/api.json -o docs/tutorial/04-json/types/api_gen.goose
import std;
import os;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
import rest from "../../../../";
import .api_gen;

struct App { projects: api::Project[>..]& }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "POST", "/projects") {
            rest::route(cx) {
                let body = rest::take<api::ProjectCreate>(cx);
                let p .= cx.app.projects.push(api::Project {
                    id: cx.app.projects.len + 1, name: body.name, has_color: body.has_color, color: body.color,
                });
                rest::json(cx, 201, p);
            };
        } else if rest::on(cx, "GET", "/projects/:id") {
            rest::route(cx) {
                let id = rest::param_int(cx, "id");
                guard id >= 1 && id <= cx.app.projects.len else { rest::fail(cx, 404, "project_not_found"); }
                rest::json(cx, 200, cx.app.projects[id - 1]);
            };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
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
    thread_wait(thread_spawn(worker, cfg));
}
