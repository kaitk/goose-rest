// The handlers api_gen.goose's dispatch calls, one per operationId in
// api.json, and the check its token scheme names.
namespace app;

import std;
import rest;
import api_gen;

// The worker's state, which dispatch passes to each handler.
struct App { projects: api::Project[>..]&, token: const u8[:] }

// The scheme token: a bearer token, whose user the handlers it guards get.
fn security_token(cx, state: App&) -> const u8[:] {
    guard rest::bearer_token(cx) == state.token else { rest::invalid_token(cx); }
    return "ada";
}

fn health(cx, state: App&) { rest::text(cx, 200, "ok"); }

fn list_projects(cx, state: App&, q: api::ListProjectsParams) {
    rest::json(cx, 200, Listing { app: state, q: if q.has_q { q.q } else { "" }, limit: if q.has_limit { q.limit } else { 20 } });
}

fn create_project(cx, state: App&, user: const u8[:], body: const api::ProjectCreate&) {
    let p .= state.projects.push(api::Project { id: state.projects.len + 1, name: body.name, owner: user });
    rest::json(cx, 201, p);
}

fn get_project(cx, state: App&, id: i64) {
    guard id <= state.projects.len else { rest::fail(cx, 404, "project_not_found"); }
    rest::json(cx, 200, state.projects[id - 1]);
}

// The projects whose name holds q, at most limit, as a JSON array.
struct Listing { app: const App&, q: const u8[:], limit: i64 }

fn format(out: u8[>..]&, l: const Listing&) {
    out.push('[');
    var n = 0;
    for p in l.app.projects {
        if find(p.name, l.q) < 0 || n == l.limit { continue; }
        if n > 0 { out.push(','); }
        format(out, p);
        n++;
    }
    out.push(']');
}
