// Bodies read in pieces with rest::body_in_pieces, through rest::serve_one: whole
// and in pieces, the limit, a failure or an answer before the END, a client
// that hangs up, and rest::body beside it; and responses sent in pieces with
// rest::begin, chunked and with a length, for HEAD, cut short by a failure,
// and begun while the body is read; and files with rest::file, whole, a
// range, a 304, HEAD, and none. scripts/test-unit.sh runs this through
// TinyCC, and writes test_pieces.tmp in the working directory for it.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

enum Waiting { None, Upload, Export { rows: i64 }, Echo, Download }

struct St { waiting: Waiting = Waiting.None, size: i64 = 0, file: http::FileBody = http::FileBody { .. } }

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
            rest::body_in_pieces(cx, limit, Waiting.Upload);
            if both == "after" { rest::body(cx); }
        }
    };
    return out, log;
}

fn test_body_in_pieces() {
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
    same(body_of(first), "{\"error\":\"body_already_read\"}", "body_in_pieces after body");
    same(l1, "", "body_in_pieces after body's calls");
    let after, l2 = upload(post("", 100), 1 << 20, "after");
    same(body_of(after), "{\"error\":\"body_already_read\"}", "body after body_in_pieces");
    // The route failed before any piece: CLOSED alone.
    same(l2, "C ", "body after body_in_pieces's calls");
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

fn test_begin() {
    let get = "GET /export HTTP/1.1\r\n\r\n";
    let chunked, l1 = rows_of(get, 3);
    same(status_of(chunked), "HTTP/1.1 200 OK", "chunked");
    same(body_of(chunked), "5\r\nrow1\n\r\n5\r\nrow2\n\r\n5\r\nrow3\n\r\n0\r\n\r\n", "chunked's body");
    same(l1, "M1 M2 M3 ", "chunked's calls");
    let sized, l2 = rows_of(get, 2, 10);
    same(sized, "HTTP/1.1 200 OK\r\nContent-Length: 10\r\nContent-Type: text/csv\r\n\r\nrow1\nrow2\n", "sized");
    same(l2, "M1 M2 ", "sized's calls");
    // HEAD: the head alone, and no calls.
    let head, l3 = rows_of("HEAD /export HTTP/1.1\r\n\r\n", 3);
    same(head, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/csv\r\n\r\n", "HEAD");
    same(l3, "", "HEAD's calls");
    // A failure with the response open cuts it short, then CLOSED.
    let cut, l4 = rows_of(get, 99);
    same(body_of(cut), "5\r\nrow1\n\r\n", "cut short");
    same(l4, "M1 M2 C ", "cut short's calls");
}

// A response begun while the body is read: each piece's first bytes back.
fn test_echo() {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(post("", 20000), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::body_in_pieces(cx, 1 << 20, Waiting.Echo);
            rest::begin(cx, 200, "text/plain", -1, Waiting.Echo);
        }
    };
    same(body_of(out), "4\r\nabcd\r\n4\r\ncdef\r\n4\r\nefgh\r\n0\r\n\r\n", "echo");
    same(log, "B8192 B8192 B3616 E ", "echo's calls");
}

fn resume(w: Waiting.Download, cx) {
    format(cx.app.log, if cx.kind == http::MORE { "M " } else if cx.kind == http::CLOSED { "C " } else { "? " });
    rest::send_file(cx, cx.state.file);
}

// The file at path, by a GET with fields, the request's own.
fn download(path: const u8[:], fields: const u8[:] = "", method: const u8[:] = "GET") -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(str(method, " /f HTTP/1.1\r\n", fields, "\r\n"), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::file(cx, path, cx.state.file, Waiting.Download);
        }
    };
    return out, log;
}

fn test_file() {
    let path = "test_pieces.tmp";
    var data: u8[>..] = [];
    for i in 150000 { data.push('a' + (i % 26) as u8); }
    assert(write_file(path, data));
    // In pieces of 64 KB, a MORE each.
    let whole, l1 = download(path);
    same(status_of(whole), "HTTP/1.1 200 OK", "file");
    assert(body_of(whole) == data);
    same(l1, "M M M ", "file's calls");
    // A range: 206, and those bytes.
    let part, l2 = download(path, "Range: bytes=26-30\r\n");
    same(status_of(part), "HTTP/1.1 206 Partial Content", "range");
    same(body_of(part), "abcde", "range's bytes");
    // The ETag it gave: 304, with no calls.
    let at = find(whole, "ETag: ") + 6;
    let tag = whole[at..at + find(whole[at..], "\r\n")];
    let same_tag, l3 = download(path, str("If-None-Match: ", tag, "\r\n"));
    same(status_of(same_tag), "HTTP/1.1 304 Not Modified", "If-None-Match");
    same(l3, "", "304's calls");
    let head, l4 = download(path, "", "HEAD");
    same(body_of(head), "", "HEAD");
    same(l4, "", "HEAD's calls");
    let missing, l5 = download("no-such-file.tmp");
    same(body_of(missing), "{\"error\":\"file_not_found\"}", "no file");
    assert(delete_file(path));
}

fn main() {
    test_file();
    test_body_in_pieces();
    test_ending_early();
    test_body_beside();
    test_begin();
    test_echo();
    print("test_pieces: ok");
}
