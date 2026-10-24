// Spike 10: task 050's use cases, on docs/best-practices/lanes/'s program.
// One fixed-mode enum, Use, whose variant is the job a lane runs and what
// the route waits with; run case functions on the lanes, resume ones on the
// worker, each declared in its domain's file in the global namespace; and a
// job that fails replies its failure, which fails the route before its
// resume. proposal.goose holds the calls the package would take. README.md
// has the verdict.
//
// main plays goose-http's loop, as spikes 06 and 09 do, so that the output
// is fixed: each request goes through plod::on_event, the code plod::serve
// runs, and each reply message addressed to it comes back as a WAKE. The
// lanes are real threads, each with its box.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import .app;

// Every lane's thread: the same loop, as every lane takes the same Use.
thread_fn lane(box: http::Box) {
    var all: entries::Entry[>..] = [];
    var sessions: auth::Session[>..] = [];
    var db = Db { entries: all, sessions: sessions };
    spike10::lane<Use>(box) { u, a => run(u, db, a); };
}

fn serve_event(cx) {
    if plod::resumed(cx) {
        spike10::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        handle(cx);
    }
}

// One request through to its whole response, printed without CRs: REQUEST,
// then a WAKE for each reply message addressed to it, as the loops do.
fn exchange<H>(box: http::Box, key: u64, a: App&, text: const u8[:]) {
    let r, s = http::parse(text);
    assert(s == 200);
    var out: u8[>..] = [];
    var keep = r.keep_alive;
    var stream = http::Stream { later: http::address(box, key), .. };
    var st = plod::Slot<St> { state: St { .. } };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: r.minor, head: false, stream: stream };
    plod::on_event(http::Event { kind: http::REQUEST, req: r, data: "", whole: true, trailers: "" }, st, a, reply)
                   { cx => H(cx) };
    var wakes: u8[>..] = [];
    while stream.waiting {
        assert(http::mail_wait(box, 5000));
        http::mail_take(box) { k, tag, bytes =>
            if stream.waiting && k == key {
                stream.waiting = false;
                // The variant the route waits with, and whether the job failed.
                format(wakes, "\n  wake: ", st.state.use, if tag == spike10::JOB_FAILED { ", job failed" } else { "" });
                plod::on_event(http::Event { kind: http::WAKE, req: r, data: bytes, whole: false, trailers: "",
                                             tag: tag }, st, a, reply) { cx => H(cx) };
            }
        };
    }
    let body = find(out, "\r\n\r\n");
    let line = find(out, "\r\n");
    print("-- ", text[..find(text, " HTTP/")], wakes, "\n  ", out[9..line], " ", out[body + 4..]);
}

fn post(target: const u8[:]) -> u8[>..] { str("POST ", target, " HTTP/1.1\r\nHost: x\r\n\r\n") }
fn get(target: const u8[:]) -> u8[>..] { str("GET ", target, " HTTP/1.1\r\nHost: x\r\n\r\n") }

fn main() {
    let worker, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var a = App {
        writer: http::lane_open(http::LaneConfig { slots: 16, .. }, lane),
        reports: http::lane_open(http::LaneConfig { slots: 2, .. }, lane),
        hasher: http::lane_open(http::LaneConfig { threads: 2, slots: 16, .. }, lane),
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
    http::lane_stop(a.writer);
    http::lane_stop(a.reports);
    http::lane_stop(a.hasher);
    http::mail_close(worker);
}
