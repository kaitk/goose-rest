// A chunked body against the gather budget: it's promised its route's limit
// at its head, so one the budget can't promise that much gets 503 there,
// before any piece, and one it can is never refused later.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    // A limit of 1 MB past a budget of 40,000 bytes: 503 at the head, and
    // nothing gathered.
    var none: i64[>..] = [];
    expect::same(gather(head(-1), 100000, 1 << 20, none, 40000), UNAVAILABLE, "a limit past the budget");
    assert(none.len == 1 && none[0] == 0);
    // A limit of 60,000 within a budget of its head and that: gathered whole,
    // however the run grows.
    var caps: i64[>..] = [];
    let h = head(-1).len;
    expect::same(expect::body_of(gather(head(-1), 60000, 60000, caps, h + 60000)), "60000 r", "a limit within it");
    print("a chunked body against the budget: ok");
}
