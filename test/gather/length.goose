// A body with a Content-Length, gathered in one run of its exact size from
// the head on, which never moves.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let text = head(100000);
    var caps: i64[>..] = [];
    expect::same(expect::body_of(gather(text, 100000, 1 << 20, caps)), "100000 d", "with a length");
    // One run of the head and the body, from the head on.
    for c in caps { assert(c == text.len + 100000); }
    assert(caps.len == 1 + (100000 + 8191) / 8192);
    print("a body with a length: ok");
}
