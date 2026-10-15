// Answering a request's bytes without a socket, as serve answers them, for
// tests that run in-process.

namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.3.2";

// What serve answers to text, one request's bytes, through H(cx) inside
// rest::route: the status line, the fields, and the body, without Date or
// Server. app is the worker's state, fresh the per-request state, and cfg the
// limits goose-http applies. A body that doesn't fit in cfg.max_head with
// its head comes in pieces of cfg.max_head bytes: gathered as serve gathers
// it, so H runs again once it's whole if it called rest::body, or passed on
// to a route that called rest::receive. A body shorter than its
// Content-Length is a client that hung up midway: its pieces come, then
// http::CLOSED in place of http::END. An HTTP/1.1 request
// without Host is given "Host: localhost". A request goose-http refuses gets
// its refusal, and H that doesn't answer 500, as from the server.
fn serve_one<A, S, H>(text: const u8[:], app: A&, fresh: S, cfg: http::Config = http::Config { .. }) -> u8[>..] {
    var out: u8[>..] = [];
    let full = with_host(text);
    let req, status = http::parse(full, cfg.max_head, cfg.max_body, cfg.max_line, cfg.max_fields);
    if status != 200 {
        http::refuse(out, status, "");
        return out;
    }
    if req.chunked {
        print("rest::serve_one: a chunked body isn't decoded; give the request a Content-Length");
        assert(false);
    }
    let body = full[req.len..min(full.len, req.len + req.body)];
    let short = body.len < req.body;
    let whole = !short && body.len <= cfg.max_head - req.len;
    var keep = req.keep_alive;
    var stream = http::Stream { .. };
    var st = Slot<S> { state: fresh };
    reusable[] var spill: u8[>..] = [];
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: req.minor,
                              head: req.method == "HEAD", stream: stream };
    deliver(http::Event { kind: http::REQUEST, req: req, data: if whole { body } else { "" }, whole: whole,
                          trailers: "" }, st, app, reply, spill) { cx => H(cx) };
    if !whole {
        // goose-http drops the rest of a body once the route has answered.
        var at = 0;
        while at < body.len && (out.len == 0 || stream.open) {
            let end = min(at + cfg.max_head, body.len);
            deliver(http::Event { kind: http::BODY, req: req, data: body[at..end], whole: false, trailers: "" },
                    st, app, reply, spill) { cx => H(cx) };
            at = end;
        }
        deliver(http::Event { kind: if short { http::CLOSED } else { http::END }, req: req, data: "",
                              whole: false, trailers: "" }, st, app, reply, spill) { cx => H(cx) };
    }
    if out.len == 0 { http::refuse(out, 500, ""); }
    return out;
}

// ev handled as serve handles it, with H inside rest::route.
fn deliver<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&) {
    let mark = on_event(ev, st, app, out, spill) { cx => route(cx) { H(cx); }; };
    if st.ex.mode != 0 { on_later(ev, st, app, out, spill, mark) { cx => route(cx) { H(cx); }; }; }
}

// serve_one for a program that keeps no per-request state.
fn serve_one<A, H>(text: const u8[:], app: A&) -> u8[>..] {
    return serve_one(text, app, NoState { .. }) { cx => H(cx) };
}

// serve_one for a program that keeps no state.
fn serve_one<H>(text: const u8[:]) -> u8[>..] {
    var none = NoState { .. };
    return serve_one(text, none, NoState { .. }) { cx => H(cx) };
}

// text with a Host field after its request line, when it's HTTP/1.1 and has
// none.
fn with_host(text: const u8[:]) -> u8[>..] {
    var full: u8[>..] = [];
    let line = find(text, "\r\n");
    let end = find(text, "\r\n\r\n");
    if line < 0 || end < 0 || !ends_with(text[..line], "HTTP/1.1") {
        full.append(text);
        return full;
    }
    let host, found = http::field_in(text[line + 2..end + 2], "Host");
    full.append(text[..line + 2]);
    if !found { full.append("Host: localhost\r\n"); }
    full.append(text[line + 2..]);
    return full;
}
