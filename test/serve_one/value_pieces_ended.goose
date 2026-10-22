// A rest::reply_value in pieces whose route ends while it's collected, event
// by event in the worker's gather pool, as value_pieces.goose has
// them: an upgraded connection's route that fails at a BODY, or ends there,
// a response begun whose reply passes its limit, and a refusal after a
// piece. Each route gets CLOSED once where it should, and the run is freed.
import std;
import http from "github.com/kaitk/goose-http@v0.5.1";
import rest from "../../";
import expect from "../";

enum Feeds { Next { n: i64 } }

// Echo is the upgrade's, Ticks the response's, Upload the body's, and Feed
// the lane's mark.
enum Use { None, Echo, Ticks, Upload, Feed }

struct St { use: Use = Use.None }

// The CLOSED calls each variant got.
// most is the reply limit of /ticks's ask.
struct App { to: rest::Lane<Feeds, Use>, echo: i64 = 0, ticks: i64 = 0, feed: i64 = 0, most: i64 = rest::REPLY_LIMIT }

// A value wider than a piece.
struct Row { n: i64, digits: u8[..40] }

fn handle(cx) {
    if rest::resumed(cx) {
        rest::on_reply(cx) { resume(cx.state.use, cx); };
    } else if cx.req.target == "/ticks" {
        rest::route(cx) {
            rest::begin(cx, 200, "text/plain", -1, Use.Ticks);
            rest::ask(cx, cx.app.to, Feeds.Next { n: 1 }, 5000, cx.app.most);
        };
    } else if cx.req.target == "/upload" {
        rest::route(cx) { rest::body_in_pieces(cx, 64, Use.Upload); };
    } else if cx.req.target == "/up" {
        rest::upgrade(cx, "echo", Use.Echo);
        rest::ask(cx, cx.app.to, Feeds.Next { n: 1 });
    } else {
        rest::route(cx) { rest::ask(cx, cx.app.to, Feeds.Next { n: 1 }); };
    }
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Echo, cx) { if cx.kind == http::CLOSED { cx.app.echo++; } }

fn resume(u: Use.Ticks, cx) { if cx.kind == http::CLOSED { cx.app.ticks++; } }

// Asks at the body's first piece.
fn resume(u: Use.Upload, cx) { if cx.kind == http::BODY { rest::ask(cx, cx.app.to, Feeds.Next { n: 1 }); } }

// The reply, or on the upgraded connection, bytes that come meanwhile:
// "fail" fails the route, and "end" ends it.
fn resume(u: Use.Feed, cx) {
    if cx.kind == http::WAKE {
        resume(rest::job<Feeds>(cx), cx);
    } else if cx.kind == http::CLOSED {
        cx.app.feed++;
    } else if cx.kind == http::BODY && cx.body == "fail" {
        rest::fail(cx, 400, "bad_bytes");
    } else if cx.kind == http::BODY && cx.body == "end" {
        rest::end(cx);
    }
}

fn resume(u: Feeds.Next, cx) {
    let r = rest::answer<Row>(cx);
    rest::text(cx, 200, str(r.n, " ", r.digits));
}

fn run(u: Feeds.Next, a) { rest::reply_value(a, Row { n: u.n, digits: "0123456789" }); }

fn refuse(u: Feeds.Next, a) { rest::fail(a, 409, "conflict"); }

// One exchange of a worker, whose gather pool the test's thread holds.
struct Conn {
    req: http::Request,
    st: rest::Slot<St> = rest::Slot<St> { state: St { .. } },
    keep: bool = true,
    stream: http::Stream = http::Stream { .. },
}

fn send(c: Conn&, out: u8[>..]&, app: App&, kind: u8, data: const u8[:], tag: i32, whole: bool = true) {
    let reply = http::Reply { buf: out, common: "", keep_alive: c.keep, minor: 1, head: false, stream: c.stream };
    // goose-http's wait ends before the event that ends it; an upgraded
    // connection's BODY comes during it.
    if kind == http::WAKE || kind == http::TIMEOUT {
        c.stream.waiting = false;
        c.stream.rearm = false;
    }
    rest::deliver(http::Event { kind: kind, req: c.req, data: data, whole: whole, trailers: "", tag: tag }, c.st, app,
                  reply) { cx => handle(cx); };
    assert(http::gather_promised <= http::gather_most);
}

// Piece i of p's reply in pieces of size bytes, tagged as a lane sends it.
fn piece(c: Conn&, out: u8[>..]&, app: App&, p: const rest::Played&, size: i64, i: i64) {
    let at = i * size;
    let end = min(at + size, p.data.len);
    let first = if i == 0 { p.tag } else { rest::REPLY_CONT | (p.tag & rest::REPLY_VALUE) };
    send(c, out, app, http::WAKE, p.data[at..end], if end < p.data.len { first | rest::REPLY_MORE } else { first });
}

fn in_use() -> i64 { http::gather_promised }

// An exchange of the request text, which must outlive it.
fn conn(text: const u8[:]) -> Conn {
    let req, status = http::parse(text);
    assert(status == 200);
    return Conn { req: req };
}

fn closed(app: App&) -> u8[>..] {
    let s = str("CLOSED to echo ", app.echo, ", ticks ", app.ticks, ", feed ", app.feed);
    app.echo = 0;
    app.ticks = 0;
    app.feed = 0;
    return s;
}

fn main() {
    let box, e = http::mail_open(16, 256);
    http::exit_on_error(e);
    var app = App { to: rest::lane_of<Feeds>(box, Use.Feed) };
    let one = rest::play(app.to, Feeds.Next { n: 1 }) { u, a => run(u, a); };
    let no = rest::play(app.to, Feeds.Next { n: 1 }) { u, a => refuse(u, a); };
    let size = (one.data.len + 2) / 3;
    let up = "GET /up HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n";
    let ticks = expect::request("GET", "/ticks");
    let ask = expect::request("GET", "/ask");
    let upload = "POST /upload HTTP/1.1\r\nHost: x\r\nContent-Length: 6\r\n\r\n";

    // Upgraded, the first piece, then a BODY whose handler fails: the route
    // gets CLOSED in the lane's mark, and a CLOSED from the client after it
    // reaches no one and frees nothing twice.
    var fails = conn(up);
    var fails_out: u8[>..] = [];
    send(fails, fails_out, app, http::REQUEST, "", 0);
    piece(fails, fails_out, app, one, size, 0);
    assert(in_use() > 0);
    send(fails, fails_out, app, http::BODY, "fail", 0);
    print("upgraded, failed mid-reply: open ", fails.stream.open, ", ", closed(app), ", promised ", in_use());
    send(fails, fails_out, app, http::CLOSED, "", 0);
    print("then the client goes: ", closed(app), ", promised ", in_use());

    // Upgraded, the first piece, then a BODY whose handler ends the
    // connection, goose-http's wait still set until the handler returns.
    var ends = conn(up);
    var ends_out: u8[>..] = [];
    send(ends, ends_out, app, http::REQUEST, "", 0);
    piece(ends, ends_out, app, one, size, 0);
    assert(in_use() > 0);
    send(ends, ends_out, app, http::BODY, "end", 0);
    print("upgraded, ended mid-reply: open ", ends.stream.open, ", ", closed(app), ", promised ", in_use());

    // A response begun, and a reply of 32-byte pieces that passes a 48-byte
    // reply limit at the second: the response is cut, and the route gets
    // CLOSED.
    app.most = 48;
    var cut = conn(ticks);
    var cut_out: u8[>..] = [];
    send(cut, cut_out, app, http::REQUEST, "", 0);
    piece(cut, cut_out, app, one, 32, 0);
    assert(in_use() > 0);
    piece(cut, cut_out, app, one, 32, 1);
    print("begun, past its limit: open ", cut.stream.open, ", keep-alive ", cut.keep, ", waiting ",
          cut.stream.waiting, ", ", closed(app), ", promised ", in_use());
    app.most = rest::REPLY_LIMIT;

    // A refusal after the first piece: the route fails with its status and
    // code.
    var refused = conn(ask);
    var refused_out: u8[>..] = [];
    send(refused, refused_out, app, http::REQUEST, "", 0);
    piece(refused, refused_out, app, one, size, 0);
    assert(in_use() > 0);
    send(refused, refused_out, app, http::WAKE, no.data, no.tag);
    print("refused mid-reply: ", expect::status_of(refused_out), " ", expect::body_of(refused_out), ", promised ",
          in_use());

    // A route that receives its body, with no stream open, and asks at its
    // first piece: the run holds the reply's pieces until the resume.
    var body = conn(upload);
    var body_out: u8[>..] = [];
    send(body, body_out, app, http::REQUEST, "", 0, false);
    send(body, body_out, app, http::BODY, "abc", 0);
    for i in 2 { piece(body, body_out, app, one, size, i); }
    print("receiving, two pieces of three: collecting ", (body.st.ex.mode & rest::ASKED) != 0, ", promised ",
          in_use() > 0);
    piece(body, body_out, app, one, size, 2);
    print("receiving, the third: ", expect::status_of(body_out), " ", expect::body_of(body_out), ", promised ",
          in_use());
    http::mail_close(box);
}
