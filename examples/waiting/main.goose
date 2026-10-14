// Routes that wait on another thread: a "database" thread answers a report
// and an export, and each route resumes through its case function when the
// reply comes. The worker's reply messages are 64 bytes, so that an export
// comes back in pieces, which rest::relay sends on as a chunked response.
//
//   goose build -o build/examples/waiting examples/waiting/main.goose
//   build/examples/waiting 8080
//   curl -s 'localhost:8080/v1/report?org=3&from=1&to=10'
//   curl -s 'localhost:8080/v1/export?org=7&rows=50'
import std;
import os;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../../";

// A job's tag.
let REPORT: i32 = 1;
let EXPORT: i32 = 2;
let STOP: i32 = 3;

struct ReportJob { org: i64, from: i64, to: i64 }
struct ReportReply { days: i64, total: i64 }
struct ExportJob { org: i64, rows: i64 }

// What each waiting route needs when its reply comes. Fixed-mode: each
// request overwrites it (spec §3.5).
enum Waiting {
    None,
    Report { org: i64, from: i64, to: i64 },
    Export,
}

// The per-request state: rest::ask keeps the route's Waiting here.
struct St { waiting: Waiting = Waiting.None }

// The worker's state: where the database thread takes jobs.
struct App { db: http::MailAddress }

fn handle(cx) {
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            if rest::on(cx, "GET", "/health") {
                rest::text(cx, 200, "ok");
            } else if rest::scope(cx, "/v1") {
                rest::route(cx) { ask(cx); };
            } else {
                rest::otherwise(cx);
            }
        };
    };
}

fn ask(cx) {
    if rest::on(cx, "GET", "/report") {
        let org = need_int(cx, "org");
        let from = need_int(cx, "from");
        let to = need_int(cx, "to");
        if to < from { rest::fail_param(cx, "to: minimum"); }
        rest::ask(cx, cx.app.db, REPORT, ReportJob { org: org, from: from, to: to },
                  Waiting.Report { org: org, from: from, to: to });
    } else if rest::on(cx, "GET", "/export") {
        let rows = need_int(cx, "rows");
        if rows < 0 || rows > 10000 { rest::fail_param(cx, "rows: maximum"); }
        rest::ask(cx, cx.app.db, EXPORT, ExportJob { org: need_int(cx, "org"), rows: rows }, Waiting.Export);
    } else {
        rest::otherwise(cx);
    }
}

// The query parameter name as an integer, which the request must have.
fn need_int(cx, name: const u8[:]) -> i64 {
    let v, found = rest::query_int(cx, name);
    rest::require(cx, name, found);
    return v;
}

// The case functions, one per Waiting variant, when the reply comes.
fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Report, cx) {
    let rep, ok = rest::reply_value<ReportReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    var body: u8[>..] = [];
    format(body, "{\"org\":", w.org, ",\"from\":", w.from, ",\"to\":", w.to, ",\"days\":", rep.days,
           ",\"total\":", rep.total, "}");
    http::respond(cx.out, 200, "application/json", body);
}

fn resume(w: Waiting.Export, cx) { rest::relay(cx, 200, "application/json"); }

// The database thread: it takes jobs from its box until STOP.
thread_fn database(box: http::Box) {
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == REPORT {
                let a, ok = rest::asked<ReportJob>(bytes);
                if ok {
                    var total = 0;
                    for d in a.job.from..a.job.to + 1 { total += a.job.org * d; }
                    rest::answer_value(a, ReportReply { days: a.job.to - a.job.from + 1, total: total });
                }
            } else if tag == EXPORT {
                let a, ok = rest::asked<ExportJob>(bytes);
                if ok {
                    // [[org, row, row²], ...], larger than a reply message.
                    var text: u8[>..] = [];
                    text.push('[');
                    for i in a.job.rows {
                        if i > 0 { text.push(','); }
                        format(text, "[", a.job.org, ",", i, ",", i * i, "]");
                    }
                    text.push(']');
                    rest::answer(a, text);
                }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

thread_fn worker(cfg: http::Config, db: http::MailAddress) {
    var app = App { db: db };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::woken(cx) {
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
    let box, e = http::mail_open(64, 256);
    http::exit_on_error(e);
    let db = http::address(box, 0);
    let dbt = thread_spawn(database, box);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 4, mail_size: 64, max_waiting: 256, .. };
    thread_wait(thread_spawn(worker, cfg, db));
    http::mail_send(db, STOP, "");
    thread_wait(dbt);
}
