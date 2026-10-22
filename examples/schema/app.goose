// The handlers api_gen.goose's dispatch calls, one per operationId in
// api.json, and the security check its token scheme names. Projects are kept
// in memory, in the worker.
namespace app;

import std;
import http;
import plod;
import api_gen;

// The worker state, dispatch's state: the projects and whether each is
// still there, by reference.
struct App { projects: api::Project[>..]&, live: bool[>..]&, token: const u8[:] }

// The projects whose name holds q, at most limit, as a JSON array.
struct Listing { app: const App&, q: const u8[:], limit: i64 }

fn format(out: u8[>..]&, l: const Listing&) {
    out.push('[');
    var n = 0;
    for p, i in l.app.projects {
        if !l.app.live[i] || find(p.name, l.q) < 0 || n == l.limit { continue; }
        if n > 0 { out.push(','); }
        n++;
        format(out, p);
    }
    out.push(']');
}

// The security scheme token: a bearer token, which must be the app's.
fn security_token(cx) -> bool {
    guard plod::bearer_token(cx) == cx.app.token else { plod::invalid_token(cx); }
    return true;
}

fn health(cx) { plod::text(cx, 200, "ok"); }

fn list_projects(cx, q: api::ListProjectsParams) {
    plod::json(cx, 200, Listing { app: cx.app, q: if q.has_q { q.q } else { "" }, limit: if q.has_limit { q.limit } else { 20 } });
}

fn create_project(cx, s: bool, body: const api::ProjectCreate&) {
    let p .= cx.app.projects.push(api::Project { id: cx.app.projects.len + 1, name: body.name });
    cx.app.live.push(true);
    plod::json(cx, 201, p);
}

// The index of project id, or a failure, 404 project_not_found.
fn index_of(cx, id: i64) -> i64 {
    guard id <= cx.app.projects.len && cx.app.live[id - 1] else { plod::fail(cx, 404, "project_not_found"); }
    return id - 1;
}

fn get_project(cx, id: i64) {
    plod::json(cx, 200, cx.app.projects[index_of(cx, id)]);
}

fn delete_project(cx, s: bool, id: i64) {
    cx.app.live[index_of(cx, id)] = false;
    plod::empty(cx, 204);
}
