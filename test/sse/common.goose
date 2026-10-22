import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";

enum Use { None, Events }
struct St { use: Use = Use.None }

// HTTP/1.0 exposes the event bytes without chunk framing.
fn frame<F>() -> u8[>..] {
    var app = plod::NoState { .. };
    let out = plod::serve_one("GET /events HTTP/1.0\r\n\r\n", app, St { .. }) { cx =>
        plod::sse_begin(cx, Use.Events);
        F(cx);
        plod::end(cx);
    };
    return str(expect::body_of(out));
}
