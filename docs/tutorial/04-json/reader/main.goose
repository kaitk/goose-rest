// docs/tutorial/04-json.md: a JSON body read by a hand-written reader.
// One worker, since the projects live in the worker (08-state.md).
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../../../";

struct Project { id: i64, name: u8[..256] }

fn format(out: u8[>..]&, p: const Project&) { plod::format_fields(out, p); }

// What POST /projects takes: {"name": "..."}, 1 to 64 code points.
struct ProjectCreate { name: u8[..256] }

fn read_create(r: json::Reader&, scratch: u8[>..]&) -> ProjectCreate {
    var name = r.text[..0];
    var has_name = false;
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); has_name = true; }
        else { json::fail(r, "unknown member"); }
    };
    if !has_name { json::fail(r, "name: required"); }
    let n = plod::code_points(name);
    if has_name && (n < 1 || n > 64) { json::fail(r, "name: length"); }
    if r.error.len > 0 { return ProjectCreate { name: "" }; }
    return ProjectCreate { name: name };
}

fn plod::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    plod::json_body(cx) { r, scratch => read_create(r, scratch) }
}

// The worker state, which the handlers get by reference.
struct App { projects: Project[>..]& }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::post(cx, "/projects") {
            let body = plod::take<ProjectCreate>(cx);
            let p .= cx.app.projects.push(Project { id: cx.app.projects.len + 1, name: body.name });
            plod::json(cx, 201, p);
        };
        plod::get(cx, "/projects/:id") {
            let id = plod::param_int(cx, "id");
            guard id >= 1 && id <= cx.app.projects.len else { plod::fail(cx, 404, "project_not_found"); }
            plod::json(cx, 200, cx.app.projects[id - 1]);
        };
    };
}

thread_fn worker(cfg: http::Config) {
    var projects: Project[>..] = [];
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
