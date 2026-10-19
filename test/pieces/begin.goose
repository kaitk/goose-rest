// rest::begin: a response sent in pieces, chunked and with a length, for
// HEAD, and cut short by a failure.
import std;
import http from "github.com/kaitk/goose-http@v0.4.0";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let get = "GET /export HTTP/1.1\r\n\r\n";
    let chunked, l1 = rows_of(get, 3);
    expect::same(expect::status_of(chunked), "HTTP/1.1 200 OK", "chunked");
    expect::same(expect::body_of(chunked), "5\r\nrow1\n\r\n5\r\nrow2\n\r\n5\r\nrow3\n\r\n0\r\n\r\n", "chunked's body");
    expect::same(l1, "M1 M2 M3 ", "chunked's calls");
    let sized, l2 = rows_of(get, 2, 10);
    expect::same(sized, "HTTP/1.1 200 OK\r\nContent-Length: 10\r\nContent-Type: text/csv\r\n\r\nrow1\nrow2\n", "sized");
    expect::same(l2, "M1 M2 ", "sized's calls");
    // HEAD: the head alone, and no calls.
    let head, l3 = rows_of("HEAD /export HTTP/1.1\r\n\r\n", 3);
    expect::same(head, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/csv\r\n\r\n", "HEAD");
    expect::same(l3, "", "HEAD's calls");
    // A failure with the response open cuts it short, then CLOSED.
    let cut, l4 = rows_of(get, 99);
    expect::same(expect::body_of(cut), "5\r\nrow1\n\r\n", "cut short");
    expect::same(l4, "M1 M2 C ", "cut short's calls");
    print("rest::begin: ok");
}
