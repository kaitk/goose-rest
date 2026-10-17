// The gather budget bounds the spill, not only the bytes in use: a body that
// fits beside the others in bytes, but in no free space of the spill, is
// refused rather than grow it.
import std;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    reusable[] var spill: u8[>..] = [];
    let small_text = head(20000);
    let large_text = head(30000);
    let small = small_text.len + 20000;
    let large = large_text.len + 30000;
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: 2 * small + large - 1, runs: runs };
    let s, s_status = http::parse(small_text);
    let l, l_status = http::parse(large_text);
    assert(s_status == 200 && l_status == 200);
    let body = letters(30000);

    var first = Conn { req: s };
    var first_out: u8[>..] = [];
    send(first, first_out, http::REQUEST, "", 1 << 20, spill, b);
    var second = Conn { req: s };
    var second_out: u8[>..] = [];
    send(second, second_out, http::REQUEST, "", 1 << 20, spill, b);
    send(first, first_out, http::BODY, body[..20000], 1 << 20, spill, b);
    send(first, first_out, http::END, "", 1 << 20, spill, b);
    expect::same(expect::body_of(first_out), "20000 f", "the first");
    // A hole of small bytes, then the second's run.
    var third = Conn { req: l };
    var third_out: u8[>..] = [];
    send(third, third_out, http::REQUEST, "", 1 << 20, spill, b);
    expect::same(third_out, UNAVAILABLE, "no space for it");
    assert(in_use(b) + large <= b.size);
    // Once the second has its answer, the spill is free, and holds it.
    send(second, second_out, http::BODY, body[..20000], 1 << 20, spill, b);
    send(second, second_out, http::END, "", 1 << 20, spill, b);
    var fourth = Conn { req: l };
    var fourth_out: u8[>..] = [];
    whole(fourth, fourth_out, body, spill, b);
    expect::same(expect::body_of(fourth_out), "30000 v", "once free");
    assert(spill.len == 2 * small);
    print("holes in the spill: ok");
}
