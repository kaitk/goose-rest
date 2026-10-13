// Spike 06: a route asks another thread over goose-http's mailbox, keeps
// what it needs in a fixed-mode Waiting enum in the per-request state, and
// resumes through one case function per variant. See README.md.
//
// app::handle is a handler as http::serve takes it (server.goose serves it).
// Here main plays the loop's part, so that the output is fixed: it hands each
// request to handle, takes the worker's box, and calls handle with WAKE for
// the exchange a message is addressed to, as the loops' delivered does.
import std;
import http from "github.com/kaitk/goose-http@cfb9c02bd8cd1d841eaf9d140ff0dbd96bb3bcf8";
import app;

// A request, through to its whole response, which it prints without CRs.
fn exchange(box: http::Box, key: u64, text: const u8[:]) {
    let r, s = http::parse(text);
    assert(s == 200);
    var out: u8[>..] = [];
    var keep = r.keep_alive;
    var stream = http::Stream { later: http::address(box, key), .. };
    var st = app::St { .. };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: r.minor, head: false, stream: stream };
    app::handle(http::Event { kind: http::REQUEST, req: r, data: "", whole: true, trailers: "" }, st, reply);
    var wakes = 0;
    while stream.waiting {
        assert(http::mail_wait(box, 5000));
        http::mail_take(box) { k, tag, bytes =>
            if stream.waiting && k == key {
                stream.waiting = false;
                wakes++;
                app::handle(http::Event { kind: http::WAKE, req: r, data: bytes, whole: false, trailers: "",
                                          tag: tag }, st, reply);
            }
        };
    }
    var shown: u8[>..] = [];
    for c in out { if c != '\r' { shown.push(c); } }
    print("-- ", http::path_of(r.target), ": ", wakes, " wake(s), state ", st.waiting, "\n", shown);
}

fn main() {
    let worker, e1 = http::mail_open(app::SLOTS, app::SLOT_SIZE);
    let box, e2 = http::mail_open(16, 256);
    assert(e1 == 0 && e2 == 0);
    app::db = http::address(box, 0);
    let id = thread_spawn(app::database, box);
    exchange(worker, 1, "GET /report?org=3&from=1&to=10 HTTP/1.1\r\nHost: x\r\n\r\n");
    exchange(worker, 2, "GET /export?org=7&rows=24 HTTP/1.1\r\nHost: x\r\n\r\n");
    exchange(worker, 3, "GET /nothing HTTP/1.1\r\nHost: x\r\n\r\n");
    http::mail_send(app::db, app::STOP, "");
    thread_wait(id);
    http::mail_close(worker);
}
