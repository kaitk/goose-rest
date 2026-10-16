// What the tests of bodies read in pieces and responses sent in pieces
// share: the routes' waits and the case functions that resume them, which
// log what they saw, through rest::serve_one.
import std;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../";
import expect from "../";

enum Waiting { None, Upload, Export { rows: i64 }, Echo, Download }

struct St { waiting: Waiting = Waiting.None, size: i64 = 0, file: http::FileBody = http::FileBody { .. } }

// What the case function saw, in order: B and a piece's length, E, C.
struct App { log: u8[>..]& }

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

// A row at each MORE, up to w.rows, and then the end; row 2 of 99 fails.
fn resume(w: Waiting.Export, cx) {
    if cx.kind == http::MORE {
        cx.state.size++;
        format(cx.app.log, "M", cx.state.size, " ");
        if w.rows == 99 && cx.state.size == 2 { rest::fail(cx, 500, "broken"); }
        rest::send(cx, str("row", cx.state.size, "\n"));
        if cx.state.size == w.rows { rest::end(cx); }
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("C ");
    }
}

// Sends each piece of the body back as it comes.
fn resume(w: Waiting.Echo, cx) {
    if cx.kind == http::BODY {
        format(cx.app.log, "B", cx.body.len, " ");
        rest::send(cx, cx.body[..min(cx.body.len, 4)]);
    } else if cx.kind == http::END {
        cx.app.log.append("E ");
        rest::end(cx);
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("C ");
    }
}

fn resume(w: Waiting.Download, cx) {
    format(cx.app.log, if cx.kind == http::MORE { "M " } else if cx.kind == http::CLOSED { "C " } else { "? " });
    rest::send_file(cx, cx.state.file);
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
            rest::body_in_pieces(cx, limit, Waiting.Upload);
            if both == "after" { rest::body(cx); }
        }
    };
    return out, log;
}

// A response of rows rows, with a Content-Length of length, or chunked.
fn rows_of(text: const u8[:], rows: i64, length: i64 = -1) -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(text, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::begin(cx, 200, "text/csv", length, Waiting.Export { rows: rows });
        }
    };
    return out, log;
}
