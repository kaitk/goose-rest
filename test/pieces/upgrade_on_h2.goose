// rest::upgrade on an HTTP/2 stream, which can't switch protocols:
// goose-http answers 501, and the route gets no later call, CLOSED
// included, as for any answer at the request.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../";
import expect from "../";

enum Use { None, Echo }

struct St { use: Use = Use.None }

struct App { log: u8[>..]& }

fn resume(u: Use.None, cx) { cx.app.log.append("none "); }

fn resume(u: Use.Echo, cx) { format(cx.app.log, "kind ", cx.kind, " "); }

fn main() {
    let text = "GET /up HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n";
    let req, status = http::parse(text);
    assert(status == 200);
    var log: u8[>..] = [];
    var app = App { log: log };
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<St> { state: St { .. } };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: http::H2_MINOR, head: false,
                              stream: stream };
    rest::deliver(http::Event { kind: http::REQUEST, req: req, data: "", whole: true, trailers: "" }, st, app, reply) { cx =>
        if rest::resumed(cx) { resume(cx.state.use, cx); } else { rest::upgrade(cx, "echo", Use.Echo); }
    };
    expect::same(expect::status_of(out), "HTTP/1.1 501 Not Implemented", "h2's answer");
    expect::same(log, "", "the route's later calls");
    assert(st.ex.mode == 0);
    print("rest::upgrade on h2: ok");
}
