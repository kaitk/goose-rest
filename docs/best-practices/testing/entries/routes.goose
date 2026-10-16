// The entries' routes, under /entries, each route's flow in the order it
// runs: the route, its job, its resume.
namespace entries;

import std;
import os;
import http;
import rest;
import entries.structs;
import entries.errors;
import entries.rules;

fn routes(cx) {
    if rest::on(cx, "POST", "") {
        create(cx);
    } else {
        rest::otherwise(cx);
    }
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
    // Returns at once; at the reply, the worker calls resume(Waiting.EntryCreate).
    rest::ask(cx, cx.app.writer, CREATE_ENTRY, CreateJob { input: input }, Waiting.EntryCreate);
}

// On the writer lane: the rule decides, at the time the job runs. all is the
// writer's stand-in for the entries table.
fn create_entry(all: Entry[>..]&, j: CreateJob) -> CreateReply {
    let e, err = new_entry(j.input, all.len + 1, time() as i64);
    if err == Error.None { all.push(e); }
    return CreateReply { entry: e, err: err };
}

// Waiting is the program's, so its case functions are global; each passes
// the wait on to its domain's.
fn ::resume(w: Waiting.EntryCreate, cx) { entries::resume(w, cx); }

// On the worker: the answer.
fn resume(w: Waiting.EntryCreate, cx) {
    // The writer's reply, read as the struct it sent; not one is a bug: 502.
    let r, ok = rest::read_reply<CreateReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    // A rule's refusal, such as 422 entry_in_future, ends the route here.
    check(r.err, cx);
    rest::json(cx, 201, r.entry);
}
