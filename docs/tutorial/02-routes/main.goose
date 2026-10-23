// docs/tutorial/02-routes.md and 03-errors.md: routes in a plod::routes chain, a
// scope, the extractors, and answers in JSON.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../../";

struct Project { id: i64, name: u8[..64], archived: bool }

let PROJECTS = [
    Project { id: 1, name: "goose", archived: false },
    Project { id: 2, name: "gander", archived: false },
    Project { id: 3, name: "gosling", archived: true },
];

// How plod::json writes a Project.
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    http::json_string(out, p.name);
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
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/v1") { v1(cx); };
    };
}

// The routes under /v1, matched without the prefix.
fn v1(cx) {
    plod::get(cx, "/projects") {
        let q, has_q = plod::query(cx, "q");
        let archived, has_archived = plod::query_bool(cx, "archived");
        let limit, has_limit = plod::query_int(cx, "limit");
        plod::json(cx, 200, Listing { q: q, archived: archived, limit: if has_limit { limit } else { 10 } });
    };
    plod::get(cx, "/projects/:id") { plod::json(cx, 200, find_project(cx, plod::param_int(cx, "id"))); };
    plod::get(cx, "/me") {
        let user, has_user = plod::header(cx, "X-User");
        plod::require(cx, "X-User", has_user);
        let theme, has_theme = plod::cookie(cx, "theme");
        plod::text(cx, 200, str(user, " likes ", if has_theme { theme } else { "light" }));
    };
}

fn find_project(cx, id: i64) -> const Project& {
    for &p in PROJECTS {
        if p.id == id { return p; }
    }
    plod::fail(cx, 404, "project_not_found");
}

thread_fn worker(cfg: http::Config) {
    let e = plod::serve(cfg) { cx => handle(cx) };
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
    http::run(cfg, worker);
}
