// An upgraded connection whose route waits on rest::ask: where the client's
// bytes go while it waits, at the reply, and at the timeout, for a route that
// asks at the request and one that asks at a BODY, and a second ask during
// a wait.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import expect from "../";

// The lane's one job.
enum Asks { Ask }

// Echo is the upgrade's, Asked the lane's mark. Each resume writes what it
// got to the connection, so the bytes after the 101 show which resume each
// event reached.
enum Use { None, Echo, Asked }

struct St { use: Use = Use.None }

// closed counts the CLOSED calls, whose writes go nowhere.
struct App { to: rest::Lane<Asks, Use>, closed: i64 = 0 }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        rest::upgrade(cx, "echo", Use.Echo);
        if cx.req.target == "/ask" { rest::ask(cx, cx.app.to, Asks.Ask, 200); }
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The bytes back as they are, or an ask for "ask".
fn resume(u: Use.Echo, cx) {
    rest::send(cx, str("[", kind_of(cx), " to echo: ", cx.body, "]"));
    if cx.kind == http::BODY && cx.body == "ask" { rest::ask(cx, cx.app.to, Asks.Ask, 200); }
}

// The reply, which carries the job back, or the timeout or bytes during the
// wait, which don't: of these, "again" asks a second time, and "check" asks
// rest::is_waiting.
fn resume(u: Use.Asked, cx) {
    if cx.kind == http::WAKE {
        resume(rest::job<Asks>(cx), cx);
        return;
    }
    rest::send(cx, str("[", kind_of(cx), " to asked: ", cx.body, "]"));
    if cx.kind == http::BODY && cx.body == "again" { rest::ask(cx, cx.app.to, Asks.Ask, 200); }
    if cx.kind == http::BODY && cx.body == "check" && rest::is_waiting(cx) { rest::send(cx, "[waiting]"); }
    if cx.kind == http::TIMEOUT { cx.state.use = Use.Echo; }
}

fn resume(u: Asks.Ask, cx) {
    rest::send(cx, str("[WAKE to asked: ", rest::answer<Word>(cx), "]"));
    cx.state.use = Use.Echo;
}

struct Word { s: u8[..16] }

fn format(out: u8[>..]&, w: const Word&) { out.append(w.s); }

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
    var app = App { to: rest::lane_of<Asks>(box, Use.Asked) };
    let reply = rest::play(app.to, Asks.Ask) { u, a => rest::reply_value(a, Word { s: "reply" }); };
    let data = reply.data;

    // Asked at the request: bytes during the wait, the reply, bytes after it.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "during", data: data }]));
    // The same, with the timeout in place of the reply.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "during", timeout: true }]));
    // Asked at a BODY: bytes during the wait, then the reply.
    print(upgraded(app, "/", "ask", [rest::Wake { sent: "during", data: data }]));
    // A second ask during the wait fails with 500 already_waiting, which cuts
    // the connection, so no reply comes, and sends no second job.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "again", data: data }]));
    // A route can tell it waits already before it asks.
    print(upgraded(app, "/ask", "after", [rest::Wake { sent: "check", data: data }]));

    let n = http::mail_take(box) { key, tag, bytes => };
    print("jobs sent: ", n);
    http::mail_close(box);
}
