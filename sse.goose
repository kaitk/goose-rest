// Server-Sent Events over the ordinary response stream.
namespace plod;

import std;
import http from "github.com/kaitk/goose-http@v0.5.6";

// A 200 event stream, with u in cx.state.use as for begin. Pause it with
// plod::pause and finish it with plod::end.
fn sse_begin<S, A, R>(cx: Cx<S, A, R>&, u) {
    let common = cx.out.common;
    let at = cx.scratch.len;
    cx.scratch.append(common);
    cx.scratch.append("Cache-Control: no-cache\r\nX-Accel-Buffering: no\r\n");
    cx.out.common = cx.scratch[at..];
    begin(cx, 200, "text/event-stream", -1, u);
    cx.out.common = common;
}

// One complete event. A name containing CR or LF writes nothing and
// returns false; an empty name leaves the browser's default event type.
fn sse_event(cx, event: const u8[:], data: const u8[:]) -> bool {
    guard position(event, '\r') < 0 && position(event, '\n') < 0 else { return false; }
    var frame: u8[>..] = [];
    if event.len > 0 { format(frame, "event: ", event, "\n"); }
    sse_lines(frame, "data: ", data);
    frame.push('\n');
    send(cx, frame);
    return true;
}

fn sse_data(cx, data: const u8[:]) { sse_event(cx, "", data); }

// The same format overload plod::json uses must write JSON for v.
fn sse_json(cx, v, event: const u8[:] = "") -> bool {
    var data: u8[>..] = [];
    format(data, v);
    return sse_event(cx, event, data);
}

// A comment keeps the connection active without dispatching an event.
fn sse_comment(cx, text: const u8[:] = "") {
    var frame: u8[>..] = [];
    sse_lines(frame, ": ", text);
    frame.push('\n');
    send(cx, frame);
}

// The browser's reconnect delay in milliseconds. Negative values write
// nothing and return false.
fn sse_retry(cx, ms: i64) -> bool {
    guard ms >= 0 else { return false; }
    send(cx, str("retry: ", ms, "\n\n"));
    return true;
}

// SSE recognizes LF, CRLF, and bare CR. Prefix every line, including an
// empty last one, so data cannot inject another field or end an event.
fn sse_lines(out: u8[>..]&, prefix: const u8[:], text: const u8[:]) {
    var start = 0;
    var i = 0;
    while i < text.len {
        if text[i] == '\r' || text[i] == '\n' {
            format(out, prefix, text[start..i], "\n");
            if text[i] == '\r' && i + 1 < text.len && text[i + 1] == '\n' { i++; }
            start = i + 1;
        }
        i++;
    }
    format(out, prefix, text[start..], "\n");
}
