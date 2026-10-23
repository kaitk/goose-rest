// A program's plod::error_body overload for its per-request state, which
// shapes every error answer: a failure's and plod::otherwise's.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import expect from "../";
import common;

// A program's per-request state, whose error_body overload adds the status.
struct Shaped { unused: bool = false }

fn plod::error_body(body: u8[>..]&, st: const Shaped&, status: i32, code: const u8[:], detail: const u8[:],
                    at: i64) {
    body.append("{\"error\":");
    http::json_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    body.push('}');
}

// answers, with Shaped as the per-request state.
fn shaped<H>(text: const u8[:], want: const u8[:], more: const u8[:]) {
    let req, status = http::parse(text);
    assert(status == 200);
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = Shaped { .. };
    var scratch: u8[>..] = [];
    var app = plod::NoState { .. };
    var none = plod::NoRouter { .. };
    var cx = plod::Cx<Shaped, plod::NoState, plod::NoRouter> { req: req, body: text[req.len..], out: http::Reply {
                 buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: st }, state: state, app: app,
                 scratch: scratch, router: none };
    H(cx);
    expect::same(out, str(want, more));
}

fn main() {
    shaped(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 42\r\n\r\n",
                "{\"error\":\"project_not_found\",\"status\":404}") { cx =>
        plod::route(cx) { plod::json(cx, 200, load(cx, 0)); };
    };
    shaped(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                "{\"error\":\"not_found\",\"status\":404}") { cx =>
        plod::routes(cx) { cx => plod::get(cx, "/q") { plod::text(cx, 200, "q"); }; };
    };
    print("a program's plod::error_body: ok");
}
