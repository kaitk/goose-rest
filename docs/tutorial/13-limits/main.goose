// docs/tutorial/13-limits.md: the limits of work that waits. A route that
// waits too long gets 504, a full box 503, and the database skips the work
// of a client that has gone. A report that takes longer than a client should
// wait runs as a background task, which the client polls.
//
//   goose build -o build/limits docs/tutorial/13-limits/main.goose
//   build/limits 8080
//   curl -s 'localhost:8080/v1/projects/1/summary?ms=500'
//   curl -s -X POST localhost:8080/v1/projects/1/reports
//   curl -s localhost:8080/v1/reports/1
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../../";
import db from "../db/";

let DELAY_MS: i64 = 20;

// The longest a route waits for the database, in milliseconds.
let WAIT_MS: i64 = 200;

// A report takes STEPS steps of STEP_MS each: half a second here, minutes
// in a real one.
let STEPS: i64 = 10;
let STEP_MS: i32 = 50;

// A job's tag.
let SUMMARY: i32 = 1;
let GONE: i32 = 2;
let START: i32 = 3;
let STATUS: i32 = 4;
let STOP: i32 = 5;

// ms makes the database take that much longer, as a slow query would.
struct SummaryJob { project: i64, ms: i64 }
struct Summary { project: i64 = 0, tasks: i64 = 0 }

// The jobs the database did no work for, as their clients had gone before
// they started, and the answers it sent to a client that went during the job.
struct Gone { skipped: i64 = 0, dropped: i64 = 0 }
struct GoneJob { unused: bool = false }

struct StartJob { project: i64 }
struct StatusJob { id: i64 }

// A report's state, as GET /v1/reports/:id answers it.
struct Report { status: i32 = 200, code: u8[..32] = "", id: i64 = 0, project: i64 = 0, left: i64 = STEPS, tasks: i64 = 0 }

fn format(out: u8[>..]&, s: const Summary&) { rest::format_fields(out, s); }

fn format(out: u8[>..]&, g: const Gone&) { rest::format_fields(out, g); }

fn format(out: u8[>..]&, r: const Report&) {
    format(out, "{\"id\":", r.id, ",\"project\":", r.project, ",\"state\":");
    if r.left > 0 {
        out.append("\"running\"}");
    } else {
        format(out, "\"done\",\"tasks\":", r.tasks, "}");
    }
}

enum Waiting { None, Summary, Gone, Started, Report }

struct St { waiting: Waiting = Waiting.None }

struct App { db: http::MailAddress, reports: http::MailAddress }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/v1") {
            rest::route(cx) { v1(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn v1(cx) {
    if rest::on(cx, "GET", "/projects/:id/summary") {
        let ms, has_ms = rest::query_int(cx, "ms");
        let job = SummaryJob { project: rest::param_int(cx, "id"), ms: if has_ms { ms } else { 0 } };
        rest::ask(cx, cx.app.db, SUMMARY, job, Waiting.Summary, WAIT_MS);
    } else if rest::on(cx, "GET", "/gone") {
        rest::ask(cx, cx.app.db, GONE, GoneJob { .. }, Waiting.Gone, WAIT_MS);
    } else if rest::on(cx, "POST", "/projects/:id/reports") {
        rest::ask(cx, cx.app.reports, START, StartJob { project: rest::param_int(cx, "id") }, Waiting.Started);
    } else if rest::on(cx, "GET", "/reports/:id") {
        rest::ask(cx, cx.app.reports, STATUS, StatusJob { id: rest::param_int(cx, "id") }, Waiting.Report);
    } else {
        rest::otherwise(cx);
    }
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Summary, cx) {
    let s, ok = rest::read_reply<Summary>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 200, s);
}

fn resume(w: Waiting.Gone, cx) {
    let g, ok = rest::read_reply<Gone>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 200, g);
}

// The report has started: 202, and where to ask about it.
fn resume(w: Waiting.Started, cx) {
    let r, ok = rest::read_reply<Report>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    var body: u8[>..] = [];
    format(body, r);
    http::start(cx.out, 202);
    http::field(cx.out, "Location", str("/v1/reports/", r.id));
    http::finish(cx.out, http::JSON, body);
}

fn resume(w: Waiting.Report, cx) {
    let r, ok = rest::read_reply<Report>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 200, r);
}

thread_fn database(box: http::Box) {
    var c = db::open(DELAY_MS);
    var gone = Gone { .. };
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == SUMMARY {
                let a, ok = rest::asked<SummaryJob>(bytes);
                if ok && !rest::still_wanted(a) {
                    gone.skipped++;
                } else if ok {
                    if a.job.ms > 0 { sleep_ms(a.job.ms); }
                    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [a.job.project]);
                    // False once the client has gone, as after its 504.
                    if !rest::reply_value(a, Summary { project: a.job.project, tasks: ts.len }) { gone.dropped++; }
                }
            } else if tag == GONE {
                let a, ok = rest::asked<GoneJob>(bytes);
                if ok { rest::reply_value(a, gone); }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

// The reports' thread: it takes a step of the report running between its
// messages, so that it replies to a client's question while a report runs.
thread_fn reports(box: http::Box) {
    var c = db::open(DELAY_MS);
    var all: Report[>..] = [];
    var running = true;
    while running {
        var busy = false;
        for r in all { if r.left > 0 { busy = true; } }
        http::mail_wait(box, if busy { STEP_MS } else { 1000 });
        http::mail_take(box) { key, tag, bytes =>
            if tag == START {
                let a, ok = rest::asked<StartJob>(bytes);
                if ok {
                    let r .= all.push(Report { id: all.len + 1, project: a.job.project, .. });
                    rest::reply_value(a, r);
                }
            } else if tag == STATUS {
                let a, ok = rest::asked<StatusJob>(bytes);
                if ok && a.job.id >= 1 && a.job.id <= all.len {
                    rest::reply_value(a, all[a.job.id - 1]);
                } else if ok {
                    rest::reply_value(a, Report { status: 404, code: "report_not_found", .. });
                }
            } else if tag == STOP {
                running = false;
            }
        };
        for &r in all {
            if r.left > 0 {
                r.left--;
                if r.left == 0 {
                    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [r.project]);
                    r.tasks = ts.len;
                }
                break;
            }
        }
    }
    http::mail_close(box);
}

thread_fn worker(cfg: http::Config, app: App) {
    var a = app;
    let e = rest::serve(cfg, a, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::route(cx) { resume(cx.state.waiting, cx); };
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
    http::exit_on_error(http::stop_on_signals());
    // Two slots, the fewest a box has: two jobs waiting behind the one the
    // database works on fill it.
    let dbox, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    let rbox, e2 = http::mail_open(16, 256);
    http::exit_on_error(e2);
    let app = App { db: http::address(dbox, 0), reports: http::address(rbox, 0) };
    let dt = thread_spawn(database, dbox);
    let rt = thread_spawn(reports, rbox);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, app));
    http::mail_send(app.db, STOP, "");
    http::mail_send(app.reports, STOP, "");
    thread_wait(dt);
    thread_wait(rt);
}
