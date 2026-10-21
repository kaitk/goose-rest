// The reports' routes, under /reports, read only, each route's flow in the
// order it runs: the route, its job's run on a lane, its resume.
namespace reports;

import std;
import os;
import http;
import rest;
import entries.structs;
import reports.structs;
import reports.rules;

fn routes(cx) {
    rest::get(cx, "/projects/:id") { project(cx); };
}

// A project's totals. On the worker: ask the reports lane. ms makes the job
// take that much longer, as a long period would.
fn project(cx) {
    let ms, has_ms = rest::query_int(cx, "ms");
    // Returns at once; at the reply, the worker calls resume(u: Reports.ReportTotals, cx).
    rest::ask(cx, cx.app.reports, Reports.ReportTotals { project: rest::param_int(cx, "id"), ms: if has_ms { ms } else { 0 } });
}

// The rows a reader's query of the entries table returns, in place of a
// database.
let ENTRIES = [
    entries::Entry { id: 1, project: 1, started: 1767250800, stopped: 1767254400 },
    entries::Entry { id: 2, project: 1, started: 1767258000, stopped: 1767265200 },
    entries::Entry { id: 3, project: 2, started: 1767268800, stopped: 1767270600 },
];

// On the reports lane: the query, then the rule that sums. A report whose
// client has gone isn't run.
fn ::run(u: Reports.ReportTotals, r: Reader&, a) {
    guard rest::still_wanted(a) else { return; }
    if u.ms > 0 { sleep_ms(u.ms); }
    rest::reply_value(a, reports::totals(r.entries, u.project));
}

// On the worker: the answer.
fn ::resume(u: Reports.ReportTotals, cx) { rest::json(cx, 200, rest::answer<reports::Totals>(cx)); }
