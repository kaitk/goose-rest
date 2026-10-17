// docs/best-practices/testing.md: an application with its tests. app.goose
// declares the program's types and routes, which the tests under test/ import
// as a package; this file starts the writer lane and the worker, which only a
// scenario over HTTP runs. test/run_tests.py runs both kinds:
//
//   python3 docs/best-practices/testing/test/run_tests.py
//   goose build -o build/testing docs/best-practices/testing/main.goose
//   build/testing 8080
//   curl -s -d 'project=1&started=1767250800&stopped=1767254400' localhost:8080/entries
import std;
import os;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../../";
import .app;

// A write takes a millisecond or so: 64 queued wait under a tenth of a second.
let WRITER_SLOTS: i32 = 64;

// The writer lane, one thread: it owns the entries, and runs every job that
// writes, one at a time.
thread_fn writer(box: http::Box) {
    var all: entries::Entry[>..] = [];
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == CREATE_ENTRY {
                let a, ok = rest::asked<entries::CreateJob>(bytes);
                if ok { rest::reply_value(a, entries::create_entry(all, a.job)); }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

thread_fn worker(cfg: http::Config, writer: http::MailAddress) {
    var projects: projects::Project[>..] = [];
    var app = App { projects: projects, writer: writer };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
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
    let box, e = http::mail_open(WRITER_SLOTS, 256);
    http::exit_on_error(e);
    let to = http::address(box, 0);
    let wt = thread_spawn(writer, box);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, to));
    http::mail_send(to, STOP, "");
    thread_wait(wt);
}
