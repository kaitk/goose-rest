// Bodies gathered for rest::body, event by event as serve gathers them: a
// body with a Content-Length in one run of its exact size, which never
// moves; a chunked one, whose run doubles; each past its route's limit; and
// the worker's gather budget: a body with a length refused at its head, a
// chunked one past it, a body that fits once another has finished, and a
// route on rest::body_in_pieces beside a full budget.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

fn same(got: const u8[:], want: const u8[:], what: const u8[:]) {
    if got != want {
        print(what, ":\ngot:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

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

fn test_length() {
    let text = head(100000);
    var caps: i64[>..] = [];
    same(body_of(gather(text, 100000, 1 << 20, caps)), "100000 d", "with a length");
    // One run of the head and the body, from the head on.
    for c in caps { assert(c == text.len + 100000); }
    assert(caps.len == 1 + (100000 + 8191) / 8192);
}

fn test_chunked() {
    var caps: i64[>..] = [];
    same(body_of(gather(head(-1), 50000, 1 << 20, caps)), "50000 b", "chunked");
    // 16 KB, then doubled as it fills.
    assert(caps[0] == 16384 && caps[caps.len - 1] == 65536);
    for i in caps.len - 1 { assert(caps[i + 1] == caps[i] || caps[i + 1] == caps[i] * 2); }
}

fn test_over_limit() {
    // A Content-Length over the limit: 413 at the head, nothing gathered.
    var none: i64[>..] = [];
    same(body_of(gather(head(30000), 30000, 20000, none)), "{\"error\":\"payload_too_large\"}", "a length");
    assert(none.len == 1 && none[0] == 0);
    // A chunked body: 413 once it passes the limit, and the connection closes.
    var caps: i64[>..] = [];
    same(body_of(gather(head(-1), 30000, 20000, caps)), "{\"error\":\"payload_too_large\"}\r\nclosed", "chunked");
    assert(caps.len == 4);
}

fn test_budget_at_head() {
    // Through serve_one: refused in the route's first run, before the body.
    let text = str(head(100000), letters(100000));
    var runs = 0;
    let small = rest::Config { gather_budget: 100000 };
    var app = rest::NoState { .. };
    let out = rest::serve_one(text, app, St { .. }, http::Config { .. }, small) { cx =>
        runs++;
        route(cx, 1 << 20);
    };
    same(out, UNAVAILABLE, "a length past the budget");
    assert(runs == 1);
    // The run is the head and the body: a budget of both takes it.
    let fits = rest::Config { gather_budget: head(100000).len + 100000 };
    same(body_of(rest::serve_one(text, app, St { .. }, http::Config { .. }, fits) { cx => route(cx, 1 << 20); }),
         "100000 d", "a length within the budget");
}

fn test_budget_chunked() {
    // The run doubles to 32 KB; doubled again it would pass the budget of
    // 40,000 bytes, so it grows by the piece alone, and once the body passes
    // the budget it gets 503, and the connection closes.
    var caps: i64[>..] = [];
    let closing = str("HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n",
                      UNAVAILABLE["HTTP/1.1 503 Service Unavailable\r\n".len..], "\r\nclosed");
    let h = head(-1).len;
    same(gather(head(-1), 100000, 1 << 20, caps, 40000), closing, "chunked past the budget");
    let want: i64[6] = [16384, 16384, 32768, 32768, h + 4 * 8192, 0];
    assert(caps.len == 6);
    for i in 6 { assert(caps[i] == want[i]); }
}

fn test_budget_shared() {
    reusable[] var spill: u8[>..] = [];
    let one = head(30000).len + 30000;
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: one + 100, runs: runs };
    let body = letters(30000);
    let text = head(30000);
    let req, status = http::parse(text);
    assert(status == 200);

    // a gathers; b, beside it, doesn't fit.
    var a = Conn { req: req };
    var a_out: u8[>..] = [];
    send(a, a_out, http::REQUEST, "", 1 << 20, spill, b);
    send(a, a_out, http::BODY, body[..10000], 1 << 20, spill, b);
    assert(in_use(b) == one && a_out.len == 0);
    var second = Conn { req: req };
    var second_out: u8[>..] = [];
    send(second, second_out, http::REQUEST, "", 1 << 20, spill, b);
    same(second_out, UNAVAILABLE, "beside another");
    assert(second.keep && in_use(b) == one);

    // A route on rest::body_in_pieces beside the full budget reads its body.
    var pieces = Conn { req: req };
    var pieces_out: u8[>..] = [];
    send(pieces, pieces_out, http::REQUEST, "", -1, spill, b);
    send(pieces, pieces_out, http::BODY, body[..20000], -1, spill, b);
    send(pieces, pieces_out, http::BODY, body[20000..], -1, spill, b);
    send(pieces, pieces_out, http::END, "", -1, spill, b);
    same(body_of(pieces_out), "30000", "in pieces beside a full budget");
    assert(in_use(b) == one);

    // Once a has its answer, the budget is free, and the next body fits.
    send(a, a_out, http::BODY, body[10000..], 1 << 20, spill, b);
    send(a, a_out, http::END, "", 1 << 20, spill, b);
    same(body_of(a_out), "30000 v", "the first");
    assert(in_use(b) == 0);
    var third = Conn { req: req };
    var third_out: u8[>..] = [];
    send(third, third_out, http::REQUEST, "", 1 << 20, spill, b);
    send(third, third_out, http::BODY, body, 1 << 20, spill, b);
    send(third, third_out, http::END, "", 1 << 20, spill, b);
    same(body_of(third_out), "30000 v", "after the first");
    assert(in_use(b) == 0);
    // Its run took the place a's had.
    assert(spill.len == one);
}

// Gathers body on c, from its head to its END, in one piece.
fn whole(c: Conn&, out: u8[>..]&, body: const u8[:], spill: u8[>..]&, b: rest::Budget&) {
    send(c, out, http::REQUEST, "", 1 << 20, spill, b);
    send(c, out, http::BODY, body, 1 << 20, spill, b);
    send(c, out, http::END, "", 1 << 20, spill, b);
}

fn test_budget_holes() {
    // The budget bounds the spill, not only the bytes in use: a body that
    // fits beside the others in bytes, but in no free space of the spill, is
    // refused rather than grow it.
    reusable[] var spill: u8[>..] = [];
    let small_text = head(20000);
    let large_text = head(30000);
    let small = small_text.len + 20000;
    let large = large_text.len + 30000;
    var runs: rest::Run[>..] = [];
    var b = rest::Budget { size: 2 * small + large - 1, runs: runs };
    let s, s_status = http::parse(small_text);
    let l, l_status = http::parse(large_text);
    assert(s_status == 200 && l_status == 200);
    let body = letters(30000);

    var first = Conn { req: s };
    var first_out: u8[>..] = [];
    send(first, first_out, http::REQUEST, "", 1 << 20, spill, b);
    var second = Conn { req: s };
    var second_out: u8[>..] = [];
    send(second, second_out, http::REQUEST, "", 1 << 20, spill, b);
    send(first, first_out, http::BODY, body[..20000], 1 << 20, spill, b);
    send(first, first_out, http::END, "", 1 << 20, spill, b);
    same(body_of(first_out), "20000 f", "the first");
    // A hole of small bytes, then the second's run.
    var third = Conn { req: l };
    var third_out: u8[>..] = [];
    send(third, third_out, http::REQUEST, "", 1 << 20, spill, b);
    same(third_out, UNAVAILABLE, "no space for it");
    assert(in_use(b) + large <= b.size);
    // Once the second has its answer, the spill is free, and holds it.
    send(second, second_out, http::BODY, body[..20000], 1 << 20, spill, b);
    send(second, second_out, http::END, "", 1 << 20, spill, b);
    var fourth = Conn { req: l };
    var fourth_out: u8[>..] = [];
    whole(fourth, fourth_out, body, spill, b);
    same(body_of(fourth_out), "30000 v", "once free");
    assert(spill.len == 2 * small);
}

fn main() {
    test_length();
    test_chunked();
    test_over_limit();
    test_budget_at_head();
    test_budget_chunked();
    test_budget_shared();
    test_budget_holes();
    print("test_gather: ok");
}
