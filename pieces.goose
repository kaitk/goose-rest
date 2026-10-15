// Bodies and responses in pieces, and upgraded connections: a route that
// reads its body as it arrives (receive), sends its response as the client
// takes it, or takes the connection's bytes says so with a Waiting variant,
// as rest::ask does, and serve calls the handler again for each event of
// the exchange, rest::resumed, with cx.kind saying which (goose-http's
// docs/patterns.md, "Request bodies" and "Long responses"):
//
//   rest::serve(cfg, app, St { .. }) { cx =>
//       if rest::resumed(cx) { rest::route(cx) { resume(cx.state.waiting, cx); }; } else { handle(cx); }
//   };
//
// A case function gets http::CLOSED once when the exchange ends before the
// route finished, and releases what the state holds then.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.3.2";

// Reads the request's body in pieces as they arrive, up to limit bytes, with
// w in cx.state.waiting. The route returns without an answer, and the
// handler is called again with http::BODY and each piece in cx.body, then
// http::END, where the route answers. A body that came whole with its head
// comes the same way, as one BODY, and an empty one as END alone. The
// handler gets http::CLOSED once, writing nowhere, if the route ends before
// the END: when its client goes, when the body passes limit, or when it
// answers or fails first, after which it gets no more pieces. A
// Content-Length over limit fails here with 413 payload_too_large, before
// the body is sent; a chunked body past it gets 413 and the connection
// closes. Config.max_body caps limit. 500 body_already_read after
// rest::body, and 500 not_served outside serve and serve_one.
fn receive<S, A, R>(cx: Cx<S, A, R>&, limit: i64, w) {
    var x .= cx.ex;
    guard x else { fail(cx, 500, "not_served"); }
    guard x.limit == 0 else { fail(cx, 500, "body_already_read"); }
    let over = if x.pending { !cx.req.chunked && cx.req.body > limit } else { cx.body.len > limit };
    if over { fail(cx, 413, "payload_too_large"); }
    x.limit = limit;
    x.len = 0;
    x.mode |= RECEIVING;
    cx.state.waiting = w;
}
