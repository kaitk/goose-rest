// A body read in pieces that ends early: a failure at a piece, an answer
// before the END, and a client that hangs up midway.
import std;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    // A failure at a piece answers in the error shape, then CLOSED, and no
    // more pieces.
    let failed, l1 = upload(post("fail", 20000));
    expect::same(expect::status_of(failed), "HTTP/1.1 422 Unprocessable Content", "failure");
    expect::same(expect::body_of(failed), "{\"error\":\"refused\"}", "failure's body");
    expect::same(l1, "B8192 C ", "failure's calls");
    // The same for a body that came whole.
    let whole, l2 = upload(post("fail", 100));
    expect::same(expect::body_of(whole), "{\"error\":\"refused\"}", "whole failure");
    expect::same(l2, "B100 C ", "whole failure's calls");
    // An answer before the END ends the read as a failure does.
    let stopped, l3 = upload(post("stop", 20000));
    expect::same(expect::body_of(stopped), "stopped", "answer");
    expect::same(l3, "B8192 C ", "answer's calls");
    // A client that hangs up midway: the pieces that came, then CLOSED.
    let gone, l4 = upload(post("", 10000, 20000));
    expect::same(l4, "B8192 B1808 C ", "hang-up's calls");
    expect::same(expect::status_of(gone), "HTTP/1.1 500 Internal Server Error", "hang-up");
    print("a body read in pieces, ended early: ok");
}
