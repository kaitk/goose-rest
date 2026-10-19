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
import http from "github.com/kaitk/goose-http@2c5280c76ade5f70f69a80cd68f73b03d5b34252";
import rest from "../../";

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
    let n = rest::code_points(name);
    if has_name && (n < 1 || n > 64) { json::fail(r, "name: length"); }
    if r.error.len > 0 { return ProjectCreate { name: "" }; }
    return ProjectCreate { name: name };
}

// rest::take<ProjectCreate> reads the body with read_create.
fn rest::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    rest::json_body(cx) { r, scratch => read_create(r, scratch) }
}

// What POST /v1/projects takes as a form, name=..., checked as read_create
// checks the JSON.
fn form_create(cx) -> ProjectCreate {
    let name, has_name = rest::form(cx, "name");
    rest::require(cx, "name", has_name);
    let n = rest::code_points(name);
    if n < 1 || n > 64 { rest::fail_param(cx, "name: length"); }
    return ProjectCreate { name: name };
}

// The longest logo PUT /v1/projects/:id/logo takes. Other routes keep
// rest::body's 1 MB, and http::Config's max_body is raised to this, the most
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
    rest::fail(cx, 404, "project_not_found");
}

fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    rest::route(cx) { projects(cx); };
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}

// The routes under /v1, inside the route.
fn projects(cx) {
    if rest::on(cx, "GET", "/projects") {
        let q, has_q = rest::query(cx, "q");
        rest::json(cx, 200, Listing { projects: cx.app.projects, q: q });
    } else if rest::on(cx, "POST", "/projects") {
        rest::bearer(cx) { token =>
            guard token == cx.app.token else { rest::invalid_token(cx); }
            let form = http::has_type(cx.req, "application/x-www-form-urlencoded");
            let body = if form { form_create(cx) } else { rest::take<ProjectCreate>(cx) };
            let p .= cx.app.projects.push(Project { id: cx.app.projects.len + 1, name: body.name });
            rest::json(cx, 201, p);
        };
    } else if rest::on(cx, "GET", "/projects/:id") {
        rest::json(cx, 200, find_project(cx, rest::param_int(cx, "id")));
    } else if rest::on(cx, "PUT", "/projects/:id/logo") {
        // A body past the read buffer runs this block twice, so nothing
        // before rest::body changes state.
        rest::bearer(cx) { token =>
            guard token == cx.app.token else { rest::invalid_token(cx); }
            let p = find_project(cx, rest::param_int(cx, "id"));
            let logo = rest::body(cx, LOGO_LIMIT);
            rest::json(cx, 200, Logo { id: p.id, bytes: logo.len });
        };
    } else if rest::on(cx, "DELETE", "/projects/:id") {
        rest::bearer(cx) { token =>
            guard token == cx.app.token else { rest::invalid_token(cx); }
            let p .= find_project(cx, rest::param_int(cx, "id"));
            p.deleted = true;
            rest::empty(cx, 204);
        };
    } else {
        rest::otherwise(cx);
    }
}

thread_fn worker(cfg: http::Config) {
    var projects: Project[>..] = [];
    var app = App { projects: projects, token: "secret" };
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
    let cfg = http::Config { port: port as i32, workers: 1, max_body: LOGO_LIMIT, .. };
    http::run(cfg, worker);
}
