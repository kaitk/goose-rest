// What the tests of bodies gathered for rest::body share: one exchange of a
// worker, event by event as serve gives them, with the worker's spill and
// gather budget, and a route that reads its body whole or in pieces.
import std;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../";
import expect from "../";

let UNAVAILABLE = "HTTP/1.1 503 Service Unavailable\r\nRetry-After: 1\r\nContent-Type: application/json\r\nContent-Length: 23\r\n\r\n{\"error\":\"unavailable\"}";

// A POST's head, with a Content-Length of n, or chunked for a negative n.
fn head(n: i64) -> u8[>..] {
    let framing = if n < 0 { str("Transfer-Encoding: chunked") } else { str("Content-Length: ", n) };
    return str("POST /up HTTP/1.1\r\nHost: x\r\n", framing, "\r\n\r\n");
}

fn letters(n: i64) -> u8[>..] {
    var text: u8[>..] = [];
    for i in n { text.push('a' + (i % 26) as u8); }
    return text;
}

enum Waiting { None, Pieces }

struct St { waiting: Waiting = Waiting.None, size: i64 = 0 }

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Pieces, cx) {
    if cx.kind == http::BODY { cx.state.size += cx.body.len; }
    else if cx.kind == http::END { rest::text(cx, 201, str(cx.state.size)); }
}

// The route: the body of at most limit bytes, answered with its length and
// its last byte, or for a negative limit, the body in pieces, answered with
// its length.
fn route(cx, limit: i64) {
    if rest::resumed(cx) {
        resume(cx.state.waiting, cx);
    } else if limit < 0 {
        rest::body_in_pieces(cx, 1 << 20, Waiting.Pieces);
    } else {
        let data = rest::body(cx, limit);
        rest::text(cx, 200, str(data.len, " ", data[data.len - 1..]));
    }
}

// One exchange of a worker whose spill and budget the caller holds: send
// gives the route an event, as serve does for a body that didn't come with
// its head.
struct Conn {
    req: http::Request,
    st: rest::Slot<St> = rest::Slot<St> { state: St { .. } },
    keep: bool = true,
    stream: http::Stream = http::Stream { .. },
}

fn send(c: Conn&, out: u8[>..]&, kind: u8, data: const u8[:], limit: i64, spill: u8[>..]&, budget: rest::Budget&) {
    var app = rest::NoState { .. };
    let reply = http::Reply { buf: out, common: "", keep_alive: c.keep, minor: 1, head: false, stream: c.stream };
    rest::deliver(http::Event { kind: kind, req: c.req, data: data, whole: false, trailers: "" }, c.st, app, reply,
                  spill, budget) { cx => route(cx, limit); };
    // The budget knows the spill's length, which never passes it.
    assert(budget.len == spill.len && spill.len <= budget.size);
}

// The bytes of the runs in use.
fn in_use(b: const rest::Budget&) -> i64 {
    var n: i64 = 0;
    for r in b.runs { n += r.cap; }
    return n;
}

// text's head, then size bytes of body in pieces of 8 KB and the END,
// unless the exchange has ended, on a worker of its own with a budget of
// budget bytes. caps holds the run's capacity after the head and each piece.
// Returns the answer, with "closed" after it if the connection closes.
fn gather(text: const u8[:], size: i64, limit: i64, caps: i64[>..]&, budget: i64 = rest::GATHER_BUDGET) -> u8[>..] {
    let req, status = http::parse(text);
    assert(status == 200);
    var c = Conn { req: req };
    var out: u8[>..] = [];
    reusable[] var spill: u8[>..] = [];
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: budget, runs: runs };
    let body = letters(size);
    send(c, out, http::REQUEST, "", limit, spill, b);
    caps.push(c.st.ex.cap);
    var at = 0;
    while at < size && out.len == 0 {
        let end = min(at + 8192, size);
        let start = c.st.ex.at;
        let room = c.st.ex.cap;
        send(c, out, http::BODY, body[at..end], limit, spill, b);
        caps.push(c.st.ex.cap);
        // A run that kept its capacity kept its place.
        assert(c.st.ex.cap != room || c.st.ex.at == start || out.len > 0);
        at = end;
    }
    if out.len == 0 { send(c, out, http::END, "", limit, spill, b); }
    assert((c.st.ex.mode & rest::GATHERING) == 0 && c.st.ex.cap == 0 && in_use(b) == 0);
    if !c.keep { out.append("\r\nclosed"); }
    return out;
}

// Gathers body on c, from its head to its END, in one piece.
fn whole(c: Conn&, out: u8[>..]&, body: const u8[:], spill: u8[>..]&, b: rest::Budget&) {
    send(c, out, http::REQUEST, "", 1 << 20, spill, b);
    send(c, out, http::BODY, body, 1 << 20, spill, b);
    send(c, out, http::END, "", 1 << 20, spill, b);
}
