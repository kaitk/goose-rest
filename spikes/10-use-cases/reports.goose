// The reports: the route, its job on the reports lane, and its resume.
namespace reports;

import std;
import rest;
import .entries;

struct Totals { project: i64 = 0, entries: i64 = 0, seconds: i64 = 0 }

fn format(out: u8[>..]&, t: const Totals&) {
    format(out, "{\"project\":", t.project, ",\"entries\":", t.entries, ",\"seconds\":", t.seconds, "}");
}

// The rows a reader's query returns, in place of a database.
let ENTRIES = [
    entries::Entry { id: 1, project: 1, started: 1767250800, stopped: 1767254400 },
    entries::Entry { id: 2, project: 1, started: 1767258000, stopped: 1767265200 },
];

fn routes(cx) {
    if rest::on(cx, "GET", "/projects/:id") { project(cx); } else { rest::otherwise(cx); }
}

fn project(cx) {
    rest::ask(cx, cx.app.reports, Use.ReportTotals { project: rest::param_int(cx, "id") });
}

// On the reports lane: a project without entries is a 404 from here.
fn ::run(u: Use.ReportTotals, db: Db&, a) {
    let t = reports::totals(reports::ENTRIES, u.project);
    if t.entries == 0 { rest::fail(a, 404, "no_such_project"); }
    rest::reply_value(a, t);
}

fn ::resume(u: Use.ReportTotals, cx) { rest::json(cx, 200, rest::answer<reports::Totals>(cx)); }

fn totals(all: const entries::Entry[:], project: i64) -> Totals {
    var t = Totals { project: project, .. };
    for e in all {
        if e.project == project {
            t.entries++;
            t.seconds += e.stopped - e.started;
        }
    }
    return t;
}
