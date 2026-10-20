// A compressed response in pieces that ends early, the connection closed or
// cut short by a failure: what was sent, then CLOSED, and the encoder back.
import std;
import http from "github.com/kaitk/goose-http@v0.4.1";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    let get = str("GET /export HTTP/1.1\r\n", GZIP, "\r\n");
    // The connection closes at the second MORE: what was sent, then CLOSED,
    // and the encoder is back.
    let gone, l1 = streamed(get, 5, "text/csv", -1, 2);
    expect::same(l1, "M1 M2 C ");
    assert(starts_with(gone, str(CSV_HEAD, "Content-Encoding: gzip\r\n\r\n")));
    assert(!ends_with(gone, "0\r\n\r\n"));
    assert(all_released());
    // A failure with the response open cuts it short, the same way.
    let cut, l2 = streamed(get, 5, "text/csv", -1, 0, true);
    expect::same(l2, "M1 M2 C ");
    assert(!ends_with(cut, "0\r\n\r\n"));
    assert(all_released());
    print("compressed responses in pieces, ended early: ok");
}
