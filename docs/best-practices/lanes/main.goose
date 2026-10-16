// docs/best-practices/lanes.md: a lane for each kind of slow work. The writer
// owns the entries and the sessions, the hasher checks passwords, and the
// reports run on a reader of their own behind a small box, so that they are
// refused first. One worker, as in the section's other programs.
//
//   goose build -o build/lanes docs/best-practices/lanes/main.goose
//   build/lanes 8080
//   curl -s -d 'project=1&started=1767250800&stopped=1767254400' localhost:8080/entries
//   curl -s localhost:8080/reports/projects/1
//   curl -s -d 'email=ada@example.com&password=goose' localhost:8080/auth/session
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../../";
import entries.routes;
import reports.routes;
import auth.routes;

// A box holds the jobs its lane finishes within a route's time limit, 5
// seconds by default, in a power of two of at least 2 slots.
// A write takes a millisecond or so: 64 queued wait under a tenth of a second.
let WRITER_SLOTS: i32 = 64;
// A report can take a second or more, and it's the work to refuse first.
let REPORTS_SLOTS: i32 = 2;
// A password hash takes about 50 ms: 16 queued wait under a second.
let HASHER_SLOTS: i32 = 16;

// A job's tag.
let CREATE_ENTRY: i32 = 1;
let TOTAL_ENTRIES: i32 = 2;
let VERIFY_PASSWORD: i32 = 3;
let OPEN_SESSION: i32 = 4;
let STOP: i32 = 5;

// The steps of every route that waits, a route's steps together and in the
// order they run.
enum Waiting {
    None,
    EntryCreate,               // entries::create
    ReportTotals,              // reports::project
    AuthPassword, AuthSession, // auth::sign_in
}

struct St { waiting: Waiting = Waiting.None }

// Where the routes send each lane its jobs.
struct App { writer: http::MailAddress, reports: http::MailAddress, hasher: http::MailAddress }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/auth") {
            rest::route(cx) { auth::routes(cx); };
        } else if rest::scope(cx, "/entries") {
            rest::route(cx) { entries::routes(cx); };
        } else if rest::scope(cx, "/reports") {
            rest::route(cx) { reports::routes(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The writer lane, one thread: the database's one writer. It owns the entries
// and the sessions, and runs every job that writes, one at a time.
thread_fn writer(box: http::Box) {
    var all: entries::Entry[>..] = [];
    var sessions: auth::Session[>..] = [];
    var running = true;
    while running {
        // Sleeps until a job comes, or a second passes.
        http::mail_wait(box, 1000);
        // Each job in the box, in order, told apart by its tag.
        http::mail_take(box) { key, tag, bytes =>
            if tag == CREATE_ENTRY {
                // The job, and where reply_value sends the reply.
                let a, ok = rest::asked<entries::CreateJob>(bytes);
                if ok { rest::reply_value(a, entries::create_entry(all, a.job)); }
            } else if tag == OPEN_SESSION {
                let a, ok = rest::asked<auth::OpenJob>(bytes);
                if ok { rest::reply_value(a, auth::open_session(sessions, a.job)); }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

// The reports lane, one thread: a reader that runs only reports, so that a
// slow report holds it, not the writer.
thread_fn reports(box: http::Box) {
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == TOTAL_ENTRIES {
                let a, ok = rest::asked<reports::TotalsJob>(bytes);
                // A report whose client has gone isn't run.
                if ok && rest::still_wanted(a) { rest::reply_value(a, reports::total_entries(a.job)); }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

// The hasher lane, one thread: password checks, work that takes CPU, not
// waiting, so that it holds up neither the worker's connections nor the writer.
thread_fn hasher(box: http::Box) {
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == VERIFY_PASSWORD {
                // The job, and where reply_value sends the reply.
                let a, ok = rest::asked<auth::SignInJob>(bytes);
                if ok { rest::reply_value(a, auth::verify_password(a.job)); }
            } else if tag == STOP {
                running = false;
            }
        };
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
    let wbox, e = http::mail_open(WRITER_SLOTS, 256);
    http::exit_on_error(e);
    let rbox, e2 = http::mail_open(REPORTS_SLOTS, 256);
    http::exit_on_error(e2);
    let hbox, e3 = http::mail_open(HASHER_SLOTS, 256);
    http::exit_on_error(e3);
    let app = App { writer: http::address(wbox, 0), reports: http::address(rbox, 0), hasher: http::address(hbox, 0) };
    let wt = thread_spawn(writer, wbox);
    let rt = thread_spawn(reports, rbox);
    let ht = thread_spawn(hasher, hbox);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, app));
    http::mail_send(app.writer, STOP, "");
    http::mail_send(app.reports, STOP, "");
    http::mail_send(app.hasher, STOP, "");
    thread_wait(wt);
    thread_wait(rt);
    thread_wait(ht);
}
