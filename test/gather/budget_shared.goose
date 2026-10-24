// One worker's gather budget across exchanges: a body that doesn't fit
// beside another, a route on plod::body_in_pieces beside a full budget, and
// a body that fits once another has finished.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let one = head(30000).len + 30000;
    http::gather_budget(one + 100);
    let body = letters(30000);
    let text = head(30000);
    let req, status = http::parse(text);
    assert(status == 200);

    // a gathers; b, beside it, doesn't fit.
    var a = Conn { req: req };
    var a_out: u8[>..] = [];
    send(a, a_out, http::REQUEST, "", 1 << 20);
    send(a, a_out, http::BODY, body[..10000], 1 << 20);
    assert(http::gather_promised == one && a_out.len == 0);
    var second = Conn { req: req };
    var second_out: u8[>..] = [];
    send(second, second_out, http::REQUEST, "", 1 << 20);
    expect::same(second_out, UNAVAILABLE, "beside another");
    assert(second.keep && http::gather_promised == one);

    // A route on plod::body_in_pieces beside the full budget reads its body.
    var pieces = Conn { req: req };
    var pieces_out: u8[>..] = [];
    send(pieces, pieces_out, http::REQUEST, "", -1);
    send(pieces, pieces_out, http::BODY, body[..20000], -1);
    send(pieces, pieces_out, http::BODY, body[20000..], -1);
    send(pieces, pieces_out, http::END, "", -1);
    expect::same(expect::body_of(pieces_out), "30000", "in pieces beside a full budget");
    assert(http::gather_promised == one);

    // Once a has its answer, the budget is free, and the next body fits.
    send(a, a_out, http::BODY, body[10000..], 1 << 20);
    send(a, a_out, http::END, "", 1 << 20);
    expect::same(expect::body_of(a_out), "30000 v", "the first");
    assert(http::gather_promised == 0);
    var third = Conn { req: req };
    var third_out: u8[>..] = [];
    whole(third, third_out, body);
    expect::same(expect::body_of(third_out), "30000 v", "after the first");
    assert(http::gather_promised == 0);
    print("a budget shared by exchanges: ok");
}
