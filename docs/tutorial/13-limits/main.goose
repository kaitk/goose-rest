// docs/tutorial/13-limits.md: the limits of work that waits. A route that
// waits too long gets 504, a full box 503, and the database skips the work
// of a client that has gone. A report that takes longer than a client should
// wait runs as a background task, which the client polls.
//
//   goose build -o build/limits docs/tutorial/13-limits/main.goose
//   build/limits 8080
//   curl -s 'localhost:8080/v1/projects/1/summary?ms=1000'
//   curl -s -X POST localhost:8080/v1/projects/1/reports
//   curl -s localhost:8080/v1/reports/1
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../../";
import db from "../db/";

let DELAY_MS: i64 = 20;

// The longest a route waits for the database, in milliseconds.
let WAIT_MS: i64 = 200;

// A report takes STEPS steps of STEP_MS each: half a second here, minutes
// in a real one.
let STEPS: i64 = 10;
let STEP_MS: i32 = 50;

// Each lane's jobs. Summary's ms makes the database take that much longer,
// as a slow query would.
enum DbJob {
    Summary { project: i64, ms: i64 },
    Gone,
}
enum ReportJob {
    Start { project: i64 },
    Status { id: i64 },
}

enum Use { None, Db, Reports }

struct St { use: Use = Use.None }

struct App { db: rest::Lane<DbJob, Use>, reports: rest::Lane<ReportJob, Use> }

struct Summary { project: i64 = 0, tasks: i64 = 0 }

// The jobs the database did no work for, as their clients had gone before
// they started, and the answers it sent to a client that went during the job.
struct Gone { skipped: i64 = 0, dropped: i64 = 0 }

// A report's state, as GET /v1/reports/:id answers it.
struct Report { id: i64 = 0, project: i64 = 0, left: i64 = STEPS, tasks: i64 = 0 }

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

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        rest::scope(cx, "/v1") { v1(cx); };
    };
}

fn v1(cx) {
    rest::get(cx, "/projects/:id/summary") {
        let ms, has_ms = rest::query_int(cx, "ms");
        let job = DbJob.Summary { project: rest::param_int(cx, "id"), ms: if has_ms { ms } else { 0 } };
        rest::ask(cx, cx.app.db, job, WAIT_MS);
    };
    rest::get(cx, "/gone") { rest::ask(cx, cx.app.db, DbJob.Gone, WAIT_MS); };
    rest::post(cx, "/projects/:id/reports") {
        rest::ask(cx, cx.app.reports, ReportJob.Start { project: rest::param_int(cx, "id") });
    };
    rest::get(cx, "/reports/:id") {
        rest::ask(cx, cx.app.reports, ReportJob.Status { id: rest::param_int(cx, "id") });
    };
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Db, cx) { resume(rest::job<DbJob>(cx), cx); }
fn resume(u: Use.Reports, cx) { resume(rest::job<ReportJob>(cx), cx); }

// On the database lane: a job whose client has gone isn't run.
fn run(u: DbJob.Summary, c: db::Conn&, gone: Gone&, a) {
    guard rest::still_wanted(a) else {
        gone.skipped++;
        return;
    }
    if u.ms > 0 { sleep_ms(u.ms); }
    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [u.project]);
    // False once the client has gone, as after its 504.
    if !rest::reply_value(a, Summary { project: u.project, tasks: ts.len }) { gone.dropped++; }
}

fn resume(u: DbJob.Summary, cx) { rest::json(cx, 200, rest::answer<Summary>(cx)); }

fn run(u: DbJob.Gone, c: db::Conn&, gone: Gone&, a) { rest::reply_value(a, gone); }

fn resume(u: DbJob.Gone, cx) { rest::json(cx, 200, rest::answer<Gone>(cx)); }

// On the reports lane: a report starts, and runs between the lane's jobs.
fn run(u: ReportJob.Start, all: Report[>..]&, a) {
    let r .= all.push(Report { id: all.len + 1, project: u.project, .. });
    rest::reply_value(a, r);
}

// The report has started: 202, and where to ask about it.
fn resume(u: ReportJob.Start, cx) {
    let r = rest::answer<Report>(cx);
    var body: u8[>..] = [];
    format(body, r);
    http::start(cx.out, 202);
    http::field(cx.out, "Location", str("/v1/reports/", r.id));
    http::finish(cx.out, http::JSON, body);
}

fn run(u: ReportJob.Status, all: Report[>..]&, a) {
    guard u.id >= 1 && u.id <= all.len else { rest::fail(a, 404, "report_not_found"); }
    rest::reply_value(a, all[u.id - 1]);
}

fn resume(u: ReportJob.Status, cx) { rest::json(cx, 200, rest::answer<Report>(cx)); }

thread_fn database(box: http::Box, jobs: rest::Jobs<DbJob>) {
    var c = db::open(DELAY_MS);
    var gone = Gone { .. };
    rest::lane(box, jobs) { u, a => run(u, c, gone, a); };
}

// The reports' thread: it takes a step of the report running between its
// messages, so that it replies to a client's question while a report runs.
// Its wait has a time limit while a report runs, so it writes the loop that
// rest::lane is, until the lane is stopped and its box empty.
thread_fn reports(box: http::Box, jobs: rest::Jobs<ReportJob>) {
    var c = db::open(DELAY_MS);
    var all: Report[>..] = [];
    while !http::mail_stopped(box) {
        var busy = false;
        for r in all { if r.left > 0 { busy = true; } }
        http::mail_wait(box, if busy { STEP_MS } else { 1000 });
        http::mail_take(box) { key, tag, bytes =>
            rest::lane_job(jobs, bytes) { u, a => run(u, all, a); };
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
    http::exit_on_error(http::stop_on_signals());
    // Two slots, the fewest a box has: two jobs waiting behind the one the
    // database works on fill it.
    let app = App {
        db: rest::lane_open<DbJob>(http::LaneConfig { slots: 2, .. }, Use.Db, database),
        reports: rest::lane_open<ReportJob>(http::LaneConfig { slots: 16, .. }, Use.Reports, reports),
    };
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    http::run(cfg, app, worker);
    rest::lane_stop(app.db);
    rest::lane_stop(app.reports);
}
