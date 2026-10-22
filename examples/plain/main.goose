// A JSON API without a schema: projects kept in memory, behind the access
// log and Server-Timing, CORS, and a bearer token for the writes. One worker,
// since workers share nothing and the projects live in the worker.
//
//   goose build -o build/examples/plain examples/plain/main.goose
//   build/examples/plain 8080
//   curl -s localhost:8080/v1/projects
//   curl -s -H 'Authorization: Bearer secret' -H 'Content-Type: application/json' \
//        -d '{"name": "goose"}' localhost:8080/v1/projects
//   curl -s -H 'Authorization: Bearer secret' -d 'name=wild+goose' localhost:8080/v1/projects
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";

struct Project { id: i64, name: u8[..256], deleted: bool = false }

// The worker's projects, which the handlers get by reference, as cx.app.
struct App { projects: Project[>..]&, token: const u8[:] }

// A project's JSON.
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    http::json_string(out, p.name);
    out.push('}');
}

// The projects whose name holds q, as a JSON array.
struct Listing { projects: const Project[:], q: const u8[:] }

fn format(out: u8[>..]&, l: const Listing&) {
    out.push('[');
    var first = true;
    for p in l.projects {
        if p.deleted || find(p.name, l.q) < 0 { continue; }
        if !first { out.push(','); }
        first = false;
        format(out, p);
    }
    out.push(']');
}

// What POST /v1/projects takes: {"name": "..."}, 1 to 64 code points.
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

// plod::take<ProjectCreate> reads the body with read_create.
fn plod::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    plod::json_body(cx) { r, scratch => read_create(r, scratch) }
}

// What POST /v1/projects takes as a form, name=..., checked as read_create
// checks the JSON.
fn form_create(cx) -> ProjectCreate {
    let name, has_name = plod::form(cx, "name");
    plod::require(cx, "name", has_name);
    let n = plod::code_points(name);
    if n < 1 || n > 64 { plod::fail_param(cx, "name: length"); }
    return ProjectCreate { name: name };
}

// The longest logo PUT /v1/projects/:id/logo takes. Other routes keep
// plod::body's 1 MB, and http::Config's max_body is raised to this, the most
// any route takes.
let LOGO_LIMIT: i64 = 4 * 1024 * 1024;

// What a logo upload answers: its size. The example keeps no files.
struct Logo { id: i64, bytes: i64 }

fn format(out: u8[>..]&, l: const Logo&) {
    format(out, "{\"id\":", l.id, ",\"bytes\":", l.bytes, "}");
}

fn find_project(cx, id: i64) -> Project& {
    for &p in cx.app.projects {
        if p.id == id && !p.deleted { return p; }
    }
    plod::fail(cx, 404, "project_not_found");
}

fn handle(cx) {
    plod::timed(cx) {
        plod::cors(cx, plod::Cors { origins: "https://app.example", .. }) {
            plod::routes(cx) { cx =>
                plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
                plod::scope(cx, "/v1") { projects(cx); };
            };
        };
    };
}

// The routes under /v1.
fn projects(cx) {
    plod::get(cx, "/projects") {
        let q, has_q = plod::query(cx, "q");
        plod::json(cx, 200, Listing { projects: cx.app.projects, q: q });
    };
    plod::post(cx, "/projects") {
        plod::bearer(cx) { token =>
            guard token == cx.app.token else { plod::invalid_token(cx); }
            let form = http::has_type(cx.req, "application/x-www-form-urlencoded");
            let body = if form { form_create(cx) } else { plod::take<ProjectCreate>(cx) };
            let p .= cx.app.projects.push(Project { id: cx.app.projects.len + 1, name: body.name });
            plod::json(cx, 201, p);
        };
    };
    plod::get(cx, "/projects/:id") { plod::json(cx, 200, find_project(cx, plod::param_int(cx, "id"))); };
    plod::put(cx, "/projects/:id/logo") {
        // A body past the read buffer runs this block twice, so nothing
        // before plod::body changes state.
        plod::bearer(cx) { token =>
            guard token == cx.app.token else { plod::invalid_token(cx); }
            let p = find_project(cx, plod::param_int(cx, "id"));
            let logo = plod::body(cx, LOGO_LIMIT);
            plod::json(cx, 200, Logo { id: p.id, bytes: logo.len });
        };
    };
    plod::delete(cx, "/projects/:id") {
        plod::bearer(cx) { token =>
            guard token == cx.app.token else { plod::invalid_token(cx); }
            let p .= find_project(cx, plod::param_int(cx, "id"));
            p.deleted = true;
            plod::empty(cx, 204);
        };
    };
}

thread_fn worker(cfg: http::Config) {
    var projects: Project[>..] = [];
    var app = App { projects: projects, token: "secret" };
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
    let cfg = http::Config { port: port as i32, workers: 1, max_body: LOGO_LIMIT, .. };
    http::run(cfg, worker);
}
