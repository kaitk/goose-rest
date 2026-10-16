// Responses in pieces rest::compressed leaves alone: no coding taken, HEAD,
// and a type not worth compressing.
import std;
import http from "github.com/kaitk/goose-http@v0.3.4";
import compress from "github.com/kaitk/goose-compress@v0.1.0";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    var all: u8[>..] = [];
    for i in 3 { all.append(piece(i)); }
    // No coding taken: the length rest::begin was given, and Vary.
    let plain, l1 = streamed("GET /export HTTP/1.1\r\n\r\n", 2, "text/csv", all.len);
    expect::same(plain, str("HTTP/1.1 200 OK\r\nContent-Length: ", all.len, "\r\nContent-Type: text/csv\r\n",
                            "Vary: Accept-Encoding\r\n\r\n", all));
    expect::same(l1, "M1 M2 ");
    // HEAD: the head a GET would get, without Content-Encoding, and no calls.
    let head, l2 = streamed(str("HEAD /export HTTP/1.1\r\n", GZIP, "\r\n"), 2);
    expect::same(head, str(CSV_HEAD, "\r\n"));
    expect::same(l2, "");
    // A type not worth compressing: as written, without Vary.
    var chunks: u8[>..] = [];
    for i in 3 { chunk(chunks, piece(i)); }
    let png, l3 = streamed(str("GET /export HTTP/1.1\r\n", GZIP, "\r\n"), 2, "image/png");
    expect::same(png, str("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: image/png\r\n\r\n", chunks,
                          "0\r\n\r\n"));
    expect::same(l3, "M1 M2 ");
    assert(all_released());
    print("responses in pieces left alone: ok");
}
