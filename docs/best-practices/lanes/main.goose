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
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../../";
import .app;

// A box holds the jobs its lane finishes within a route's time limit, 5
// seconds by default, in a power of two of at least 2 slots.
// A write takes a millisecond or so: 64 queued wait under a tenth of a second.
let WRITER_SLOTS: i32 = 64;
// A report can take a second or more, and it's the work to refuse first.
let REPORTS_SLOTS: i32 = 2;
// A password hash takes about 50 ms: 16 queued wait under a second.
let HASHER_SLOTS: i32 = 16;

// The writer lane, one thread: the database's one writer. It owns the entries
// and the sessions, and runs every job that writes, one at a time.
thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
    var all: entries::Entry[>..] = [];
    var sessions: auth::Session[>..] = [];
    var w = Writer { entries: all, sessions: sessions };
    // Each job in the box, in order, to its run case function, until main
    // stops the lane.
    rest::lane(box, jobs) { u, a => run(u, w, a); };
}

// A thread of the reports lane: a reader that runs only reports, so that a
// slow report holds it, not the writer.
thread_fn reports(box: http::Box, jobs: rest::Jobs<Reports>) {
    var r = Reader { entries: reports::ENTRIES };
    rest::lane(box, jobs) { u, a => run(u, r, a); };
}

// A thread of the hasher lane: password checks, work that takes CPU, not
// waiting, so that it holds up neither the worker's connections nor the writer.
thread_fn hasher(box: http::Box, jobs: rest::Jobs<Hashes>) {
    var h = Hasher { users: auth::USERS };
    rest::lane(box, jobs) { u, a => run(u, h, a); };
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
    // Each lane_open spawns its lane's threads: one writer, the database's
    // only one; one reader for reports; and two hashers, so that one sign-in
    // doesn't wait behind another's hash. Each names its jobs' enum and the
    // mark a route waiting on it holds.
    let app = App {
        writer: rest::lane_open<Writes>(http::LaneConfig { slots: WRITER_SLOTS, .. }, Use.Write, writer),
        reports: rest::lane_open<Reports>(http::LaneConfig { slots: REPORTS_SLOTS, .. }, Use.Report, reports),
        hasher: rest::lane_open<Hashes>(http::LaneConfig { threads: 2, slots: HASHER_SLOTS, .. }, Use.Hash, hasher),
    };
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    http::run(cfg, app, worker);
    // A flag in each box, not a message: a full box can't refuse it. Each
    // lane_stop waits for its lane's threads.
    rest::lane_stop(app.writer);
    rest::lane_stop(app.reports);
    rest::lane_stop(app.hasher);
}
