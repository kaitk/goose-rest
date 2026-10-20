// docs/tutorial/15-long-responses.md: a project's tasks exported as CSV,
// made and sent 500 rows at a time as the client takes them, and its files
// downloaded, with ranges and conditional requests, and its task count sent
// as Server-Sent Events over time. The files are in the directory FILES
// names, "files" by default, a folder per project. One worker: the tasks
// live in the worker.
//
//   goose build -o build/exports docs/tutorial/15-long-responses/main.goose
//   build/exports 8080
//   curl -s localhost:8080/v1/projects/1/tasks.csv
//   curl -s -r 0-99 localhost:8080/v1/projects/1/files/plans.txt
//   curl -N localhost:8080/v1/projects/1/progress
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.2";
import rest from "../../../";

let PROJECTS = 2;

// The rows of the export sent at each MORE: about 16 KB.
let ROWS_PER_PIECE = 500;

// How far apart the progress events are, in milliseconds.
let PROGRESS_MS = 100;

struct Task { id: i64, project: i64, title: u8[..64], assignee: u8[..32] }

// The worker state: the tasks, and where each project's files are.
struct App { tasks: Task[>..]&, files: const u8[:] }

// What each route that sends in pieces waits on, with what it needs at each
// call.
enum Use {
    None,
    Export { project: i64 },
    Download,
    Progress { project: i64 },
}

struct St {
    use: Use = Use.None,
    next: i64 = 0,                                // the export's next task
    file: http::FileBody = http::FileBody { .. }, // what's left of a download
    events: i64 = 0,                              // progress events sent
    left: i64 = 0,                                // and still to send, or -1 for no end
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "GET", "/v1/projects/:id/tasks.csv") {
            rest::route(cx) { export_tasks(cx, project(cx)); };
        } else if rest::on(cx, "GET", "/v1/projects/:id/files/*name") {
            rest::route(cx) { download(cx, project(cx)); };
        } else if rest::on(cx, "GET", "/v1/projects/:id/progress") {
            rest::route(cx) { progress(cx, project(cx)); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn project(cx) -> i64 {
    let id = rest::param_int(cx, "id");
    guard id >= 1 && id <= PROJECTS else { rest::fail(cx, 404, "project_not_found"); }
    return id;
}

// GET /v1/projects/:id/tasks.csv: the header now, and the rows as the
// client takes them.
fn export_tasks(cx, project: i64) {
    rest::begin(cx, 200, "text/csv; charset=utf-8", -1, Use.Export { project: project });
    rest::send(cx, "id,title,assignee\n");
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: the state holds nothing to release
    var piece: u8[>..] = [];
    cx.state.next = tasks_csv(piece, cx.app.tasks, u.project, cx.state.next, ROWS_PER_PIECE);
    rest::send(cx, piece);
    if cx.state.next < 0 { rest::end(cx); }
}

// Appends to out up to n of project's tasks from tasks[from], as CSV rows,
// and returns where the next piece starts, or -1 after the last task.
fn tasks_csv(out: u8[>..]&, tasks: const Task[:], project: i64, from: i64, n: i64) -> i64 {
    var at = from;
    var rows = 0;
    while at < tasks.len && rows < n {
        let t = tasks[at];
        if t.project == project {
            format(out, t.id, ",", t.title, ",", t.assignee, "\n");
            rows++;
        }
        at++;
    }
    return if at < tasks.len { at } else { -1 };
}

// GET /v1/projects/:id/files/*name: 200, 206 for a range, 304 for a
// matching If-None-Match, 416, and 404 file_not_found.
fn download(cx, project: i64) {
    var path: u8[>..] = [];
    guard http::file_path(str(cx.app.files, "/", project), rest::param(cx, "name"), path) else {
        rest::fail(cx, 400, "bad_path");
    }
    rest::file(cx, path, cx.state.file, Use.Download);
}

fn resume(u: Use.Download, cx) { rest::send_file(cx, cx.state.file); }

// GET /v1/projects/:id/progress?n=N: the project's task count as Server-Sent
// Events, PROGRESS_MS apart; N of them, or without N until the client goes.
fn progress(cx, project: i64) {
    let n, given = rest::query_int(cx, "n");
    guard !given || n > 0 else { rest::fail(cx, 400, "invalid_n"); }
    cx.state.left = if given { n } else { -1 };
    rest::begin(cx, 200, "text/event-stream", -1, Use.Progress { project: project });
    progress_event(cx, project);
}

fn resume(u: Use.Progress, cx) {
    guard cx.kind == http::TIMEOUT else { return; }   // CLOSED: the state holds nothing to release
    progress_event(cx, u.project);
}

// Sends the next event, then pauses until the one after, or ends after the
// last.
fn progress_event(cx, project: i64) {
    cx.state.events++;
    rest::send(cx, str("id: ", cx.state.events, "\ndata: {\"tasks\":", count(cx.app.tasks, project), "}\n\n"));
    if cx.state.left > 0 { cx.state.left--; }
    if cx.state.left == 0 { rest::end(cx); } else { rest::pause(cx, PROGRESS_MS); }
}

fn count(tasks: const Task[:], project: i64) -> i64 {
    var n = 0;
    for t in tasks { if t.project == project { n++; } }
    return n;
}

thread_fn worker(cfg: http::Config, files: u8[..200]) {
    // Project 1 has 2,000 tasks, and project 2 two.
    var tasks: Task[>..] = [];
    let people = ["ada", "grace", "linus"];
    for i in 2000 {
        tasks.push(Task { id: i + 1, project: 1, title: str("Task ", i + 1), assignee: people[i % 3] });
    }
    tasks.push(Task { id: 2001, project: 2, title: "Name it", assignee: "grace" });
    tasks.push(Task { id: 2002, project: 2, title: "Ship it", assignee: "ada" });
    var app = App { tasks: tasks, files: files };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::on_reply(cx) { resume(cx.state.use, cx); };
        } else {
            handle(cx);
        }
    };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    var files: u8[..200] = [];
    var dir: u8[>..] = [];
    if !env("FILES", dir) { dir.append("files"); }
    guard dir.len <= 200 else {
        write_stderr("FILES is too long\n");
        return;
    }
    files.append(dir);
    http::exit_on_error(http::stop_on_signals());
    // The progress events' pauses need a timer each: max_waiting of them,
    // which goose-http keeps with a box of mail_slots.
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    http::run(cfg, files, worker);
}
