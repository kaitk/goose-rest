// rest::pause(cx, ms, u) before rest::begin: the handler's answer at
// TIMEOUT, the early 503 when goose-http has no timer, a pause followed by
// a rest::ask that times out (504), the middleware's kept fields on both,
// and 500 already_waiting.
import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";
import expect from "../";

enum Jobs { Slow { ms: i64 } }

enum Use { None, Delay { ms: i64 }, Slow }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Jobs, Use>, calls: i64 = 0 }

let CORS = rest::Cors { origins: "https://a.example", expose: "X-Delay", .. };
let ALLOWED = "Access-Control-Allow-Origin: https://a.example\r\nAccess-Control-Expose-Headers: X-Delay\r\nVary: Origin\r\n";

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Delay, cx) {
    cx.app.calls++;
    guard cx.kind == http::TIMEOUT else { rest::fail(cx, 500, "unexpected_event"); }
    if u.ms < 0 {
        rest::ask(cx, cx.app.to, Jobs.Slow { ms: -u.ms });
    } else {
        rest::text(cx, 200, str(u.ms));
    }
}

fn resume(u: Use.Slow, cx) { resume(rest::job<Jobs>(cx), cx); }

fn resume(u: Jobs.Slow, cx) { rest::text(cx, 200, str("asked ", rest::answer<i64>(cx))); }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    rest::timed(cx, false) {
        rest::cors(cx, CORS) {
            rest::routes(cx) { cx =>
                rest::get(cx, "/delay/:ms") {
                    let ms = rest::param_int(cx, "ms");
                    rest::pause(cx, ms, Use.Delay { ms: ms });
                };
                rest::get(cx, "/then-ask") {
                    rest::pause(cx, 10, Use.Delay { ms: -10 });
                };
                rest::get(cx, "/twice") {
                    rest::pause(cx, 10, Use.Delay { ms: 10 });
                    rest::pause(cx, 10, Use.Delay { ms: 10 });
                };
                rest::get(cx, "/ask-then-pause") {
                    rest::ask(cx, cx.app.to, Jobs.Slow { ms: 10 });
                    rest::pause(cx, 10, Use.Delay { ms: 10 });
                };
            };
        };
    };
}

fn has_timing(out: const u8[:]) -> bool {
    let head = find(out, "\r\nServer-Timing: app;dur=") + 25;
    guard head >= 25 else { return false; }
    let end = find(out[head..], "\r\n");
    return end == 12;
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Jobs>(box, Use.Slow) };
    fn req(target: const u8[:], wakes: const rest::Wake[:]) -> u8[>..] {
        app.calls = 0;
        return rest::serve_one(expect::request("GET", target, "Origin: https://a.example\r\n"), app, St { .. },
                               wakes) { cx => handle(cx); };
    }

    // The handler's answer after the pause, with the middleware's kept fields.
    let ok = req("/delay/25", [rest::Wake { timeout: true }]);
    expect::same(expect::status_of(ok), "HTTP/1.1 200 OK", "delayed 200");
    expect::same(expect::body_of(ok), "25", "delayed body");
    assert(find(ok, ALLOWED) >= 0 && has_timing(ok) && app.calls == 1);

    // goose-http's TIMEOUT at once, when it has no timer: 503 with
    // Retry-After, and the handler isn't called.
    let early = req("/delay/25", [rest::Wake { timeout: true, early: true }]);
    expect::same(expect::status_of(early), "HTTP/1.1 503 Service Unavailable", "early 503");
    expect::same(expect::body_of(early), "{\"error\":\"unavailable\"}", "early body");
    assert(find(early, "\r\nRetry-After: 1\r\n") >= 0 && find(early, ALLOWED) >= 0 && has_timing(early) && app.calls == 0);

    // A pause followed by a rest::ask that times out: PAUSED was cleared, so
    // the second TIMEOUT answers 504, not the pause's resume.
    let late = req("/then-ask", [rest::Wake { timeout: true }, rest::Wake { timeout: true }]);
    expect::same(expect::status_of(late), "HTTP/1.1 504 Gateway Timeout", "ask timeout after pause");
    expect::same(expect::body_of(late), "{\"error\":\"timeout\"}", "ask timeout body");
    assert(find(late, ALLOWED) >= 0 && has_timing(late) && app.calls == 1);

    // And when the ask after the pause gets its reply.
    let reply = rest::play(app.to, Jobs.Slow { ms: 10 }) { u, a => rest::reply_value(a, 42); };
    let asked = req("/then-ask", [rest::Wake { timeout: true }, rest::wake(reply)]);
    expect::same(expect::status_of(asked), "HTTP/1.1 200 OK", "ask reply after pause");
    expect::same(expect::body_of(asked), "asked 42", "ask reply body");
    assert(find(asked, ALLOWED) >= 0 && has_timing(asked));

    // already_waiting: a second pause, or a pause after rest::ask.
    let twice = req("/twice", []);
    expect::same(expect::status_of(twice), "HTTP/1.1 500 Internal Server Error", "twice status");
    expect::same(expect::body_of(twice), "{\"error\":\"already_waiting\"}", "twice body");
    let ask_pause = req("/ask-then-pause", []);
    expect::same(expect::status_of(ask_pause), "HTTP/1.1 500 Internal Server Error", "ask then pause status");
    expect::same(expect::body_of(ask_pause), "{\"error\":\"already_waiting\"}", "ask then pause body");

    // And not_served outside serve and serve_one.
    let parsed, status = http::parse("GET / HTTP/1.1\r\nHost: x\r\n\r\n");
    assert(status == 200);
    var buf: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = St { .. };
    var scratch: u8[>..] = [];
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<St, App, rest::NoRouter> {
        req: parsed, body: "", out: http::Reply { buf: buf, common: "", keep_alive: keep, minor: 1, head: false, stream: stream },
        state: st, app: app, scratch: scratch, router: none,
    };
    rest::route(cx) { rest::pause(cx, 10, Use.Delay { ms: 10 }); };
    expect::same(expect::body_of(buf), "{\"error\":\"not_served\"}", "not served");

    http::mail_close(box);
    print("pause before begin: ok");
}
