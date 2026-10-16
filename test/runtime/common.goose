// What the runtime's tests share: a context to call a handler with, and a
// project that a route loads through two calls that may fail.
import std;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../";
import expect from "../";

struct Project { id: i64, name: const u8[:] }

fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    http::json_string(out, p.name);
    out.push('}');
}

// Calls H with a context for text, a whole request, and compares what it
// wrote with want and then more.
fn answers<H>(text: const u8[:], want: const u8[:], more: const u8[:] = "") {
    let req, status = http::parse(text);
    assert(status == 200);
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    let body = text[req.len..];
    var scratch: u8[>..] = [];
    var app = rest::NoState { .. };
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<rest::NoState, rest::NoState, rest::NoRouter> { req: req, body: body, out: http::Reply { buf: out,
                        common: "", keep_alive: keep, minor: 1, head: false, stream: st }, state: state, app: app,
                        scratch: scratch, router: none };
    H(cx);
    expect::same(out, str(want, more));
}

fn find(cx, id: i64) -> Project {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    return Project { id: id, name: "goose \"one\"" };
}

fn load(cx, id: i64) -> Project {
    let p = find(cx, id);
    guard p.id != 13 else { rest::fail(cx, 403, str("forbidden_", p.id)); }
    return p;
}

let GET = "GET /p HTTP/1.1\r\nHost: x\r\n\r\n";
