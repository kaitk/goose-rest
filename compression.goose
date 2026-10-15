// rest::compressed, the answers of a block of routes compressed by the
// request's Accept-Encoding, with goose-http's http.compression. Only a
// program that imports this module needs goose-compress, which its root file
// declares at the tag goose-http's compression.goose names:
//
//   import http from "github.com/kaitk/goose-http@v0.3.2";
//   import compress from "github.com/kaitk/goose-compress@v0.1.0";
//   import rest from "github.com/kaitk/goose-rest@<tag>";
//   import rest.compression;
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import compress from "github.com/kaitk/goose-compress@v0.1.0";
import http.compression;

// Runs F(c), c being cx with its answer written to a buffer of its own, then
// writes that answer compressed, as http::respond_compressed would have: in
// the coding the request's Accept-Encoding weighs highest, with
// Content-Encoding, the compressed Content-Length, and Vary:
// Accept-Encoding. Errors count when the block holds the rest::route that
// answers them. HEAD, 206, a body under c.min_size, and a request that takes
// no coding get only the Vary. An answer whose type http::compressible
// refuses, one that has a Content-Encoding, one without a body, and a
// response F begins and sends in pieces go as F wrote them. The buffer can't
// be cx.out's own, which a handler can't shrink while it holds the request
// (spec §5.1), so the answer is copied once.
//
//   rest::compressed(cx) { cx => rest::routes(cx) { cx => ... }; };
inline fn compressed<S, A, R, F>(cx: Cx<S, A, R>&, c: http::Compression = http::Compression { .. }) {
    var buf: u8[>..] = [];
    let o = cx.out;
    var inner = Cx<S, A, R> { req: cx.req, body: cx.body,
                              out: http::Reply { buf: buf, common: o.common, keep_alive: o.keep_alive, minor: o.minor,
                                                 head: o.head, stream: o.stream, fd: o.fd },
                              state: cx.state, app: cx.app, scratch: cx.scratch, kind: cx.kind, reply: cx.reply,
                              tag: cx.tag, more: cx.more, ex: cx.ex, kept: cx.kept, router: cx.router };
    F(&inner);   // a block given the local itself gets a copy of it
    write_compressed(cx.out, cx.req, buf, c);
}

// Appends w, what compressed's block wrote, to out.buf, its answer
// compressed for req where it's whole and worth it.
fn write_compressed(out: http::Reply, req: const http::Request&, w: const u8[:], c: http::Compression) {
    let at, n = length_line(w, out.head);
    guard at >= 0 && !out.stream.open else {
        out.buf.append(w);
        return;
    }
    let fields = w[find(w, "\r\n") + 2..at];
    let media, typed = http::field_in(fields, "content-type");
    let coded, has_coding = http::field_in(fields, "content-encoding");
    guard typed && !has_coding && http::compressible(media) else {
        out.buf.append(w);
        return;
    }
    out.buf.append(w[..at]);
    out.buf.append("Vary: Accept-Encoding\r\n");
    let coding = if out.head || out.stream.status == 206 || n < c.min_size {
        http::Coding.Identity
    } else {
        http::coding_for(req, c)
    };
    guard coding != http::Coding.Identity else {
        out.buf.append(w[at..]);
        return;
    }
    out.buf.append(http::coding_field(coding));
    var z: u8[>..] = [];
    http::compress_whole(w[w.len - n..], z, coding, c);
    http::write_body(out.buf, http::NO_TYPE, z, false);
}

// Where w's Content-Length line starts, and its value, when w is one whole
// response that http::finish wrote, its Content-Length last in the head and
// then its body, or none for HEAD; else -1.
fn length_line(w: const u8[:], head: bool) -> i64, i64 {
    let end = find(w, "\r\n\r\n");
    guard end >= 0 else { return -1, 0; }
    var at = end;
    while at > 0 && w[at - 1] != '\n' { at--; }
    guard at > 0 else { return -1, 0; }   // no field: the status line alone
    let name, value, next = http::field_at(w, at);
    let n, ok = parse_int(value);
    guard http::same_name(name, "content-length") && ok && end + 4 + (if head { 0 } else { n }) == w.len else {
        return -1, 0;
    }
    return at, n;
}
