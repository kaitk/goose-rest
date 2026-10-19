// The entries: the route, its job on the writer lane, and its resume.
namespace entries;

import std;
import rest;

struct Entry { id: i64 = 0, project: i64 = 0, started: i64 = 0, stopped: i64 = 0 }

enum Error { None, EndsBeforeStart }

// Fails with e's status and code, in a route or on a lane: x is a route's cx
// or a lane's job.
fn check(e: Error.None, x) {}
fn check(e: Error.EndsBeforeStart, x) { rest::fail(x, 422, "entry_ends_before_start"); }

fn format(out: u8[>..]&, e: const Entry&) {
    format(out, "{\"id\":", e.id, ",\"project\":", e.project, ",\"started\":", e.started,
           ",\"stopped\":", e.stopped, "}");
}

fn routes(cx) {
    if rest::on(cx, "POST", "") { create(cx); } else { rest::otherwise(cx); }
}

// On the worker: ask the writer lane.
fn create(cx) {
    let project, has_project = rest::query_int(cx, "project");
    rest::require(cx, "project", has_project);
    let started, has_started = rest::query_int(cx, "started");
    rest::require(cx, "started", has_started);
    let stopped, has_stopped = rest::query_int(cx, "stopped");
    rest::require(cx, "stopped", has_stopped);
    rest::ask(cx, cx.app.writer, Use.EntryCreate { project: project, started: started, stopped: stopped });
}

// On the writer lane: the rule, which fails the route from here.
fn ::run(u: Use.EntryCreate, db: Db&, a) {
    entries::check(entries::ordered(u.started, u.stopped), a);
    let e = entries::Entry { id: db.entries.len + 1, project: u.project, started: u.started, stopped: u.stopped };
    db.entries.push(e);
    rest::reply_value(a, e);
}

// On the worker: the answer.
fn ::resume(u: Use.EntryCreate, cx) { rest::json(cx, 201, rest::answer<entries::Entry>(cx)); }

fn ordered(started: i64, stopped: i64) -> Error {
    return if stopped < started { Error.EndsBeforeStart } else { Error.None };
}
