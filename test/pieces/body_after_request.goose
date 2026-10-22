// rest::body and rest::body_in_pieces at a later call, after a pause, for a
// body that didn't come with its head: both fail with 500 body_too_late,
// since the head a gathering needs has gone, rather than read a body cut
// short. Event by event, as goose-http gives them: the body's pieces come
// once the wait has ended.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";
import expect from "../";

enum Use { None, Paused, Upload }

struct St { use: Use = Use.None, size: i64 = 0, read: bool = false }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        rest::route(cx) {
            cx.state.read = cx.req.target == "/whole";
            rest::pause(cx, 5, Use.Paused);
        };
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Paused, cx) {
    if cx.state.read {
        let body = rest::body(cx);
        rest::text(cx, 200, str(body.len));
    } else {
        rest::body_in_pieces(cx, 1 << 20, Use.Upload);
    }
}

fn resume(u: Use.Upload, cx) {
    if cx.kind == http::BODY {
        cx.state.size += cx.body.len;
    } else if cx.kind == http::END {
        rest::text(cx, 201, str(cx.state.size));
    }
}

// What the route answers to a POST to target of a body of 300 bytes, which
// comes after its head in two pieces once the pause has ended.
fn answered(target: const u8[:]) -> u8[>..] {
    let text = str("POST ", target, " HTTP/1.1\r\nHost: x\r\nContent-Length: 300\r\n\r\n");
    let req, status = http::parse(text);
    assert(status == 200);
    var body: u8[>..] = [];
    for i in 300 { body.push('a'); }
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<St> { state: St { .. } };
    var app = rest::NoState { .. };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: stream };
    fn send(kind: u8, data: const u8[:], whole: bool) {
        rest::deliver(http::Event { kind: kind, req: req, data: data, whole: whole, trailers: "" }, st, app, reply)
            { cx => handle(cx); };
    }
    send(http::REQUEST, "", false);
    stream.waiting = false;
    stream.rearm = false;
    send(http::TIMEOUT, "", false);
    if out.len == 0 {
        send(http::BODY, body[..100], false);
        send(http::BODY, body[100..], false);
        send(http::END, "", false);
    }
    return out;
}

fn main() {
    let pieces = answered("/pieces");
    expect::same(expect::status_of(pieces), "HTTP/1.1 500 Internal Server Error", "body_in_pieces after a pause");
    expect::same(expect::body_of(pieces), "{\"error\":\"body_too_late\"}", "body_in_pieces' code");
    let whole = answered("/whole");
    expect::same(expect::status_of(whole), "HTTP/1.1 500 Internal Server Error", "body after a pause");
    expect::same(expect::body_of(whole), "{\"error\":\"body_too_late\"}", "body's code");
    print("rest::body and rest::body_in_pieces after the request: ok");
}
