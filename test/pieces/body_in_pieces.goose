// rest::body_in_pieces: a body that came with its head, an empty one, a
// longer one a piece at a time, and one over the limit.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    // A body that came with its head: one piece, then the END.
    let short, l1 = upload(post("", 100));
    expect::same(expect::body_of(short), "100", "whole");
    expect::same(l1, "B100 E ", "whole's calls");
    // An empty body: the END alone.
    let empty, l2 = upload(post("", 0));
    expect::same(expect::body_of(empty), "0", "empty");
    expect::same(l2, "E ", "empty's calls");
    // A longer one, a piece at a time.
    let long, l3 = upload(post("", 20000));
    expect::same(expect::body_of(long), "20000", "in pieces");
    expect::same(l3, "B8192 B8192 B3616 E ", "in pieces' calls");
    // A Content-Length over the limit: 413 before any piece.
    let big, l4 = upload(post("", 20000), 10000);
    expect::same(expect::status_of(big), "HTTP/1.1 413 Content Too Large", "over the limit");
    expect::same(expect::body_of(big), "{\"error\":\"payload_too_large\"}", "over the limit's body");
    expect::same(l4, "", "over the limit's calls");
    print("rest::body_in_pieces: ok");
}
