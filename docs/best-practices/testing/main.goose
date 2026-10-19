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
import http from "github.com/kaitk/goose-http@v0.4.0";
import rest from "../../../";
import .app;

// A write takes a millisecond or so: 64 queued wait under a tenth of a second.
let WRITER_SLOTS: i32 = 64;

// The writer lane, one thread: it owns the entries, and runs every job that
// writes, one at a time.
thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
    var all: entries::Entry[>..] = [];
    var w = Writer { entries: all };
    rest::lane(box, jobs) { u, a => run(u, w, a); };
}

thread_fn worker(cfg: http::Config, lane: rest::Lane<Writes, Use>) {
    var projects: projects::Project[>..] = [];
    var app = App { projects: projects, writer: lane };
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
    http::exit_on_error(http::stop_on_signals());
    let lane = rest::lane_open<Writes>(http::LaneConfig { slots: WRITER_SLOTS, .. }, Use.Write, writer);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    http::run(cfg, lane, worker);
    rest::lane_stop(lane);
}
