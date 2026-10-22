// The entries' routes, under /entries, each route's flow in the order it
// runs: the route, its job's run on a lane, its resume.
namespace entries;

import std;
import os;
import http;
import plod;
import entries.structs;
import entries.errors;
import entries.rules;

fn routes(cx) {
    plod::post(cx, "") { create(cx); };
}

// Creating an entry. On the worker: read the form, and ask the writer lane.
fn create(cx) {
    let project, has_project = plod::form_int(cx, "project");
    plod::require(cx, "project", has_project);
    let started, has_started = plod::form_int(cx, "started");
    plod::require(cx, "started", has_started);
    let stopped, has_stopped = plod::form_int(cx, "stopped");
    plod::require(cx, "stopped", has_stopped);
    let input = CreateInput { project: project, started: started, stopped: stopped };
    // Returns at once; at the reply, the worker calls resume(u: Writes.EntryCreate, cx).
    plod::ask(cx, cx.app.writer, Writes.EntryCreate { input: input });
}

// On the writer lane: the rule decides, at the time the job runs, and a
// refusal, such as 422 entry_in_future, fails the route from here. The
// writer's entries stand in for the entries table.
fn ::run(u: Writes.EntryCreate, w: Writer&, a) {
    let e, err = entries::new_entry(u.input, w.entries.len + 1, time() as i64);
    entries::check(err, a);
    w.entries.push(e);
    plod::reply_value(a, e);
}

// On the worker: the answer.
fn ::resume(u: Writes.EntryCreate, cx) { plod::json(cx, 201, plod::answer<entries::Entry>(cx)); }
