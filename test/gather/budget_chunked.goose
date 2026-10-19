// A chunked body against the gather budget: its run grows by the piece
// alone where doubling would pass the budget, and once the body passes it,
// 503 and the connection closes.
import std;
import http from "github.com/kaitk/goose-http@2c5280c76ade5f70f69a80cd68f73b03d5b34252";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    // The run doubles to 32 KB; doubled again it would pass the budget of
    // 40,000 bytes, so it grows by the piece alone, and once the body passes
    // the budget it gets 503, and the connection closes.
    var caps: i64[>..] = [];
    let closing = str("HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n",
                      UNAVAILABLE["HTTP/1.1 503 Service Unavailable\r\n".len..], "\r\nclosed");
    let h = head(-1).len;
    expect::same(gather(head(-1), 100000, 1 << 20, caps, 40000), closing, "chunked past the budget");
    let want: i64[6] = [16384, 16384, 32768, 32768, h + 4 * 8192, 0];
    assert(caps.len == 6);
    for i in 6 { assert(caps[i] == want[i]); }
    print("a chunked body past the budget: ok");
}
