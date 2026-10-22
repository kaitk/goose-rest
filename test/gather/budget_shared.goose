// One worker's gather budget across exchanges: a body that doesn't fit
// beside another, a route on rest::body_in_pieces beside a full budget, and
// a body that fits once another has finished, in the place it had.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    reusable[] var spill: u8[>..] = [];
    let one = head(30000).len + 30000;
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: one + 100, runs: runs };
    let body = letters(30000);
    let text = head(30000);
    let req, status = http::parse(text);
    assert(status == 200);

    // a gathers; b, beside it, doesn't fit.
    var a = Conn { req: req };
    var a_out: u8[>..] = [];
    send(a, a_out, http::REQUEST, "", 1 << 20, spill, b);
    send(a, a_out, http::BODY, body[..10000], 1 << 20, spill, b);
    assert(in_use(b) == one && a_out.len == 0);
    var second = Conn { req: req };
    var second_out: u8[>..] = [];
    send(second, second_out, http::REQUEST, "", 1 << 20, spill, b);
    expect::same(second_out, UNAVAILABLE, "beside another");
    assert(second.keep && in_use(b) == one);

    // A route on rest::body_in_pieces beside the full budget reads its body.
    var pieces = Conn { req: req };
    var pieces_out: u8[>..] = [];
    send(pieces, pieces_out, http::REQUEST, "", -1, spill, b);
    send(pieces, pieces_out, http::BODY, body[..20000], -1, spill, b);
    send(pieces, pieces_out, http::BODY, body[20000..], -1, spill, b);
    send(pieces, pieces_out, http::END, "", -1, spill, b);
    expect::same(expect::body_of(pieces_out), "30000", "in pieces beside a full budget");
    assert(in_use(b) == one);

    // Once a has its answer, the budget is free, and the next body fits.
    send(a, a_out, http::BODY, body[10000..], 1 << 20, spill, b);
    send(a, a_out, http::END, "", 1 << 20, spill, b);
    expect::same(expect::body_of(a_out), "30000 v", "the first");
    assert(in_use(b) == 0);
    var third = Conn { req: req };
    var third_out: u8[>..] = [];
    send(third, third_out, http::REQUEST, "", 1 << 20, spill, b);
    send(third, third_out, http::BODY, body, 1 << 20, spill, b);
    send(third, third_out, http::END, "", 1 << 20, spill, b);
    expect::same(expect::body_of(third_out), "30000 v", "after the first");
    assert(in_use(b) == 0);
    // Its run took the place a's had.
    assert(spill.len == one);
    print("a budget shared by exchanges: ok");
}
