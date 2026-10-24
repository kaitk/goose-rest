import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import common;

struct Update { text: u8[], n: i64 }
fn format(out: u8[>..]&, v: const Update&) { plod::format_fields(out, v); }

fn main() {
    expect::same(frame() { cx => plod::sse_data(cx, "one\n\ntwo\n"); },
                 "data: one\ndata: \ndata: two\ndata: \n\n", "LF and empty lines");
    expect::same(frame() { cx => plod::sse_data(cx, "one\r\ntwo\rthree\r\n"); },
                 "data: one\ndata: two\ndata: three\ndata: \n\n", "CRLF and CR");
    expect::same(frame() { cx => plod::sse_data(cx, ""); }, "data: \n\n", "empty data");
    expect::same(frame() { cx => assert(plod::sse_event(cx, "update", "first\nsecond")); },
                 "event: update\ndata: first\ndata: second\n\n", "named event");
    expect::same(frame() { cx => assert(plod::sse_event(cx, "", "default")); },
                 "data: default\n\n", "default event");
    expect::same(frame() { cx =>
        assert(!plod::sse_event(cx, "bad\nevent", "ignored"));
        assert(!plod::sse_event(cx, "bad\revent", "ignored"));
        plod::sse_data(cx, "\nevent: still data");
    }, "data: \ndata: event: still data\n\n", "field injection");
    expect::same(frame() { cx => plod::sse_comment(cx); }, ": \n\n", "empty heartbeat");
    expect::same(frame() { cx => plod::sse_comment(cx, "alive\r\nretry: 0\n"); },
                 ": alive\n: retry: 0\n: \n\n", "comment lines");
    expect::same(frame() { cx =>
        assert(plod::sse_retry(cx, 2500));
        assert(plod::sse_retry(cx, 0));
        assert(!plod::sse_retry(cx, -1));
    }, "retry: 2500\n\nretry: 0\n\n", "retry");
    expect::same(frame() { cx =>
        assert(plod::sse_json(cx, Update { text: "hello\nworld", n: 7 }, "update"));
        assert(plod::sse_json(cx, Update { text: "ok", n: 8 }));
    }, "event: update\ndata: {\"text\":\"hello\\nworld\",\"n\":7}\n\ndata: {\"text\":\"ok\",\"n\":8}\n\n", "JSON writer");
    print("SSE frames: ok");
}
