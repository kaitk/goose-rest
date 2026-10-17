// Answering a request's bytes without a socket, as serve answers them, for
// tests that run in-process.

namespace rest;

import std;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";

// What serve answers to text, one request's bytes, through H(cx) inside
// rest::route: the status line, the fields, and the body, without Date or
// Server. app is the worker state, fresh the request state, cfg the
// limits goose-http applies, and limits goose-rest's. A body that doesn't
// fit in cfg.max_head with its head comes in pieces of cfg.max_head bytes:
// gathered as serve gathers it, within limits.gather_budget, so H runs
// again once it's whole if it called rest::body, or passed on
// to a route that called rest::body_in_pieces. A body shorter than its
// Content-Length is a client that hung up midway: its pieces come, then
// http::CLOSED in place of http::END. A response sent in pieces
// (rest::begin) is taken to its end, H called with http::MORE as for a
// client that keeps up. The bytes after the head of a request that
// rest::upgrade answered are what its client sends: they come as one
// http::BODY once the route doesn't wait, then http::CLOSED, as the client
// closing. An HTTP/1.1 request
// without Host is given "Host: localhost". A request goose-http refuses gets
// its refusal, and H that doesn't answer 500, as from the server. A route
// that waits (rest::ask) gets no reply here: see the serve_one below.
fn serve_one<A, S, H>(text: const u8[:], app: A&, fresh: S, cfg: http::Config = http::Config { .. },
                      limits: Config = Config { .. }) -> u8[>..] {
    return serve_one(text, app, fresh, [], cfg, limits) { cx => H(cx) };
}

// What serve_one gives a route that waits, in place of the thread it asked:
// data with tag, as rest::reply sends them, or with timeout, the end of the
// wait, which rest::ask answers with 504, and rest::pause's route gets as
// http::TIMEOUT. early makes that timeout goose-http's own, given at once
// when it has no timer: a pause then ends its response. A flat value's
// data is rest::value_bytes of it. sent is what the client of an upgraded
// connection sends while the route waits, which comes as one http::BODY
// before the reply or the timeout; on any other connection, goose-http
// holds it back, and serve_one drops it.
struct Wake { data: const u8[:] = "", tag: i32 = 0, timeout: bool = false, early: bool = false, sent: const u8[:] = "" }

// serve_one, with wakes for the waits of the route, one each, in order: H is
// called again with each, as serve calls it with a reply that comes, in
// pieces of cfg.mail_size bytes, or with the timeout. A piece that comes
// once the route no longer waits is dropped, as serve drops it. A wait with
// no wake left ends the exchange with what the route wrote so far, or 500
// if nothing; one with a response open is a client that goes, and H gets
// http::CLOSED.
//
//   let reply = rest::value_bytes(database::AssignReply { .. });
//   let out = rest::serve_one(text, app, St { .. }, [rest::Wake { data: reply }]) { cx => handle(cx) };
fn serve_one<A, S, H>(text: const u8[:], app: A&, fresh: S, wakes: const Wake[:],
                      cfg: http::Config = http::Config { .. }, limits: Config = Config { .. }) -> u8[>..] {
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
    var runs: Run[>..] = [];
    var budget = Budget { size: limits.gather_budget, runs: runs };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: req.minor,
                              head: req.method == "HEAD", stream: stream };
    deliver(http::Event { kind: http::REQUEST, req: req, data: if whole { body } else { "" }, whole: whole,
                          trailers: "" }, st, app, reply, spill, budget) { cx => H(cx) };
    if !whole {
        // goose-http drops the rest of a body once the route has answered.
        var at = 0;
        while at < body.len && (out.len == 0 || stream.open) {
            let end = min(at + cfg.max_head, body.len);
            deliver(http::Event { kind: http::BODY, req: req, data: body[at..end], whole: false, trailers: "" },
                    st, app, reply, spill, budget) { cx => H(cx) };
            at = end;
        }
        deliver(http::Event { kind: if short { http::CLOSED } else { http::END }, req: req, data: "",
                              whole: false, trailers: "" }, st, app, reply, spill, budget) { cx => H(cx) };
    }
    // MORE while a response is open, as the loop calls it for a client that
    // keeps up. A MORE that neither sends nor ends closes the connection, as
    // the loop closes it, and so does an upgraded connection's client here,
    // once it has sent the bytes after the request's head.
    let none = http::Event { kind: http::MORE, req: req, data: "", whole: false, trailers: "" };
    let gone = http::Request { .. };
    let piece = max(cfg.mail_size as i64, 1);
    let after = full[min(full.len, req.len + req.body)..];
    var sent_after = false;
    var next = 0;
    loop {
        while stream.open && !stream.waiting {
            let before = out.len;
            stream.moved = false;
            let raw = stream.framing == http::Framing.Raw;
            if raw && !sent_after && after.len > 0 {
                sent_after = true;
                deliver(http::Event { kind: http::BODY, req: gone, data: after, whole: false, trailers: "" },
                        st, app, reply, spill, budget) { cx => H(cx) };
                continue;
            }
            if !raw {
                deliver(none, st, app, reply, spill, budget) { cx => H(cx) };
            }
            if raw || (out.len == before && !stream.moved && stream.open && !stream.waiting) {
                deliver(http::Event { kind: http::CLOSED, req: req, data: "", whole: false, trailers: "" },
                        st, app, reply, spill, budget) { cx => H(cx) };
                break;
            }
        }
        guard stream.waiting && next < wakes.len else { break; }
        let w = wakes[next];
        next++;
        if w.sent.len > 0 && stream.framing == http::Framing.Raw {
            deliver(http::Event { kind: http::BODY, req: gone, data: w.sent, whole: false, trailers: "" },
                    st, app, reply, spill, budget) { cx => H(cx) };
            // An end, or a failure that cut the connection, stops the wait,
            // as goose-http stops it.
            if !stream.open {
                stream.waiting = false;
                stream.rearm = false;
                continue;
            }
        }
        if w.timeout {
            stream.waiting = false;
            stream.rearm = false;
            // The time a rest::pause asked for has come, or with early hasn't.
            st.ex.due = if w.early { 1 << 62 } else { 0 };
            deliver(http::Event { kind: http::TIMEOUT, req: gone, data: "", whole: false, trailers: "" },
                    st, app, reply, spill, budget) { cx => H(cx) };
            continue;
        }
        var at = 0;
        var tag = w.tag & REPLY_TAG;
        while stream.waiting {
            let end = min(at + piece, w.data.len);
            let more = end < w.data.len;
            stream.waiting = false;
            stream.rearm = false;
            deliver(http::Event { kind: http::WAKE, req: gone, data: w.data[at..end], whole: false, trailers: "",
                                  tag: if more { tag | REPLY_MORE } else { tag } },
                    st, app, reply, spill, budget) { cx => H(cx) };
            guard more else { break; }
            at = end;
            tag = REPLY_CONT;
        }
    }
    // A response still open with no wake left is a client that goes.
    if stream.open && stream.waiting {
        stream.waiting = false;
        stream.rearm = false;
        deliver(http::Event { kind: http::CLOSED, req: gone, data: "", whole: false, trailers: "" },
                st, app, reply, spill, budget) { cx => H(cx) };
    }
    if out.len == 0 { http::refuse(out, 500, ""); }
    return out;
}

// ev handled as serve handles it, with H inside rest::route.
fn deliver<S, A, H>(ev: http::Event, st: Slot<S>&, app: A&, out: http::Reply, spill: u8[>..]&, budget: Budget&) {
    let mark = on_event(ev, st, app, out, spill, budget) { cx => route(cx) { H(cx); }; };
    if (st.ex.mode & LATER) != 0 { on_later(ev, st, app, out, spill, budget, mark) { cx => route(cx) { H(cx); }; }; }
}

// serve_one for a program that keeps no request state.
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
