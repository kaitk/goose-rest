// docs/tutorial/04-json.md: a JSON body read by a hand-written reader.
// One worker, since the projects live in the worker (08-state.md).
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../../../../";

struct Project { id: i64, name: u8[..256] }

fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.push('}');
}

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
    let n = rest::code_points(name);
    if has_name && (n < 1 || n > 64) { json::fail(r, "name: length"); }
    if r.error.len > 0 { return ProjectCreate { name: "" }; }
    return ProjectCreate { name: name };
}

fn rest::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    rest::json_body(cx) { r, scratch => read_create(r, scratch) }
}

// The worker's state, which the handlers get by reference.
struct App { projects: Project[>..]& }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "POST", "/projects") {
            rest::route(cx) {
                let body = rest::take<ProjectCreate>(cx);
                let p .= cx.app.projects.push(Project { id: cx.app.projects.len + 1, name: body.name });
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
    var projects: Project[>..] = [];
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
