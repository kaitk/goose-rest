// Spike 09's state, the handlers api_gen.goose's dispatch calls, and the
// helpers both they and main.goose's hand-written routes call. README.md has
// the verdict.
namespace app;

import std;
import http;
import rest;
import api_gen;

// The worker's state, cx.app: the projects, where the database thread takes
// jobs, and counts the output shows.
struct App {
    projects: api::Project[>..]&,
    live: bool[>..]&,
    db: http::MailAddress,
    audits: i64 = 0,
    lookups: i64 = 0,
}

struct User { name: u8[..16] = "", admin: bool = false }

// What a route that asked the database keeps until the reply comes.
enum Waiting {
    None,
    Report { id: i64 },
}

// The per-request state, cx.state.
struct St { user: rest::Once<User>, waiting: Waiting = Waiting.None }

// The request's user, from its bearer token, looked up once a request.
fn user(cx) -> User& {
    return rest::once(cx.state.user) { lookup(cx) };
}

fn lookup(cx) -> User {
    let token = rest::bearer_token(cx);
    cx.app.lookups++;
    if token == "ada" { return User { name: "ada", admin: true }; }
    guard token == "bob" else { rest::invalid_token(cx); }
    return User { name: "bob" };
}

// The project of the route's :id that the user may see. Three calls below a
// route, it reads the router (the path parameter), the worker's state (the
// projects), and the request's (the user).
fn visible(cx) -> api::Project& {
    return owned(cx, rest::param_int(cx, "id"));
}

fn owned(cx, id: i64) -> api::Project& {
    let i = index_of(cx, id);
    guard cx.app.projects[i].owner == user(cx).name || user(cx).admin else { rest::fail(cx, 403, "not_owner"); }
    return cx.app.projects[i];
}

fn index_of(cx, id: i64) -> i64 {
    guard id >= 1 && id <= cx.app.projects.len && cx.app.live[id - 1] else { rest::fail(cx, 404, "project_not_found"); }
    return id - 1;
}

fn security_token(cx) -> const u8[:] { user(cx).name }

// The projects, and how many times a user was looked up so far: once per
// request, though the check and this handler both ask.
fn list_projects(cx, name: const u8[:]) {
    rest::text(cx, 200, str(user(cx).name, " sees ", cx.app.projects.len, " projects; lookups ", cx.app.lookups));
}

// Reads the project through visible, which takes :id from the router rather
// than from id: a helper written for the hand-written routes.
fn get_project(cx, name: const u8[:], id: i64) { rest::json(cx, 200, visible(cx)); }

fn delete_project(cx, name: const u8[:], id: i64) {
    cx.app.live[index_of(cx, owned(cx, id).id)] = false;
    rest::empty(cx, 204);
}
