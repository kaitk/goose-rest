// The entries: the route, its job on the writer lane, and its resume.
namespace entries;

import std;
import plod;

struct Entry { id: i64 = 0, project: i64 = 0, started: i64 = 0, stopped: i64 = 0 }

enum Error { None, EndsBeforeStart }

// Fails with e's status and code, in a route or on a lane: x is a route's cx
// or a lane's job.
fn check(e: Error.None, x) {}
fn check(e: Error.EndsBeforeStart, x) { plod::fail(x, 422, "entry_ends_before_start"); }

fn format(out: u8[>..]&, e: const Entry&) {
    format(out, "{\"id\":", e.id, ",\"project\":", e.project, ",\"started\":", e.started,
           ",\"stopped\":", e.stopped, "}");
}

fn routes(cx) {
    if plod::on(cx, "POST", "") { create(cx); } else { plod::otherwise(cx); }
}

// On the worker: ask the writer lane.
fn create(cx) {
    let project, has_project = plod::query_int(cx, "project");
    plod::require(cx, "project", has_project);
    let started, has_started = plod::query_int(cx, "started");
    plod::require(cx, "started", has_started);
    let stopped, has_stopped = plod::query_int(cx, "stopped");
    plod::require(cx, "stopped", has_stopped);
    plod::ask(cx, cx.app.writer, Writes.EntryCreate { project: project, started: started, stopped: stopped });
}

// On the writer lane: the rule, which fails the route from here.
fn ::run(u: Writes.EntryCreate, w: Writer&, a) {
    entries::check(entries::ordered(u.started, u.stopped), a);
    let e = entries::Entry { id: w.entries.len + 1, project: u.project, started: u.started, stopped: u.stopped };
    w.entries.push(e);
    plod::reply_value(a, e);
}

// On the worker: the answer.
fn ::resume(u: Writes.EntryCreate, cx) { plod::json(cx, 201, plod::answer<entries::Entry>(cx)); }

fn ordered(started: i64, stopped: i64) -> Error {
    return if stopped < started { Error.EndsBeforeStart } else { Error.None };
}
