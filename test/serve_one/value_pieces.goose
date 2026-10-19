// A rest::reply_value in pieces, event by event as serve gives them, with
// the worker's spill and gather budget: the reply's run holds the pieces
// while they come, and is freed once the resume has the value, when the
// route then waits again, when the client goes mid-reply, and when the wait
// times out mid-reply.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";

enum Counts { Next { n: i64 } }

enum Use { None, Count }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Counts, Use> }

// A value wider than a piece.
struct Row { n: i64, digits: u8[..40] }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        rest::route(cx) { rest::ask(cx, cx.app.to, Counts.Next { n: 1 }); };
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Count, cx) { resume(rest::job<Counts>(cx), cx); }

// Two waits in turn: the first answer asks again.
fn resume(u: Counts.Next, cx) {
    let r = rest::answer<Row>(cx);
    if r.n < 2 { rest::ask(cx, cx.app.to, Counts.Next { n: r.n + 1 }); } else { rest::text(cx, 200, str(r.n, " ", r.digits)); }
}

fn run(u: Counts.Next, a) { rest::reply_value(a, Row { n: u.n, digits: "0123456789" }); }

// One exchange of a worker whose spill and budget the caller holds.
struct Conn {
    req: http::Request,
    st: rest::Slot<St> = rest::Slot<St> { state: St { .. } },
    keep: bool = true,
    stream: http::Stream = http::Stream { .. },
}

fn send(c: Conn&, out: u8[>..]&, app: App&, kind: u8, data: const u8[:], tag: i32, spill: u8[>..]&,
        budget: rest::Budget&) {
    let reply = http::Reply { buf: out, common: "", keep_alive: c.keep, minor: 1, head: false, stream: c.stream };
    // goose-http's wait ends before the event that ends it.
    if kind != http::REQUEST {
        c.stream.waiting = false;
        c.stream.rearm = false;
    }
    rest::deliver(http::Event { kind: kind, req: c.req, data: data, whole: true, trailers: "", tag: tag }, c.st, app,
                  reply, spill, budget) { cx => handle(cx); };
    assert(budget.len == spill.len && spill.len <= budget.size);
}

// Pieces from..to of p's reply in pieces of size bytes, tagged as a lane
// sends them, while the exchange waits: goose-http drops the others.
fn wake(c: Conn&, out: u8[>..]&, app: App&, p: const rest::Played&, size: i64, from: i64, to: i64, spill: u8[>..]&,
        budget: rest::Budget&) {
    for i in from..to {
        if !c.stream.waiting { return; }
        let at = i * size;
        let end = min(at + size, p.data.len);
        let first = if i == 0 { p.tag } else { rest::REPLY_CONT | (p.tag & rest::REPLY_VALUE) };
        let tag = if end < p.data.len { first | rest::REPLY_MORE } else { first };
        send(c, out, app, http::WAKE, p.data[at..end], tag, spill, budget);
    }
}

// The bytes of the runs in use.
fn in_use(b: const rest::Budget&) -> i64 {
    var n: i64 = 0;
    for r in b.runs { n += r.cap; }
    return n;
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Counts>(box, Use.Count) };
    let text = expect::request("GET", "/count");
    let req, status = http::parse(text);
    assert(status == 200);
    reusable[] var spill: u8[>..] = [];
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: 1 << 20, runs: runs };
    let one = rest::play(app.to, Counts.Next { n: 1 }) { u, a => run(u, a); };
    let two = rest::play(app.to, Counts.Next { n: 2 }) { u, a => run(u, a); };
    let size = (one.data.len + 2) / 3;
    print("a reply of ", one.data.len, " bytes, in pieces of ", size, ", marked: ",
          (one.tag & rest::REPLY_VALUE) != 0);

    // Three pieces, a second wait, and three more: the run holds each
    // reply until its resume has it.
    var c = Conn { req: req };
    var out: u8[>..] = [];
    send(c, out, app, http::REQUEST, "", 0, spill, b);
    wake(c, out, app, one, size, 0, 2, spill, b);
    print("two pieces of three: waiting ", c.stream.waiting, ", answered ", out.len > 0, ", in the spill ",
          in_use(b) > 0);
    wake(c, out, app, one, size, 2, 3, spill, b);
    print("the third, then a second wait: waiting ", c.stream.waiting, ", in the spill ", in_use(b));
    wake(c, out, app, two, size, 0, 3, spill, b);
    expect::same(expect::body_of(out), "2 0123456789", "two waits");
    print("answered: ", expect::body_of(out), ", in the spill ", in_use(b), ", then: ", c.st.state.use);

    // A client that goes mid-reply: CLOSED frees the run.
    var gone = Conn { req: req };
    var gone_out: u8[>..] = [];
    send(gone, gone_out, app, http::REQUEST, "", 0, spill, b);
    wake(gone, gone_out, app, one, size, 0, 2, spill, b);
    assert(in_use(b) > 0);
    send(gone, gone_out, app, http::CLOSED, "", 0, spill, b);
    print("gone mid-reply: answered ", gone_out.len > 0, ", in the spill ", in_use(b));

    // The wait's time runs out mid-reply: 504, and the run is freed.
    var late = Conn { req: req };
    var late_out: u8[>..] = [];
    send(late, late_out, app, http::REQUEST, "", 0, spill, b);
    wake(late, late_out, app, one, size, 0, 1, spill, b);
    assert(in_use(b) > 0);
    send(late, late_out, app, http::TIMEOUT, "", 0, spill, b);
    print("timed out mid-reply: ", expect::status_of(late_out), " ", expect::body_of(late_out), ", in the spill ",
          in_use(b));

    // Over a budget smaller than the reply: 502, the run freed, and the
    // pieces after it find the exchange no longer waiting.
    var small_runs: rest::Run[>..] = [];
    var small = rest::Budget { size: one.data.len, runs: small_runs };
    reusable[] var other: u8[>..] = [];
    var over = Conn { req: req };
    var over_out: u8[>..] = [];
    send(over, over_out, app, http::REQUEST, "", 0, other, small);
    wake(over, over_out, app, one, size, 0, 3, other, small);
    print("over the budget: ", expect::status_of(over_out), " ", expect::body_of(over_out), ", waiting ",
          over.stream.waiting, ", in the spill ", in_use(small));
    http::mail_close(box);
}
