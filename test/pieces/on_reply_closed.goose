// plod::on_reply around a route that reads its body in pieces: a BODY that
// fails, or answers before the END, leaves the variant in cx.state.use, so
// the CLOSED that follows reaches it and not Use.None.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";
import common;

fn upload_on_reply(text: const u8[:]) -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = plod::serve_one(text, app, St { .. }) { cx =>
        if plod::resumed(cx) {
            plod::on_reply(cx) { resume(cx.state.use, cx); };
        } else {
            plod::body_in_pieces(cx, 1 << 20, Use.Upload);
        }
    };
    return out, log;
}

fn main() {
    // A four-byte body whose BODY fails the route: 422, then CLOSED.
    let failed, l1 = upload_on_reply(post("fail", 4));
    expect::same(expect::status_of(failed), "HTTP/1.1 422 Unprocessable Content", "failed");
    expect::same(l1, "B4 C ", "failed's calls");
    // One whose BODY answers before the END.
    let stopped, l2 = upload_on_reply(post("stop", 4));
    expect::same(expect::body_of(stopped), "stopped", "stopped");
    expect::same(l2, "B4 C ", "stopped's calls");
    print("plod::on_reply's CLOSED: ok");
}
