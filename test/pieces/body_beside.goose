// rest::body beside rest::body_in_pieces, before it and after it: the
// second read fails with body_already_read.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let first, l1 = upload(post("", 100), 1 << 20, "first");
    expect::same(expect::body_of(first), "{\"error\":\"body_already_read\"}", "body_in_pieces after body");
    expect::same(l1, "", "body_in_pieces after body's calls");
    let after, l2 = upload(post("", 100), 1 << 20, "after");
    expect::same(expect::body_of(after), "{\"error\":\"body_already_read\"}", "body after body_in_pieces");
    // The route failed before any piece: CLOSED alone.
    expect::same(l2, "C ", "body after body_in_pieces's calls");
    print("rest::body beside rest::body_in_pieces: ok");
}
