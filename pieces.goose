// Bodies and responses in pieces, and upgraded connections: a route that
// reads its body as it arrives (body_in_pieces), sends its response as the client
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
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";

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
fn body_in_pieces<S, A, R>(cx: Cx<S, A, R>&, limit: i64, w) {
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

// Begins a response sent in pieces, with status, a Content-Type of
// content_type unless it's empty, and a body of length bytes, or -1 for one
// of a length not known yet, chunked. w goes in cx.state.waiting, and the
// handler is called again with http::MORE each time the client has taken
// what was sent, and sends the next piece with rest::send, until rest::end.
// A piece of about 16 KB each time keeps within Config.max_queued. A
// handler that neither sends nor ends at MORE closes the connection. The
// handler gets http::CLOSED once if the response ends otherwise: when the
// client goes, or when the route fails with it open, which cuts it short
// (rest::route). A HEAD request, or a status without a body, gets the head
// alone, and no calls. Begun after rest::body_in_pieces, the pieces of the body
// still come, then MORE once it has ended. Inside rest::compressed, a
// response of a type worth compressing is compressed (compression.goose).
fn begin<S, A, R>(cx: Cx<S, A, R>&, status: i32, content_type: const u8[:], length: i64, w) {
    var x .= cx.ex;
    var begun = false;
    if x { begun = begin_coded(x, cx.out, cx.req, status, content_type, length); }
    if !begun {
        http::begin(cx.out, status, length);
        if content_type.len > 0 { http::field(cx.out, "Content-Type", content_type); }
    }
    if cx.out.head || cx.out.stream.bodyless {
        http::end(cx.out);
        return;
    }
    cx.state.waiting = w;
    guard x else { return; }
    x.mode |= SENDING;
}

// Pauses the response rest::begin began for ms milliseconds, for events
// sent over time, such as Server-Sent Events: the handler is called again
// with http::TIMEOUT then, the response still open, and sends the next
// piece, pauses again, or ends. What was sent before still goes to the
// client meanwhile, and no MORE comes until the pause ends. A TIMEOUT call
// that neither pauses nor ends gets MORE once the client has taken what it
// sent. A client that goes meanwhile ends the pause, and the handler gets
// http::CLOSED. Needs Config.mail_slots and max_waiting, as rest::ask does.
// Past max_waiting, goose-http has no timer for the pause, and gives
// TIMEOUT at once: goose-rest tells it from the pause's own by the clock,
// and ends the response, and the handler gets CLOSED. 500 not_sending
// without a response begun and open, and 500 not_served outside serve and
// serve_one.
fn pause<S, A, R>(cx: Cx<S, A, R>&, ms: i64) {
    var x .= cx.ex;
    guard x else { fail(cx, 500, "not_served"); }
    guard (x.mode & SENDING) != 0 && cx.out.stream.open else { fail(cx, 500, "not_sending"); }
    // goose-http's timer falls due by its loop's clock, which can lag this
    // one: a TIMEOUT halfway to its time is the pause's.
    x.due = clock_ns() + max(ms, 0) * 500000;
    http::later(cx.out, ms);
}

// Sends data, the next piece of the response rest::begin began, or bytes as
// they are on a connection rest::upgrade took.
fn send(cx, data: const u8[:]) {
    var x .= cx.ex;
    if x {
        if (x.mode & CODED) != 0 {
            send_coded(x, cx.out, data);
            return;
        }
    }
    http::send(cx.out, data);
}

// Ends the response rest::begin began, with trailers when it's chunked
// (http::end), or closes a connection rest::upgrade took. The route has
// finished: it gets no more calls, CLOSED included.
fn end<S, A, R>(cx: Cx<S, A, R>&, trailers: const u8[:] = "") {
    var x .= cx.ex;
    guard x else {
        http::end(cx.out, trailers);
        return;
    }
    if (x.mode & CODED) != 0 { end_coded(x, cx.out, trailers); } else { http::end(cx.out, trailers); }
    x.mode &= KEPT;
}

// What a response rest::begin begins inside rest::compressed does: these
// leave it as written. rest.compression overloads them for an Exchange, and
// where a program imports it, its overloads win, as a concrete match does
// over a generic one (spec §7.1), so that the core neither imports
// goose-compress nor keeps a byte for it. begin_coded returns whether it
// began the response; the others run only for one it began with an encoder
// (CODED), at each rest::send, at rest::end, and at CLOSED.
fn begin_coded(x, out: http::Reply, req: const http::Request&, status: i32, content_type: const u8[:],
               length: i64) -> bool {
    return false;
}

fn send_coded(x, out: http::Reply, data: const u8[:]) { http::send(out, data); }

fn end_coded(x, out: http::Reply, trailers: const u8[:]) { http::end(out, trailers); }

fn release_coded(x, fd: i32) {}

// Answers a GET or HEAD with the file at path, as http::serve_file does:
// 200, 206 for a range, 304 when the request's validators match, or 416,
// with ETag, Last-Modified, and Accept-Ranges, and a Content-Type of
// content_type, or by path's extension when it's empty
// (http::content_type_of). body, a field of the request state, holds
// what is left to send, and w goes in cx.state.waiting: the case function
// calls rest::send_file(cx, body) for each call, which sends the rest and
// closes the file. A response with nothing to send, as for HEAD or 304,
// gets no calls. Fails with 404 file_not_found for no file, or a
// directory, at path, 403 forbidden where reading it isn't allowed, and 500
// file_unreadable. Inside rest::compressed, the file goes as it is: coded on
// the fly, it would lose its Content-Length, its ranges, and the loop's
// sendfile.
fn file<S, A, R>(cx: Cx<S, A, R>&, path: const u8[:], body: http::FileBody&, w, content_type: const u8[:] = "") {
    let f, status = http::open_file(path);
    if status == 404 { fail(cx, 404, "file_not_found"); }
    if status == 403 { fail(cx, 403, "forbidden"); }
    if status != 200 { fail(cx, 500, "file_unreadable"); }
    http::serve_file(cx.req, cx.out, f, if content_type.len > 0 { content_type } else { http::content_type_of(path) },
                     body);
    guard cx.out.stream.open else { return; }
    cx.state.waiting = w;
    var x .= cx.ex;
    guard x else { return; }
    x.mode |= SENDING;
}

// Answers 101 and switches the connection to protocol (http::upgrade), with
// w in cx.state.waiting. The handler is called again with http::BODY and the
// client's bytes in cx.body as they arrive, with no END and no limit, and
// writes with rest::send, bytes as they are, until rest::end closes the
// connection. It gets http::CLOSED once if the client closes first, or the
// route fails. http::upgrade_of(cx.req) says what the request asks to switch
// to. A route that then waits on another thread (rest::ask) gets the bytes
// that come meanwhile in the case function of the ask's variant, and sets
// cx.state.waiting back to w's to get them where they went before.
fn upgrade<S, A, R>(cx: Cx<S, A, R>&, protocol: const u8[:], w) {
    http::upgrade(cx.out, protocol);
    cx.state.waiting = w;
    var x .= cx.ex;
    guard x else { return; }
    x.mode |= UPGRADED;
}

// The case function's work for a file rest::file answered: at http::MORE,
// sends the next piece of body, and ends the response after the last; at
// http::CLOSED, closes the file.
fn send_file<S, A, R>(cx: Cx<S, A, R>&, body: http::FileBody&) {
    if cx.kind == http::MORE {
        if !http::send_file(cx.out, body) { end(cx); }
    } else if cx.kind == http::CLOSED {
        http::close_body(body);
    }
}
