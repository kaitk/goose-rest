// A response begun while the body is read: each piece's first bytes back.
import std;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(post("", 20000), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::body_in_pieces(cx, 1 << 20, Waiting.Echo);
            rest::begin(cx, 200, "text/plain", -1, Waiting.Echo);
        }
    };
    expect::same(expect::body_of(out), "4\r\nabcd\r\n4\r\ncdef\r\n4\r\nefgh\r\n0\r\n\r\n", "echo");
    expect::same(log, "B8192 B8192 B3616 E ", "echo's calls");
    print("a response begun while the body is read: ok");
}
