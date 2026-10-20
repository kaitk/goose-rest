// What the middleware's tests share: a context to call a handler with, and
// a route behind CORS and Server-Timing that answers at a later call: at
// WAKE, at TIMEOUT, or at a body's END.
import std;
import http from "github.com/kaitk/goose-http@v0.4.2";
import rest from "../../";
import expect from "../";

// Calls H with a context for text, a whole request, and returns what it
// wrote.
fn answer<H>(text: const u8[:]) -> u8[>..] {
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    var scratch: u8[>..] = [];
    var app = rest::NoState { .. };
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<rest::NoState, rest::NoState, rest::NoRouter> { req: req, body: text[req.len..],
                                       out: http::Reply { buf: out, common: "", keep_alive: keep, minor: 1,
                                       head: req.method == "HEAD", stream: st }, state: state, app: app,
                                       scratch: scratch, router: none };
    H(cx);
    return out;
}

let OK = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok";

// The jobs of the lane the route asks, and what the route waits on.
enum Reports { Report }

enum Use { None, Report, Upload }

struct St { use: Use = Use.None, size: i64 = 0 }

type Lane = rest::Lane<Reports, Use>;

let CORS = rest::Cors { origins: "https://a.example", expose: "X-Total", .. };

let ALLOWED = "Access-Control-Allow-Origin: https://a.example\r\nAccess-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n";

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Report, cx) { resume(rest::job<Reports>(cx), cx); }

fn resume(u: Reports.Report, cx) { rest::text(cx, 200, str("got ", rest::answer<i64>(cx))); }

// The lane's reply to the report, 42.
fn reported(to: const Lane&) -> rest::Played {
    return rest::play(to, Reports.Report) { u, a => rest::reply_value(a, 42); };
}

fn resume(u: Use.Upload, cx) {
    if cx.kind == http::BODY { cx.state.size += cx.body.len; }
    else if cx.kind == http::END { rest::text(cx, 201, str(cx.state.size)); }
}

// The route of what, behind the middleware of which: "cors", "timed", or
// both, timed outside. "ask" asks to, "upload" reads its body in pieces, and
// "gathered" asks once rest::body has the body whole.
fn later_route(cx, what: const u8[:], which: const u8[:], to: const Lane&) {
    fn inner() {
        rest::route(cx) {
            if what == "upload" {
                rest::body_in_pieces(cx, 1 << 20, Use.Upload);
            } else {
                if what == "gathered" { rest::body(cx); }
                rest::ask(cx, to, Reports.Report);
            }
        };
    }
    if which == "cors" {
        rest::cors(cx, CORS) { inner(); };
    } else if which == "timed" {
        rest::timed(cx, false) { inner(); };
    } else {
        rest::timed(cx, false) { rest::cors(cx, CORS) { inner(); }; };
    }
}

// Checks out's Server-Timing, after its status line and the loop's fields:
// a value of at least least milliseconds, padded. Returns what follows it.
fn timing_in(out: const u8[:], least: i64) -> const u8[:] {
    let head = find(out, "\r\nServer-Timing: app;dur=") + 25;
    assert(head >= 25);
    let end = find(out[head..], "\r\n");
    assert(end == 12);
    let dur = out[head..head + find(out[head..], " ")];
    let ms, ok = parse_int(dur[..find(dur, ".")]);
    assert(ok && ms >= least);
    return out[head + end + 2..];
}
