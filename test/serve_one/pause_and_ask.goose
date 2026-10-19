// An exchange keeps a pause's deadline and the start of a reply being
// collected in one field: a route that began a response and paused asks a
// lane at each TIMEOUT, gets a rest::reply_value in pieces, and pauses again
// in the resume; and an upgraded connection that asks gets bytes while the
// reply's pieces are being collected. Each reply's run is freed, and the
// pause still ends.
import std;
import http from "github.com/kaitk/goose-http@v0.4.0";
import rest from "../../";
import expect from "../";

enum Feeds { Next { n: i64 } }

// Ticks is the response's, Echo the upgrade's, and Feed the lane's mark.
enum Use { None, Ticks, Echo, Feed }

struct St { use: Use = Use.None }

struct App { to: rest::Lane<Feeds, Use> }

// A value wider than a piece.
struct Row { n: i64, digits: u8[..40] }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else if cx.req.target == "/ticks" {
        rest::route(cx) {
            rest::begin(cx, 200, "text/plain", -1, Use.Ticks);
            rest::pause(cx, 10);
        };
    } else {
        rest::upgrade(cx, "echo", Use.Echo);
        rest::ask(cx, cx.app.to, Feeds.Next { n: 9 });
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// At each TIMEOUT of the pause, the next row from the lane.
fn resume(u: Use.Ticks, cx) {
    if cx.kind == http::TIMEOUT { rest::ask(cx, cx.app.to, Feeds.Next { n: 1 }); }
}

fn resume(u: Use.Echo, cx) {}

// The reply, or on the upgraded connection, bytes that come meanwhile.
fn resume(u: Use.Feed, cx) {
    if cx.kind == http::WAKE {
        resume(rest::job<Feeds>(cx), cx);
    } else if cx.kind == http::BODY {
        rest::send(cx, str("[", cx.body, "]"));
    }
}

// Sends the row, and pauses again, or ends after the second; on the upgraded
// connection, whose job is 9, sends it and ends.
fn resume(u: Feeds.Next, cx) {
    let r = rest::answer<Row>(cx);
    rest::send(cx, str(r.n, " ", r.digits, "\n"));
    if u.n == 9 || r.n == 2 {
        rest::end(cx);
    } else {
        cx.state.use = Use.Ticks;
        rest::pause(cx, 10);
    }
}

fn run(u: Feeds.Next, a) { rest::reply_value(a, Row { n: u.n, digits: "0123456789" }); }

fn run_as(n: i64, a) { rest::reply_value(a, Row { n: n, digits: "0123456789" }); }

// One exchange of a worker whose spill and budget the caller holds, as
// value_pieces.goose has it.
struct Conn {
    req: http::Request,
    st: rest::Slot<St> = rest::Slot<St> { state: St { .. } },
    keep: bool = true,
    stream: http::Stream = http::Stream { .. },
}

fn send(c: Conn&, out: u8[>..]&, app: App&, kind: u8, data: const u8[:], tag: i32, spill: u8[>..]&,
        budget: rest::Budget&) {
    let reply = http::Reply { buf: out, common: "", keep_alive: c.keep, minor: 1, head: false, stream: c.stream };
    // goose-http's wait ends before the event that ends it; an upgraded
    // connection's BODY comes during it.
    if kind == http::WAKE || kind == http::TIMEOUT {
        c.stream.waiting = false;
        c.stream.rearm = false;
    }
    // The time the pause asked for has come.
    if kind == http::TIMEOUT { c.st.ex.due = 0; }
    rest::deliver(http::Event { kind: kind, req: c.req, data: data, whole: true, trailers: "", tag: tag }, c.st, app,
                  reply, spill, budget) { cx => handle(cx); };
}

fn in_use(b: const rest::Budget&) -> i64 {
    var n: i64 = 0;
    for r in b.runs { n += r.cap; }
    return n;
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Feeds>(box, Use.Feed) };
    let one = rest::play(app.to, Feeds.Next { n: 1 }) { u, a => run(u, a); };
    let two = rest::play(app.to, Feeds.Next { n: 1 }) { u, a => run_as(2, a); };
    let nine = rest::play(app.to, Feeds.Next { n: 9 }) { u, a => run(u, a); };
    let size = (one.data.len + 2) / 3;
    let small = http::Config { mail_size: size as i32, .. };

    // Paused, asked at the TIMEOUT, the reply in three pieces, paused again
    // in the resume, and again.
    let ticks = rest::serve_one(expect::request("GET", "/ticks"), app, St { .. },
                                [rest::Wake { timeout: true }, rest::wake(one), rest::Wake { timeout: true },
                                 rest::wake(two)], small) { cx => handle(cx); };
    expect::same(expect::body_of(ticks), "d\r\n1 0123456789\n\r\nd\r\n2 0123456789\n\r\n0\r\n\r\n", "paused, then asked");

    // The same, event by event, with the spill in view: each run is freed,
    // and the pause after the first reply waits on its own deadline.
    let text = expect::request("GET", "/ticks");
    let req, status = http::parse(text);
    assert(status == 200);
    reusable[] var spill: u8[>..] = [];
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: 1 << 20, runs: runs };
    var c = Conn { req: req };
    var out: u8[>..] = [];
    send(c, out, app, http::REQUEST, "", 0, spill, b);
    send(c, out, app, http::TIMEOUT, "", 0, spill, b);
    for i in 3 {
        let at = i * size;
        let end = min(at + size, one.data.len);
        let first = if i == 0 { one.tag } else { rest::REPLY_CONT | rest::REPLY_VALUE };
        send(c, out, app, http::WAKE, one.data[at..end], if end < one.data.len { first | rest::REPLY_MORE } else { first },
             spill, b);
    }
    print("after the first reply: paused ", c.stream.waiting, ", collecting ", (c.st.ex.mode & rest::COLLECTING) != 0,
          ", in the spill ", in_use(b), ", deadline ahead ", c.st.ex.due > clock_ns());

    // An upgraded connection that asks: bytes come between the reply's
    // pieces, and the run holds the pieces meanwhile.
    let up_text = "GET /up HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n";
    let up_req, up_status = http::parse(up_text);
    assert(up_status == 200);
    var u = Conn { req: up_req };
    var up_out: u8[>..] = [];
    send(u, up_out, app, http::REQUEST, "", 0, spill, b);
    for i in 3 {
        let at = i * size;
        let end = min(at + size, nine.data.len);
        let first = if i == 0 { nine.tag } else { rest::REPLY_CONT | rest::REPLY_VALUE };
        send(u, up_out, app, http::WAKE, nine.data[at..end], if end < nine.data.len { first | rest::REPLY_MORE } else { first },
             spill, b);
        if i == 0 { send(u, up_out, app, http::BODY, "hello", 0, spill, b); }
    }
    expect::same(expect::body_of(up_out), "[hello]9 0123456789\n", "upgraded, bytes mid-reply");
    print("upgraded: open ", u.stream.open, ", in the spill ", in_use(b));
    http::mail_close(box);
}
