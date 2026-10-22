// Spike 11: task 050's use cases with one enum per lane, on
// docs/best-practices/lanes/'s program, as spike 10 has them with one enum
// for the program. Each lane takes its own enum of jobs and its own state;
// a route waits with its lane's mark, and the lane's reply carries the job
// back, which the mark's resume dispatches on. The calls are the package's,
// waiting.goose, which took them from this spike's proposal.goose.
// README.md has the verdict.
//
// main plays goose-http's loop, as spikes 06, 09, and 10 do, so that the
// output is fixed: each request goes through rest::on_event, the code
// rest::serve runs, and each reply message addressed to it comes back as a
// WAKE. The lanes are real threads, each with its box.
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import .app;

// A thread for each lane, each with its own state and its own enum.
thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
    var all: entries::Entry[>..] = [];
    var sessions: auth::Session[>..] = [];
    var w = Writer { entries: all, sessions: sessions };
    rest::lane(box, jobs) { u, a => run(u, w, a); };
}

thread_fn reader(box: http::Box, jobs: rest::Jobs<Reports>) {
    var r = Reader { entries: reports::ENTRIES };
    rest::lane(box, jobs) { u, a => run(u, r, a); };
}

thread_fn hasher(box: http::Box, jobs: rest::Jobs<Hashes>) {
    var h = Hasher { users: auth::USERS };
    rest::lane(box, jobs) { u, a => run(u, h, a); };
}

fn serve_event(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        handle(cx);
    }
}

// The job a reply carries back, for the output: the reply is all the worker
// holds of it.
fn shown(u: Use.None, bytes: const u8[:]) -> u8[>..] { str("") }
fn shown(u: Use.Write, bytes: const u8[:]) -> u8[>..] { str(" ", rest::echoed<Writes>(bytes)) }
fn shown(u: Use.Report, bytes: const u8[:]) -> u8[>..] { str(" ", rest::echoed<Reports>(bytes)) }
fn shown(u: Use.Hash, bytes: const u8[:]) -> u8[>..] { str(" ", rest::echoed<Hashes>(bytes)) }

// One request through to its whole response, printed without CRs: REQUEST,
// then a WAKE for each reply message addressed to it, as the loops do; then
// the request state once the route has answered.
fn exchange<H>(box: http::Box, key: u64, a: App&, text: const u8[:]) {
    let r, s = http::parse(text);
    assert(s == 200);
    var out: u8[>..] = [];
    var keep = r.keep_alive;
    var stream = http::Stream { later: http::address(box, key), .. };
    var st = rest::Slot<St> { state: St { .. } };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: r.minor, head: false, stream: stream };
    rest::on_event(http::Event { kind: http::REQUEST, req: r, data: "", whole: true, trailers: "" }, st, a, reply)
                   { cx => H(cx) };
    var wakes: u8[>..] = [];
    while stream.waiting {
        assert(http::mail_wait(box, 5000));
        http::mail_take(box) { k, tag, bytes =>
            if stream.waiting && k == key {
                stream.waiting = false;
                // The mark the route waits with, and the job the reply
                // carries back, or that the job failed.
                format(wakes, "\n  wake: ", st.state.use,
                       if (tag & rest::REPLY_REFUSED) != 0 { str(", job failed") } else { shown(st.state.use, bytes) });
                rest::on_event(http::Event { kind: http::WAKE, req: r, data: bytes, whole: false, trailers: "",
                                             tag: tag }, st, a, reply) { cx => H(cx) };
            }
        };
    }
    let body = find(out, "\r\n\r\n");
    let line = find(out, "\r\n");
    print("-- ", text[..find(text, " HTTP/")], wakes, "\n  ", out[9..line], " ", out[body + 4..],
          "\n  then: ", st.state.use);
}

fn post(target: const u8[:]) -> u8[>..] { str("POST ", target, " HTTP/1.1\r\nHost: x\r\n\r\n") }
fn get(target: const u8[:]) -> u8[>..] { str("GET ", target, " HTTP/1.1\r\nHost: x\r\n\r\n") }

fn main() {
    let worker, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var a = App {
        writer: rest::lane_open<Writes>(http::LaneConfig { slots: 16, .. }, Use.Write, writer),
        reports: rest::lane_open<Reports>(http::LaneConfig { slots: 2, .. }, Use.Report, reader),
        hasher: rest::lane_open<Hashes>(http::LaneConfig { threads: 2, slots: 16, .. }, Use.Hash, hasher),
    };
    var key: u64 = 0;
    fn served(text: const u8[:]) {
        key++;
        exchange(worker, key, a, text) { cx => serve_event(cx) };
    }
    served(get("/health"));
    served(post("/entries?project=1&started=1767250800&stopped=1767254400"));
    served(post("/entries?project=1&started=1767254400&stopped=1767250800"));
    served(post("/entries?project=1"));
    served(get("/reports/projects/1"));
    served(get("/reports/projects/9"));
    served(post("/auth/session?email=ada@example.com&password=goose"));
    served(post("/auth/session?email=ada@example.com&password=gander"));
    served(post("/entries?project=2&started=1767268800&stopped=1767270600"));
    rest::lane_stop(a.writer);
    rest::lane_stop(a.reports);
    rest::lane_stop(a.hasher);
    http::mail_close(worker);
}
