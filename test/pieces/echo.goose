// A response begun while the body is read: each piece's first bytes back.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(post("", 20000), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.use, cx);
        } else {
            rest::body_in_pieces(cx, 1 << 20, Use.Echo);
            rest::begin(cx, 200, "text/plain", -1, Use.Echo);
        }
    };
    expect::same(expect::body_of(out), "4\r\nabcd\r\n4\r\ncdef\r\n4\r\nefgh\r\n0\r\n\r\n", "echo");
    expect::same(log, "B8192 B8192 B3616 E ", "echo's calls");
    print("a response begun while the body is read: ok");
}
