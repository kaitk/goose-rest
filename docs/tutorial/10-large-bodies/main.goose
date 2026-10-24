// docs/tutorial/10-large-bodies.md: a CSV import of a project's tasks,
// gathered whole up to a limit of its own, and the checks before it, which
// answer without reading the body. One worker: the tasks live in the worker.
//
//   goose build -o build/import docs/tutorial/10-large-bodies/main.goose
//   build/import 8080
//   printf 'Write the docs,ada\nShip it,grace\n' |
//       curl -s -H 'Content-Type: text/csv' --data-binary @- localhost:8080/v1/projects/1/tasks/import
import std;
import os;
import csv;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../../";

// The most bytes an import takes: past the 8 KB read buffer, and below the
// server's 1 MB, so the route's limit is the one that applies.
let IMPORT_LIMIT: i64 = 256 * 1024;

let PROJECTS = 2;

struct Task { project: i64, title: u8[..128], assignee: u8[..32] }

struct App { tasks: Task[>..]& }

struct Imported { project: i64, imported: i64 }

fn format(out: u8[>..]&, i: const Imported&) { plod::format_fields(out, i); }

struct Count { project: i64, tasks: i64 }

fn format(out: u8[>..]&, c: const Count&) { plod::format_fields(out, c); }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::post(cx, "/v1/projects/:id/tasks/import") { import_tasks(cx, project(cx)); };
        plod::get(cx, "/v1/projects/:id/tasks") { count_tasks(cx, project(cx)); };
    };
}

fn project(cx) -> i64 {
    let id = plod::param_int(cx, "id");
    guard id >= 1 && id <= PROJECTS else { plod::fail(cx, 404, "project_not_found"); }
    return id;
}

fn count_tasks(cx, project: i64) {
    var n = 0;
    for t in cx.app.tasks { if t.project == project { n++; } }
    plod::json(cx, 200, Count { project: project, tasks: n });
}

// Each record is title,assignee. The whole body is checked before any task
// is added, so a bad record adds none.
fn import_tasks(cx, project: i64) {
    let kind, has_kind = plod::header(cx, "Content-Type");
    guard has_kind && starts_with(kind, "text/csv") else { plod::fail(cx, 415, "unsupported_media_type"); }
    // Leaves the route until the body is whole; the lines above then run again.
    let text = plod::body(cx, IMPORT_LIMIT);
    var good = true;
    let ok = csv::each_record(text) { f =>
        if f.len != 2 || f[0].len < 1 || f[0].len > 128 || f[1].len > 32 { good = false; }
    };
    guard ok && good else { plod::fail(cx, 400, "invalid_csv"); }
    var n = 0;
    csv::each_record(text) { f =>
        cx.app.tasks.push(Task { project: project, title: f[0], assignee: f[1] });
        n++;
    };
    plod::json(cx, 201, Imported { project: project, imported: n });
}

thread_fn worker(cfg: http::Config) {
    var tasks: Task[>..] = [];
    var app = App { tasks: tasks };
    let e = plod::serve(cfg, app) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, workers: 1, .. };
    // The most bytes each worker gathers at once: 15 imports at the limit,
    // with their heads, where the default, 64 MB, would take 255.
    http::gather_budget(16 * IMPORT_LIMIT);
    http::run(cfg, worker);
}
