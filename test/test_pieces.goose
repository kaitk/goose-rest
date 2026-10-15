// Bodies read in pieces with rest::receive, through rest::serve_one: whole
// and in pieces, the limit, a failure or an answer before the END, a client
// that hangs up, and rest::body beside it. scripts/test-unit.sh runs this
// through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

enum Waiting { None, Upload }

struct St { waiting: Waiting = Waiting.None, size: i64 = 0 }

// What the case function saw, in order: B and a piece's length, E, C.
struct App { log: u8[>..]& }

fn same(got: const u8[:], want: const u8[:], what: const u8[:]) {
    if got != want {
        print(what, ":\ngot:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

// A POST whose body starts with start, then letters, n bytes in all, with a
// Content-Length of length, or n when length is negative.
fn post(start: const u8[:], n: i64, length: i64 = -1) -> u8[>..] {
    var text = str("POST /up HTTP/1.1\r\nHost: x\r\nContent-Length: ", if length < 0 { n } else { length }, "\r\n\r\n");
    text.append(start);
    for i in n - start.len { text.push('a' + (i % 26) as u8); }
    return text;
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// A piece that starts with "fail" fails the route, and one that starts with
// "stop" answers it.
fn resume(w: Waiting.Upload, cx) {
    if cx.kind == http::BODY {
        format(cx.app.log, "B", cx.body.len, " ");
        cx.state.size += cx.body.len;
        if starts_with(cx.body, "fail") { rest::fail(cx, 422, "refused"); }
        if starts_with(cx.body, "stop") { rest::text(cx, 200, "stopped"); }
    } else if cx.kind == http::END {
        cx.app.log.append("E ");
        rest::text(cx, 201, str(cx.state.size));
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("C ");
    }
}

// Receives with limit; "both" reads the body whole first, and "after" after.
fn upload(text: const u8[:], limit: i64 = 1 << 20, both: const u8[:] = "") -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(text, app, St { .. }, http::Config { max_body: 4 << 20, .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            if both == "first" { rest::body(cx); }
            rest::receive(cx, limit, Waiting.Upload);
            if both == "after" { rest::body(cx); }
        }
    };
    return out, log;
}

fn test_receive() {
    // A body that came with its head: one piece, then the END.
    let short, l1 = upload(post("", 100));
    same(body_of(short), "100", "whole");
    same(l1, "B100 E ", "whole's calls");
    // An empty body: the END alone.
    let empty, l2 = upload(post("", 0));
    same(body_of(empty), "0", "empty");
    same(l2, "E ", "empty's calls");
    // A longer one, a piece at a time.
    let long, l3 = upload(post("", 20000));
    same(body_of(long), "20000", "in pieces");
    same(l3, "B8192 B8192 B3616 E ", "in pieces' calls");
    // A Content-Length over the limit: 413 before any piece.
    let big, l4 = upload(post("", 20000), 10000);
    same(status_of(big), "HTTP/1.1 413 Content Too Large", "over the limit");
    same(body_of(big), "{\"error\":\"payload_too_large\"}", "over the limit's body");
    same(l4, "", "over the limit's calls");
}

fn test_ending_early() {
    // A failure at a piece answers in the error shape, then CLOSED, and no
    // more pieces.
    let failed, l1 = upload(post("fail", 20000));
    same(status_of(failed), "HTTP/1.1 422 Unprocessable Content", "failure");
    same(body_of(failed), "{\"error\":\"refused\"}", "failure's body");
    same(l1, "B8192 C ", "failure's calls");
    // The same for a body that came whole.
    let whole, l2 = upload(post("fail", 100));
    same(body_of(whole), "{\"error\":\"refused\"}", "whole failure");
    same(l2, "B100 C ", "whole failure's calls");
    // An answer before the END ends the read as a failure does.
    let stopped, l3 = upload(post("stop", 20000));
    same(body_of(stopped), "stopped", "answer");
    same(l3, "B8192 C ", "answer's calls");
    // A client that hangs up midway: the pieces that came, then CLOSED.
    let gone, l4 = upload(post("", 10000, 20000));
    same(l4, "B8192 B1808 C ", "hang-up's calls");
    same(status_of(gone), "HTTP/1.1 500 Internal Server Error", "hang-up");
}

fn test_body_beside() {
    let first, l1 = upload(post("", 100), 1 << 20, "first");
    same(body_of(first), "{\"error\":\"body_already_read\"}", "receive after body");
    same(l1, "", "receive after body's calls");
    let after, l2 = upload(post("", 100), 1 << 20, "after");
    same(body_of(after), "{\"error\":\"body_already_read\"}", "body after receive");
    // The route failed before any piece: CLOSED alone.
    same(l2, "C ", "body after receive's calls");
}

fn main() {
    test_receive();
    test_ending_early();
    test_body_beside();
    print("test_pieces: ok");
}
