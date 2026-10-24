// A response sent in pieces inside plod::compressed, in each coding: each
// piece flushed in a chunk of its own, every encoder back after, and one
// entry reused by each response in turn.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import compress from "github.com/kaitk/goose-compress@v0.1.4";
import plod from "../../";
import plod.compression;
import expect from "../";
import common;

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

fn main() {
    let get = "GET /export HTTP/1.1\r\n";
    var gzip = compress::encoder(compress::GZIP, 1);
    let gz, l1 = streamed(str(get, GZIP, "\r\n"), 3);
    expect::same(gz, str(CSV_HEAD, "Content-Encoding: gzip\r\n\r\n", coded_chunks(gzip, 3)));
    expect::same(l1, "M1 M2 M3 ");
    var zlib = compress::encoder(compress::ZLIB, 1);
    let zl, l2 = streamed(str(get, "Accept-Encoding: deflate\r\n\r\n"), 3);
    expect::same(zl, str(CSV_HEAD, "Content-Encoding: deflate\r\n\r\n", coded_chunks(zlib, 3)));
    expect::same(l2, "M1 M2 M3 ");
    var zstd = compress::zstd_encoder(1);
    let zs, l3 = streamed(str(get, "Accept-Encoding: gzip, zstd\r\n\r\n"), 3);
    expect::same(zs, str(CSV_HEAD, "Content-Encoding: zstd\r\n\r\n", coded_chunks(zstd, 3)));
    expect::same(l3, "M1 M2 M3 ");
    assert(all_released());
    // One entry, reused by each response in turn.
    assert(plod::coded.len == 1);
    print("responses in pieces, compressed: ok");
}
