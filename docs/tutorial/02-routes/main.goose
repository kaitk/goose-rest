// docs/tutorial/02-routes.md and 03-errors.md: routes in a rest::routes chain, a
// scope, the extractors, and answers in JSON.
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../../../";

struct Project { id: i64, name: u8[..64], archived: bool }

let PROJECTS = [
    Project { id: 1, name: "goose", archived: false },
    Project { id: 2, name: "gander", archived: false },
    Project { id: 3, name: "gosling", archived: true },
];

// How rest::json writes a Project.
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.push('}');
}

// The projects a listing shows, as a JSON array.
struct Listing { q: const u8[:], archived: bool, limit: i64 }

fn format(out: u8[>..]&, l: const Listing&) {
    out.push('[');
    var n = 0;
    for p in PROJECTS {
        if p.archived != l.archived || find(p.name, l.q) < 0 || n == l.limit { continue; }
        if n > 0 { out.push(','); }
        format(out, p);
        n++;
    }
    out.push(']');
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/v1") {
            rest::route(cx) { v1(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

// The routes under /v1, matched without the prefix.
fn v1(cx) {
    if rest::on(cx, "GET", "/projects") {
        let q, has_q = rest::query(cx, "q");
        let archived, has_archived = rest::query_bool(cx, "archived");
        let limit, has_limit = rest::query_int(cx, "limit");
        rest::json(cx, 200, Listing { q: q, archived: archived, limit: if has_limit { limit } else { 10 } });
    } else if rest::on(cx, "GET", "/projects/:id") {
        rest::json(cx, 200, find_project(cx, rest::param_int(cx, "id")));
    } else if rest::on(cx, "GET", "/me") {
        let user, has_user = rest::header(cx, "X-User");
        rest::require(cx, "X-User", has_user);
        let theme, has_theme = rest::cookie(cx, "theme");
        rest::text(cx, 200, str(user, " likes ", if has_theme { theme } else { "light" }));
    } else {
        rest::otherwise(cx);
    }
}

fn find_project(cx, id: i64) -> const Project& {
    for &p in PROJECTS {
        if p.id == id { return p; }
    }
    rest::fail(cx, 404, "project_not_found");
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
