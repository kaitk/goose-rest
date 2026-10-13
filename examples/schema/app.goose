// The handlers api_gen.goose's dispatch calls, one per operationId in
// api.json, and the security check its token scheme names. Projects are kept
// in memory, in the worker.
namespace app;

import std;
import http;
import rest;
import api_gen;

// The worker's state, dispatch's state: the projects and whether each is
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

// The security scheme token: a bearer token, which must be state's.
fn security_token(cx, state: App&) -> bool {
    guard rest::bearer_token(cx) == state.token else { rest::invalid_token(cx); }
    return true;
}

fn health(cx, state: App&) { rest::text(cx, 200, "ok"); }

fn list_projects(cx, state: App&, q: api::ListProjectsParams) {
    rest::json(cx, 200, Listing { app: state, q: if q.has_q { q.q } else { "" }, limit: if q.has_limit { q.limit } else { 20 } });
}

fn create_project(cx, state: App&, s: bool, body: const api::ProjectCreate&) {
    let p .= state.projects.push(api::Project { id: state.projects.len + 1, name: body.name });
    state.live.push(true);
    rest::json(cx, 201, p);
}

// The index of project id, or a failure, 404 project_not_found.
fn index_of(cx, state: App&, id: i64) -> i64 {
    guard id <= state.projects.len && state.live[id - 1] else { rest::fail(cx, 404, "project_not_found"); }
    return id - 1;
}

fn get_project(cx, state: App&, id: i64) {
    rest::json(cx, 200, state.projects[index_of(cx, state, id)]);
}

fn delete_project(cx, state: App&, s: bool, id: i64) {
    state.live[index_of(cx, state, id)] = false;
    http::start(cx.out, 204);
    http::finish(cx.out, "", "");
}
