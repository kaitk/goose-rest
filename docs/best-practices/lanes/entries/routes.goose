// The entries' routes, under /entries, each route's flow in the order it
// runs: the route, its job's run on a lane, its resume.
namespace entries;

import std;
import os;
import http;
import rest;
import entries.structs;
import entries.errors;
import entries.rules;

fn routes(cx) {
    rest::post(cx, "") { create(cx); };
}

// Creating an entry. On the worker: read the form, and ask the writer lane.
fn create(cx) {
    let project, has_project = rest::form_int(cx, "project");
    rest::require(cx, "project", has_project);
    let started, has_started = rest::form_int(cx, "started");
    rest::require(cx, "started", has_started);
    let stopped, has_stopped = rest::form_int(cx, "stopped");
    rest::require(cx, "stopped", has_stopped);
    let input = CreateInput { project: project, started: started, stopped: stopped };
    // Returns at once; at the reply, the worker calls resume(u: Writes.EntryCreate, cx).
    rest::ask(cx, cx.app.writer, Writes.EntryCreate { input: input });
}

// On the writer lane: the rule decides, at the time the job runs, and a
// refusal, such as 422 entry_in_future, fails the route from here. The
// writer's entries stand in for the entries table. Writes is the program's,
// so run is global, and names the domain's own as entries::.
fn ::run(u: Writes.EntryCreate, w: Writer&, a) {
    let e, err = entries::new_entry(u.input, w.entries.len + 1, time() as i64);
    entries::check(err, a);
    w.entries.push(e);
    rest::reply_value(a, e);
}

// On the worker: the answer.
fn ::resume(u: Writes.EntryCreate, cx) { rest::json(cx, 201, rest::answer<entries::Entry>(cx)); }
