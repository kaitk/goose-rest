// rest::compressed, byte for byte: a large answer compressed in each coding,
// an error from the route inside it, and the answers it leaves alone; and a
// response sent in pieces with rest::begin, in each coding, for HEAD, of a
// type not worth compressing, cut short, and beside rest::file, which goes as
// it is. scripts/test-unit.sh runs this through TinyCC, and writes
// test_compression.tmp in the working directory for it;
// scripts/test-examples.sh decompresses real answers of examples/compress.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import compress from "github.com/kaitk/goose-compress@v0.1.0";
import rest from "../";
import rest.compression;

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

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

fn test_compressed() {
    let t = records();
    let gz = coded(compress::GZIP, 1);
    assert(gz.len < t.len / 4);
    same(served(request("GET", "/big", GZIP)),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
    let zs = coded(compress::ZSTD, 1);
    same(served(request("GET", "/big", "Accept-Encoding: gzip, deflate, br, zstd\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: zstd\r\nContent-Length: ", zs.len, "\r\n\r\n", zs));
    let zl = coded(compress::ZLIB, 1);
    same(served(request("GET", "/big", "Accept-Encoding: deflate\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: deflate\r\nContent-Length: ", zl.len, "\r\n\r\n", zl));
    // A level of the program's.
    let gz9 = coded(compress::GZIP, 9);
    let nine = rest::serve_one(request("GET", "/big", GZIP)) { cx =>
        rest::compressed(cx, http::Compression { level: 9, .. }) { cx => rest::json_bytes(cx, 200, records()); };
    };
    same(nine, str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz9.len,
                   "\r\n\r\n", gz9));
}

fn test_left_alone() {
    let t = records();
    // Vary only: no Accept-Encoding, HEAD, a short body, an error.
    same(served(request("GET", "/big")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("GET", "/big", "Accept-Encoding: br, identity\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("HEAD", "/big", GZIP)),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n"));
    same(served(request("GET", "/small", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nVary: Accept-Encoding\r\n",
             "Content-Length: 2\r\n\r\nok"));
    same(served(request("GET", "/missing", GZIP)),
         str("HTTP/1.1 404 Not Found\r\n", JSON_HEAD, "Content-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    // As F wrote them: a type not worth compressing, a coding already, no body.
    same(served(request("GET", "/png", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("GET", "/done", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Type: application/json\r\nContent-Length: ", t.len,
             "\r\n\r\n", t));
    same(served(request("GET", "/empty", GZIP)), "HTTP/1.1 204 No Content\r\n\r\n");
}

// rest::timed outside fills its field in the head compressed copies, and
// rest::cors inside adds its fields to the answer compressed.
fn test_around() {
    let out = rest::serve_one(request("GET", "/big", str(GZIP, "Origin: https://a.example\r\n"))) { cx =>
        rest::timed(cx, false) {
            rest::compressed(cx) { cx =>
                rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
                    rest::json_bytes(cx, 200, records());
                };
            };
        };
    };
    let gz = coded(compress::GZIP, 1);
    let head = "HTTP/1.1 200 OK\r\nServer-Timing: app;dur=";
    same(out[..head.len], head);
    assert(out[head.len] >= '0' && out[head.len] <= '9');
    same(out[head.len + 14..],
         str("Access-Control-Allow-Origin: https://a.example\r\nVary: Origin\r\n", JSON_HEAD,
             "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
}

enum Waiting { None, Rows { rows: i64, stop: i64, fail: bool }, Download }

struct St { waiting: Waiting = Waiting.None, sent: i64 = 0, file: http::FileBody = http::FileBody { .. } }

// What the case function saw, in order: M and the piece, C.
struct App { calls: u8[>..]& }

// The piece of an export a route sends n-th, from 0: rows that compress.
fn piece(n: i64) -> u8[>..] {
    var t: u8[>..] = [];
    for i in 20 { format(t, n, ",Alpha Widget,", i, "\n"); }
    return t;
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// A piece at each MORE, then the end after w.rows. At w.stop the case
// function neither sends nor ends, so the connection closes, as for a client
// gone; with w.fail, piece 2 fails the route.
fn resume(w: Waiting.Rows, cx) {
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

fn resume(w: Waiting.Download, cx) { rest::send_file(cx, cx.state.file); }

// A response begun inside rest::compressed, with piece 0 at once and rows
// more at the MOREs, and what the case function saw.
fn streamed(text: const u8[:], rows: i64, content_type: const u8[:] = "text/csv", length: i64 = -1,
            stop: i64 = 0, fail: bool = false) -> u8[>..], u8[>..] {
    var calls: u8[>..] = [];
    var app = App { calls: calls };
    let out = rest::serve_one(text, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::compressed(cx) { cx =>
                rest::begin(cx, 200, content_type, length, Waiting.Rows { rows: rows, stop: stop, fail: fail });
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

// What a response of pieces 0 to n sends coded with e after its head: each
// piece flushed in a chunk of its own, then the coding's trailer, and the
// last chunk.
fn coded_chunks<E>(e: E&, n: i64) -> u8[>..] {
    var body: u8[>..] = [];
    for i in n + 1 {
        var z: u8[>..] = [];
        compress::write(e, piece(i), z);
        compress::flush(e, z);
        chunk(body, z);
    }
    var z: u8[>..] = [];
    compress::finish(e, z);
    chunk(body, z);
    body.append("0\r\n\r\n");
    return body;
}

// Whether every encoder rest::compressed and goose-http lent is back.
fn all_released() -> bool {
    for e in rest::coded { if e.z.slot >= 0 { return false; } }
    for b in http::deflaters_busy { if b { return false; } }
    for b in http::zstds_busy { if b { return false; } }
    return true;
}

let CSV_HEAD = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/csv\r\nVary: Accept-Encoding\r\n";

fn test_pieces_coded() {
    let get = "GET /export HTTP/1.1\r\n";
    var gzip = compress::encoder(compress::GZIP, 1);
    let gz, l1 = streamed(str(get, GZIP, "\r\n"), 3);
    same(gz, str(CSV_HEAD, "Content-Encoding: gzip\r\n\r\n", coded_chunks(gzip, 3)));
    same(l1, "M1 M2 M3 ");
    var zlib = compress::encoder(compress::ZLIB, 1);
    let zl, l2 = streamed(str(get, "Accept-Encoding: deflate\r\n\r\n"), 3);
    same(zl, str(CSV_HEAD, "Content-Encoding: deflate\r\n\r\n", coded_chunks(zlib, 3)));
    same(l2, "M1 M2 M3 ");
    var zstd = compress::zstd_encoder(1);
    let zs, l3 = streamed(str(get, "Accept-Encoding: gzip, zstd\r\n\r\n"), 3);
    same(zs, str(CSV_HEAD, "Content-Encoding: zstd\r\n\r\n", coded_chunks(zstd, 3)));
    same(l3, "M1 M2 M3 ");
    assert(all_released());
    // One entry, reused by each response in turn.
    assert(rest::coded.len == 1);
}

fn test_pieces_left_alone() {
    var all: u8[>..] = [];
    for i in 3 { all.append(piece(i)); }
    // No coding taken: the length rest::begin was given, and Vary.
    let plain, l1 = streamed("GET /export HTTP/1.1\r\n\r\n", 2, "text/csv", all.len);
    same(plain, str("HTTP/1.1 200 OK\r\nContent-Length: ", all.len, "\r\nContent-Type: text/csv\r\n",
                    "Vary: Accept-Encoding\r\n\r\n", all));
    same(l1, "M1 M2 ");
    // HEAD: the head a GET would get, without Content-Encoding, and no calls.
    let head, l2 = streamed(str("HEAD /export HTTP/1.1\r\n", GZIP, "\r\n"), 2);
    same(head, str(CSV_HEAD, "\r\n"));
    same(l2, "");
    // A type not worth compressing: as written, without Vary.
    var chunks: u8[>..] = [];
    for i in 3 { chunk(chunks, piece(i)); }
    let png, l3 = streamed(str("GET /export HTTP/1.1\r\n", GZIP, "\r\n"), 2, "image/png");
    same(png, str("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: image/png\r\n\r\n", chunks,
                  "0\r\n\r\n"));
    same(l3, "M1 M2 ");
    assert(all_released());
}

fn test_pieces_ending_early() {
    let get = str("GET /export HTTP/1.1\r\n", GZIP, "\r\n");
    // The connection closes at the second MORE: what was sent, then CLOSED,
    // and the encoder is back.
    let gone, l1 = streamed(get, 5, "text/csv", -1, 2);
    same(l1, "M1 M2 C ");
    assert(starts_with(gone, str(CSV_HEAD, "Content-Encoding: gzip\r\n\r\n")));
    assert(!ends_with(gone, "0\r\n\r\n"));
    assert(all_released());
    // A failure with the response open cuts it short, the same way.
    let cut, l2 = streamed(get, 5, "text/csv", -1, 0, true);
    same(l2, "M1 M2 C ");
    assert(!ends_with(cut, "0\r\n\r\n"));
    assert(all_released());
}

// Outside rest::compressed, rest::begin's response goes as written, and
// inside it rest::file's does.
fn test_pieces_outside() {
    var calls: u8[>..] = [];
    var app = App { calls: calls };
    let plain = rest::serve_one(str("GET /export HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        rest::compressed(cx) { cx => cx.state.sent = 1; };
        rest::begin(cx, 200, "text/csv", 2, Waiting.None);
        rest::send(cx, "ok");
        rest::end(cx);
    };
    same(plain, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/csv\r\n\r\nok");
    let path = "test_compression.tmp";
    let data = records();
    assert(write_file(path, data));
    let file = rest::serve_one(str("GET /f HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::compressed(cx) { cx => rest::file(cx, path, cx.state.file, Waiting.Download, "application/json"); };
        }
    };
    assert(find(file, "Content-Encoding") < 0);
    same(file[find(file, "\r\n\r\n") + 4..], data);
    assert(delete_file(path));
}

fn main() {
    test_compressed();
    test_left_alone();
    test_around();
    test_pieces_coded();
    test_pieces_left_alone();
    test_pieces_ending_early();
    test_pieces_outside();
    print("test_compression: ok");
}
