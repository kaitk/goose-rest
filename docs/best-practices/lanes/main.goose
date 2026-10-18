// docs/best-practices/lanes.md: a lane for each kind of slow work. The writer
// owns the entries and the sessions, the hasher checks passwords, and the
// reports run on a reader of their own behind a small box, so that they are
// refused first. One worker, as in the section's other programs. A placement
// file, given with --place or GOOSE_PLACE, may put each lane on cores of its
// own; without one, every thread floats.
//
//   goose build -o build/lanes docs/best-practices/lanes/main.goose
//   build/lanes 8080
//   curl -s -d 'project=1&started=1767250800&stopped=1767254400' localhost:8080/entries
//   curl -s localhost:8080/reports/projects/1
//   curl -s -d 'email=ada@example.com&password=goose' localhost:8080/auth/session
import std;
import os;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
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
thread_fn writer(box: http::Box, at: http::Seat) {
    // First, before the thread touches memory of its own.
    http::take_seat(at);
    var all: entries::Entry[>..] = [];
    var sessions: auth::Session[>..] = [];
    // Each job in the box, in order, told apart by its tag, until main stops
    // the box.
    rest::lane(box) { tag, bytes =>
        if tag == CREATE_ENTRY {
            // The job, and where reply_value sends the reply.
            let a, ok = rest::asked<entries::CreateJob>(bytes);
            if ok { rest::reply_value(a, entries::create_entry(all, a.job)); }
        } else if tag == OPEN_SESSION {
            let a, ok = rest::asked<auth::OpenJob>(bytes);
            if ok { rest::reply_value(a, auth::open_session(sessions, a.job)); }
        }
    };
}

// A thread of the reports lane: a reader that runs only reports, so that a
// slow report holds it, not the writer.
thread_fn reports(box: http::Box, at: http::Seat) {
    http::take_seat(at);
    rest::lane(box) { tag, bytes =>
        if tag == TOTAL_ENTRIES {
            let a, ok = rest::asked<reports::TotalsJob>(bytes);
            // A report whose client has gone isn't run.
            if ok && rest::still_wanted(a) { rest::reply_value(a, reports::total_entries(a.job)); }
        }
    };
}

// A thread of the hasher lane: password checks, work that takes CPU, not
// waiting, so that it holds up neither the worker's connections nor the writer.
thread_fn hasher(box: http::Box, at: http::Seat) {
    http::take_seat(at);
    rest::lane(box) { tag, bytes =>
        if tag == VERIFY_PASSWORD {
            // The job, and where reply_value sends the reply.
            let a, ok = rest::asked<auth::SignInJob>(bytes);
            if ok { rest::reply_value(a, auth::verify_password(a.job)); }
        }
    };
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
    let place = http::place_load();
    // The code bounds each lane, and a placement file chooses within the
    // bounds. One writer, which needs nothing written: max is threads unless
    // written. Reports may grow to 4 threads, and the hasher to 2. Each
    // lane_open spawns its lane's threads.
    let app = App {
        writer: rest::lane_open(place, rest::LaneConfig { role: "writer", slots: WRITER_SLOTS, .. }, writer),
        reports: rest::lane_open(place, rest::LaneConfig { role: "reports", max: 4, slots: REPORTS_SLOTS, .. }, reports),
        hasher: rest::lane_open(place, rest::LaneConfig { role: "hasher", max: 2, slots: HASHER_SLOTS, .. }, hasher),
    };
    let cfg = http::Config { port: port as i32, workers: 1, place: http::place_ref(place), mail_slots: 64, max_waiting: 1024, .. };
    http::run(cfg, app, worker);
    // A flag in each box, not a message: a full box can't refuse it. Each
    // lane_stop waits for its lane's threads.
    rest::lane_stop(app.writer);
    rest::lane_stop(app.reports);
    rest::lane_stop(app.hasher);
}
