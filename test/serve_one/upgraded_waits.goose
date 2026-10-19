// An upgraded connection whose route waits on rest::ask: where the client's
// bytes go while it waits, at the reply, and at the timeout, for a route that
// asks at the request and one that asks at a BODY, and a second ask during
// a wait.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";

// Echo is the upgrade's variant, Asked the ask's. Each case function writes
// what it got to the connection, so the bytes after the 101 show which case
// function each event reached.
enum Waiting { None, Echo, Asked }

struct St { waiting: Waiting = Waiting.None }

// closed counts the CLOSED calls, whose writes go nowhere.
struct App { to: http::Lane, closed: i64 = 0 }

let JOB: i32 = 1;

fn handle(cx) {
    if rest::resumed(cx) {
        resume(cx.state.waiting, cx);
    } else {
        rest::upgrade(cx, "echo", Waiting.Echo);
        if cx.req.target == "/ask" { rest::ask(cx, cx.app.to, JOB, 0, Waiting.Asked, 200); }
    }
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The bytes back as they are, or an ask for "ask".
fn resume(w: Waiting.Echo, cx) {
    rest::send(cx, str("[", kind_of(cx), " to echo: ", cx.body, "]"));
    if cx.kind == http::BODY && cx.body == "ask" { rest::ask(cx, cx.app.to, JOB, 0, Waiting.Asked, 200); }
}

// The reply, the timeout, or bytes during the wait, of which "again" asks a
// second time, and "check" asks rest::is_waiting.
fn resume(w: Waiting.Asked, cx) {
    rest::send(cx, str("[", kind_of(cx), " to asked: ", if cx.kind == http::WAKE { cx.reply } else { cx.body }, "]"));
    if cx.kind == http::BODY && cx.body == "again" { rest::ask(cx, cx.app.to, JOB, 0, Waiting.Asked, 200); }
    if cx.kind == http::BODY && cx.body == "check" && rest::is_waiting(cx) { rest::send(cx, "[waiting]"); }
    if cx.kind == http::WAKE || cx.kind == http::TIMEOUT { cx.state.waiting = Waiting.Echo; }
}

fn kind_of(cx) -> const u8[:] {
    if cx.kind == http::BODY { return "BODY"; }
    if cx.kind == http::WAKE { return "WAKE"; }
    if cx.kind == http::TIMEOUT { return "TIMEOUT"; }
    if cx.kind == http::CLOSED {
        cx.app.closed++;
        return "CLOSED";
    }
    return "other";
}

fn upgraded(app: App&, target: const u8[:], after: const u8[:], wakes: const rest::Wake[:]) -> u8[>..] {
    let text = str("GET ", target, " HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n", after);
    app.closed = 0;
    let out = rest::serve_one(text, app, St { .. }, wakes) { cx => handle(cx) };
    return str(expect::body_of(out), " closed: ", app.closed);
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: http::lane_of(box) };

    // Asked at the request: bytes during the wait, the reply, bytes after it.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "during", data: "reply" }]));
    // The same, with the timeout in place of the reply.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "during", timeout: true }]));
    // Asked at a BODY: bytes during the wait, then the reply.
    print(upgraded(app, "/", "ask", [rest::Wake { sent: "during", data: "reply" }]));
    // A second ask during the wait fails with 500 already_waiting, which cuts
    // the connection, so no reply comes, and sends no second job.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "again", data: "reply" }]));
    // A route can tell it waits already before it asks.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "check", data: "reply" }]));

    let n = http::mail_take(box) { key, tag, bytes => assert(tag == JOB); };
    print("jobs sent: ", n);
    http::mail_close(box);
}
