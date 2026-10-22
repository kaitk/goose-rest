// A chunked body, gathered in a run that starts at 16 KB and doubles as it
// fills.
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    var caps: i64[>..] = [];
    expect::same(expect::body_of(gather(head(-1), 50000, 1 << 20, caps)), "50000 b", "chunked");
    // 16 KB, then doubled as it fills.
    assert(caps[0] == 16384 && caps[caps.len - 1] == 65536);
    for i in caps.len - 1 { assert(caps[i + 1] == caps[i] || caps[i + 1] == caps[i] * 2); }
    print("a chunked body: ok");
}
