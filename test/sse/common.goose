import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";

enum Use { None, Events }
struct St { use: Use = Use.None }

// HTTP/1.0 exposes the event bytes without chunk framing.
fn frame<F>() -> u8[>..] {
    var app = rest::NoState { .. };
    let out = rest::serve_one("GET /events HTTP/1.0\r\n\r\n", app, St { .. }) { cx =>
        rest::sse_begin(cx, Use.Events);
        F(cx);
        rest::end(cx);
    };
    return str(expect::body_of(out));
}
