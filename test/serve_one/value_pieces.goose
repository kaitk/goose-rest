// A plod::reply_value in pieces, event by event as serve gives them, in
// the worker's gather pool: the reply's run holds the pieces while they
// come, within the limit its ask promised, and is freed once the resume has
// the value, when the route then waits again, when the client goes
// mid-reply, when the wait times out mid-reply, and past the limit.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";

enum Counts { Next { n: i64 } }

enum Use { None, Count }

struct St { use: Use = Use.None }

// most is the reply limit of the route's first ask.
struct App { to: plod::Lane<Counts, Use>, most: i64 = plod::REPLY_LIMIT }

// A value wider than a piece.
struct Row { n: i64, digits: u8[..40] }

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::route(cx) { plod::ask(cx, cx.app.to, Counts.Next { n: 1 }, 5000, cx.app.most); };
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Count, cx) { resume(plod::job<Counts>(cx), cx); }

// Two waits in turn: the first answer asks again.
fn resume(u: Counts.Next, cx) {
    let r = plod::answer<Row>(cx);
    if r.n < 2 { plod::ask(cx, cx.app.to, Counts.Next { n: r.n + 1 }); } else { plod::text(cx, 200, str(r.n, " ", r.digits)); }
}

fn run(u: Counts.Next, a) { plod::reply_value(a, Row { n: u.n, digits: "0123456789" }); }

// One exchange of a worker, whose gather pool the test's thread holds.
struct Conn {
    req: http::Request,
    st: plod::Slot<St> = plod::Slot<St> { state: St { .. } },
    keep: bool = true,
    stream: http::Stream = http::Stream { .. },
}

fn send(c: Conn&, out: u8[>..]&, app: App&, kind: u8, data: const u8[:], tag: i32) {
    let reply = http::Reply { buf: out, common: "", keep_alive: c.keep, minor: 1, head: false, stream: c.stream };
    // goose-http's wait ends before the event that ends it.
    if kind != http::REQUEST {
        c.stream.waiting = false;
        c.stream.rearm = false;
    }
    plod::deliver(http::Event { kind: kind, req: c.req, data: data, whole: true, trailers: "", tag: tag }, c.st, app,
                  reply) { cx => handle(cx); };
    assert(http::gather_promised <= http::gather_most);
}

// Pieces from..to of p's reply in pieces of size bytes, tagged as a lane
// sends them, while the exchange waits: goose-http drops the others.
fn wake(c: Conn&, out: u8[>..]&, app: App&, p: const plod::Played&, size: i64, from: i64, to: i64) {
    for i in from..to {
        if !c.stream.waiting { return; }
        let at = i * size;
        let end = min(at + size, p.data.len);
        let first = if i == 0 { p.tag } else { plod::REPLY_CONT | (p.tag & plod::REPLY_VALUE) };
        let tag = if end < p.data.len { first | plod::REPLY_MORE } else { first };
        send(c, out, app, http::WAKE, p.data[at..end], tag);
    }
}

// The bytes of the runs in use.
fn in_use() -> i64 { http::gather_promised }

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: plod::lane_of<Counts>(box, Use.Count) };
    let text = expect::request("GET", "/count");
    let req, status = http::parse(text);
    assert(status == 200);
    let one = plod::play(app.to, Counts.Next { n: 1 }) { u, a => run(u, a); };
    let two = plod::play(app.to, Counts.Next { n: 2 }) { u, a => run(u, a); };
    let size = (one.data.len + 2) / 3;
    print("a reply of ", one.data.len, " bytes, in pieces of ", size, ", marked: ",
          (one.tag & plod::REPLY_VALUE) != 0);

    // Three pieces, a second wait, and three more: the run holds each
    // reply until its resume has it.
    var c = Conn { req: req };
    var out: u8[>..] = [];
    send(c, out, app, http::REQUEST, "", 0);
    wake(c, out, app, one, size, 0, 2);
    print("two pieces of three: waiting ", c.stream.waiting, ", answered ", out.len > 0, ", promised ",
          in_use() > 0);
    wake(c, out, app, one, size, 2, 3);
    print("the third, then a second wait: waiting ", c.stream.waiting, ", promised ", in_use());
    wake(c, out, app, two, size, 0, 3);
    expect::same(expect::body_of(out), "2 0123456789", "two waits");
    print("answered: ", expect::body_of(out), ", promised ", in_use());

    // A client that goes mid-reply: CLOSED frees the run.
    var gone = Conn { req: req };
    var gone_out: u8[>..] = [];
    send(gone, gone_out, app, http::REQUEST, "", 0);
    wake(gone, gone_out, app, one, size, 0, 2);
    assert(in_use() > 0);
    send(gone, gone_out, app, http::CLOSED, "", 0);
    print("gone mid-reply: answered ", gone_out.len > 0, ", promised ", in_use());

    // The wait's time runs out mid-reply: 504, and the run is freed.
    var late = Conn { req: req };
    var late_out: u8[>..] = [];
    send(late, late_out, app, http::REQUEST, "", 0);
    wake(late, late_out, app, one, size, 0, 1);
    assert(in_use() > 0);
    send(late, late_out, app, http::TIMEOUT, "", 0);
    print("timed out mid-reply: ", expect::status_of(late_out), " ", expect::body_of(late_out), ", promised ",
          in_use());

    // Past a reply limit smaller than the reply: 502, the run freed, and the
    // pieces after it find the exchange no longer waiting.
    app.most = one.data.len - 1;
    var over = Conn { req: req };
    var over_out: u8[>..] = [];
    send(over, over_out, app, http::REQUEST, "", 0);
    wake(over, over_out, app, one, size, 0, 3);
    print("past its limit: ", expect::status_of(over_out), " ", expect::body_of(over_out), ", waiting ",
          over.stream.waiting, ", promised ", in_use());
    http::mail_close(box);
}
