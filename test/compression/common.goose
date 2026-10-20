// What rest::compressed's tests share: a handler behind it with answers that
// compress and answers it leaves alone, and a response sent in pieces
// inside it, with the case function that sends them. scripts/test-examples.sh
// decompresses real answers of examples/compress.
import std;
import http from "github.com/kaitk/goose-http@v0.4.2";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "../../";
import rest.compression;
import expect from "../";

// A body that compresses: 2,000 bytes of a repeating record.
fn records() -> u8[>..] {
    var t: u8[>..] = [];
    t.push('[');
    while t.len < 2000 { t.append("{\"id\":1,\"name\":\"Alpha Widget\"},"); }
    t.append("{}]");
    return t;
}

// A handler behind rest::compressed, around the route: /big answers
// records(), /small a short body, /missing fails 404, /png a large image,
// /done an answer that has a Content-Encoding, and /empty 204.
fn handle(cx) {
    rest::compressed(cx) { cx =>
        rest::route(cx) {
            let path = http::path_of(cx.req.target);
            if path == "/big" {
                rest::json_bytes(cx, 200, records());
            } else if path == "/small" {
                rest::text(cx, 200, "ok");
            } else if path == "/png" {
                http::respond(cx.out, 200, "image/png", records());
            } else if path == "/done" {
                http::start(cx.out, 200);
                http::field(cx.out, "Content-Encoding", "gzip");
                http::finish(cx.out, http::JSON, records());
            } else if path == "/empty" {
                rest::empty(cx, 204);
            } else {
                rest::fail(cx, 404, "not_found");
            }
        };
    };
}

fn served(text: const u8[:]) -> u8[>..] {
    return rest::serve_one(text) { cx => handle(cx) };
}

let GZIP = "Accept-Encoding: gzip, br\r\n";
let JSON_HEAD = "Content-Type: application/json\r\nVary: Accept-Encoding\r\n";

fn coded(format: i64, level: i64) -> u8[>..] {
    var z: u8[>..] = [];
    compress::compress(records(), z, format, level);
    return z;
}

enum Use { None, Rows { rows: i64, stop: i64, fail: bool }, Download }

struct St { use: Use = Use.None, sent: i64 = 0, file: http::FileBody = http::FileBody { .. } }

// What the case function saw, in order: M and the piece, C.
struct App { calls: u8[>..]& }

// The piece of an export a route sends n-th, from 0: rows that compress.
fn piece(n: i64) -> u8[>..] {
    var t: u8[>..] = [];
    for i in 20 { format(t, n, ",Alpha Widget,", i, "\n"); }
    return t;
}

fn resume(w: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// A piece at each MORE, then the end after w.rows. At w.stop the case
// function neither sends nor ends, so the connection closes, as for a client
// gone; with w.fail, piece 2 fails the route.
fn resume(w: Use.Rows, cx) {
    if cx.kind == http::MORE {
        cx.state.sent++;
        format(cx.app.calls, "M", cx.state.sent, " ");
        if cx.state.sent == w.stop { return; }
        if w.fail && cx.state.sent == 2 { rest::fail(cx, 500, "broken"); }
        rest::send(cx, piece(cx.state.sent));
        if cx.state.sent == w.rows { rest::end(cx); }
    } else if cx.kind == http::CLOSED {
        cx.app.calls.append("C ");
    }
}

fn resume(w: Use.Download, cx) { rest::send_file(cx, cx.state.file); }

// A response begun inside rest::compressed, with piece 0 at once and rows
// more at the MOREs, and what the case function saw.
fn streamed(text: const u8[:], rows: i64, content_type: const u8[:] = "text/csv", length: i64 = -1,
            stop: i64 = 0, fail: bool = false) -> u8[>..], u8[>..] {
    var calls: u8[>..] = [];
    var app = App { calls: calls };
    let out = rest::serve_one(text, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.use, cx);
        } else {
            rest::compressed(cx) { cx =>
                rest::begin(cx, 200, content_type, length, Use.Rows { rows: rows, stop: stop, fail: fail });
                rest::send(cx, piece(0));
            };
        }
    };
    return out, calls;
}

fn chunk(body: u8[>..]&, data: const u8[:]) {
    http::hex_size(body, data.len);
    body.append("\r\n");
    body.append(data);
    body.append("\r\n");
}

// Whether every encoder rest::compressed and goose-http lent is back.
fn all_released() -> bool {
    for e in rest::coded { if e.z.slot >= 0 { return false; } }
    for b in http::deflaters_busy { if b { return false; } }
    for b in http::zstds_busy { if b { return false; } }
    return true;
}

let CSV_HEAD = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/csv\r\nVary: Accept-Encoding\r\n";
