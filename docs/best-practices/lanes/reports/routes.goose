// The reports' routes, under /reports, read only, each route's flow in the
// order it runs: the route, its job, its resume.
namespace reports;

import std;
import os;
import http;
import rest;
import entries.structs;
import reports.structs;
import reports.rules;

fn routes(cx) {
    if rest::on(cx, "GET", "/projects/:id") {
        project(cx);
    } else {
        rest::otherwise(cx);
    }
}

// A project's totals. On the worker: ask the reports lane.
fn project(cx) {
    let ms, has_ms = rest::query_int(cx, "ms");
    let job = TotalsJob { project: rest::param_int(cx, "id"), ms: if has_ms { ms } else { 0 } };
    // Returns at once; at the reply, the worker calls resume(Waiting.ReportTotals).
    rest::ask(cx, cx.app.reports, TOTAL_ENTRIES, job, Waiting.ReportTotals);
}

// The rows a reader's query of the entries table returns, in place of a
// database.
let ENTRIES = [
    entries::Entry { id: 1, project: 1, started: 1767250800, stopped: 1767254400 },
    entries::Entry { id: 2, project: 1, started: 1767258000, stopped: 1767265200 },
    entries::Entry { id: 3, project: 2, started: 1767268800, stopped: 1767270600 },
];

// On the reports lane: the query, then the rule that sums.
fn total_entries(j: TotalsJob) -> Totals {
    if j.ms > 0 { sleep_ms(j.ms); }
    return totals(ENTRIES, j.project);
}

fn ::resume(w: Waiting.ReportTotals, cx) { reports::resume(w, cx); }

// On the worker: the answer.
fn resume(w: Waiting.ReportTotals, cx) {
    let t, ok = rest::read_reply<Totals>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 200, t);
}
