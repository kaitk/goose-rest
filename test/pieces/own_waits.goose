// plod::own_waits: a route that waits itself, as on a socket, gets the WAKE,
// the TIMEOUT, goose-http's TIMEOUT at once included, and the CLOSED of a
// client that goes, in its resume, while a lane's wait still gets Plod's
// 504. serve_one gives a wait no socket, so the route waits with
// http::later, the wait http::wait_socket begins too.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";
import expect from "../";

enum Jobs { Slow }

enum Use { None, Socket, Asked }

struct St { use: Use = Use.None, wakes: i64 = 0 }

// What the case functions saw, in order: W and the WAKE's bytes, T, C.
struct App { to: plod::Lane<Jobs, Use>, log: u8[>..]& }

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

// The first WAKE waits again, as a query does between its socket's steps.
fn resume(u: Use.Socket, cx) {
    if cx.kind == http::WAKE {
        format(cx.app.log, "W", cx.reply, " ");
        cx.state.wakes++;
        if cx.state.wakes == 1 {
            http::later(cx.out, 50);
        } else {
            plod::text(cx, 200, str("woke ", cx.reply));
        }
    } else if cx.kind == http::TIMEOUT {
        cx.app.log.append("T ");
        plod::json_bytes(cx, 200, "{\"items\":[],\"count\":0}");
    } else if cx.kind == http::CLOSED {
        cx.app.log.append("C ");
        plod::text(cx, 200, "nowhere");
    }
}

fn resume(u: Use.Asked, cx) {
    format(cx.app.log, "A", cx.kind, " ");
    resume(plod::job<Jobs>(cx), cx);
}

fn resume(u: Jobs.Slow, cx) { plod::text(cx, 200, "asked"); }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    plod::routes(cx) { cx =>
        plod::get(cx, "/socket") {
            plod::own_waits(cx, Use.Socket);
            http::later(cx.out, 50);
        };
        plod::get(cx, "/ask") { plod::ask(cx, cx.app.to, Jobs.Slow); };
    };
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var log: u8[>..] = [];
    var app = App { to: plod::lane_of<Jobs>(box, Use.Asked), log: log };
    fn req(target: const u8[:], wakes: const plod::Wake[:]) -> u8[>..] {
        return plod::serve_one(expect::request("GET", target), app, St { .. }, wakes) { cx => handle(cx); };
    }

    // Two WAKEs, the socket ready twice: the route waits again at the first.
    let woke = req("/socket", [plod::Wake { data: "1", tag: http::SOCKET_READY },
                               plod::Wake { data: "2", tag: http::SOCKET_READY }]);
    expect::same(expect::status_of(woke), "HTTP/1.1 200 OK", "woke status");
    expect::same(expect::body_of(woke), "woke 2", "woke body");
    expect::same(log, "W1 W2 ", "woke's calls");

    // A TIMEOUT, after a WAKE, goes to the route, which answers it.
    log.clear();
    let late = req("/socket", [plod::Wake { data: "1" }, plod::Wake { timeout: true }]);
    expect::same(expect::status_of(late), "HTTP/1.1 200 OK", "timeout status");
    expect::same(expect::body_of(late), "{\"items\":[],\"count\":0}", "timeout body");
    expect::same(log, "W1 T ", "timeout's calls");

    // And goose-http's TIMEOUT at once, with no timer free, in place of 503.
    log.clear();
    let early = req("/socket", [plod::Wake { timeout: true, early: true }]);
    expect::same(expect::status_of(early), "HTTP/1.1 200 OK", "early status");
    expect::same(log, "T ", "early's calls");

    // A client that goes during the wait: CLOSED, whose answer goes nowhere,
    // and serve_one's 500 for a route that never answered.
    log.clear();
    let gone = req("/socket", [plod::Wake { data: "1" }]);
    expect::same(expect::status_of(gone), "HTTP/1.1 500 Internal Server Error", "closed status");
    assert(find(gone, "nowhere") < 0);
    expect::same(log, "W1 C ", "closed's calls");

    // A lane's wait: Plod answers its TIMEOUT with 504, and the route gets
    // no call, nor a CLOSED when the client goes.
    log.clear();
    let asked = req("/ask", [plod::Wake { timeout: true }]);
    expect::same(expect::status_of(asked), "HTTP/1.1 504 Gateway Timeout", "ask timeout");
    expect::same(log, "", "ask timeout's calls");
    log.clear();
    let left = req("/ask", []);
    expect::same(expect::status_of(left), "HTTP/1.1 500 Internal Server Error", "ask closed");
    expect::same(log, "", "ask closed's calls");

    // And not_served outside serve and serve_one.
    let parsed, status = http::parse("GET / HTTP/1.1\r\nHost: x\r\n\r\n");
    assert(status == 200);
    var buf: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = St { .. };
    var scratch: u8[>..] = [];
    var none = plod::NoRouter { .. };
    var cx = plod::Cx<St, App, plod::NoRouter> {
        req: parsed, body: "", out: http::Reply { buf: buf, common: "", keep_alive: keep, minor: 1, head: false, stream: stream },
        state: st, app: app, scratch: scratch, router: none,
    };
    plod::route(cx) { plod::own_waits(cx, Use.Socket); };
    expect::same(expect::body_of(buf), "{\"error\":\"not_served\"}", "not served");
    http::mail_close(box);
    print("plod::own_waits: ok");
}
