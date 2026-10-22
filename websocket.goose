// rest::ws_upgrade and rest::ws_read, a WebSocket (RFC 6455) on a route,
// with goose-http's http.websocket. Only a program that imports this module
// needs goose-hash, which its root file declares at the tag goose-http's
// websocket.goose names:
//
//   import http from "github.com/kaitk/goose-http@v0.5.2";
//   import hash from "github.com/kaitk/goose-hash@v0.0.4";
//   import rest from "github.com/kaitk/goose-rest@<tag>";
//   import rest.websocket;
//
// The program keeps the connection's http::WebSocket in its request state,
// and sends with http::ws_send and http::ws_close on cx.out.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import http.websocket;

// Answers a request to open a WebSocket with 101 (http::ws_switch), with u
// in cx.state.use: the connection then carries frames into ws, which
// rest::ws_read reads at each later call, as for rest::upgrade. With
// protocol, the 101 names it in Sec-WebSocket-Protocol;
// http::field_of(cx.req, "sec-websocket-protocol") gives those the client
// offered. Set ws.limit before it: http::ws_admit promises ws that many
// bytes of the worker's gather pool, and WS_SLACK. Refusals, in the
// program's error shape, leave the route: 426 upgrade_required with the
// fields http::ws_check gives; 400 bad_handshake, and for a protocol that
// http::is_field refuses, as http::ws_upgrade answers it; 501
// not_implemented on an HTTP/2 stream; and 503 unavailable with
// Retry-After where the budget can't promise ws its bytes.
fn ws_upgrade<S, A, R>(cx: Cx<S, A, R>&, ws: http::WebSocket&, u, protocol: const u8[:] = "") {
    var status, key, fields = http::ws_check(cx.req, cx.out.minor);
    if status == 101 && protocol.len > 0 && !http::is_field("Sec-WebSocket-Protocol", protocol) { status = 400; }
    if status == 101 && !http::ws_admit(ws) {
        status = 503;
        fields = "Retry-After: 1\r\n";
    }
    guard status == 101 else {
        let code = if status == 426 { "upgrade_required" }
                   else if status == 400 { "bad_handshake" }
                   else if status == 501 { "not_implemented" }
                   else { "unavailable" };
        var body: u8[>..] = [];
        error_body(body, cx.state, status, code, "", -1);
        http::start(cx.out, status);
        cx.out.buf.append(fields);
        http::finish(cx.out, error_type(cx.state), body);
        fail(cx, status, code);   // the first answer wins: this leaves the route
    }
    http::ws_switch(cx.out, key, protocol);
    upgraded(cx, u);
}

// The case function's work for a WebSocket rest::ws_upgrade opened: at
// http::BODY, reads the frames cx.body completes (http::ws_take) and calls
// F(op, data) with each whole message, op http::WS_TEXT or WS_BINARY, data
// lasting until F returns; at http::CLOSED, gives back what ws holds. A
// ping, a Close, and a frame the protocol forbids are answered without F,
// and a Close closes the connection, after which the route gets CLOSED.
// Other kinds, as TIMEOUT, are the case function's.
fn ws_read<S, A, R, F>(cx: Cx<S, A, R>&, ws: http::WebSocket&) {
    if cx.kind == http::BODY {
        http::ws_take(cx.body, ws, cx.out) { op, data, o => F(op, data); };
    } else if cx.kind == http::CLOSED {
        http::ws_release(ws);
    }
}
