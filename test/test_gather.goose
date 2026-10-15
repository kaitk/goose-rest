// Bodies gathered for rest::body, event by event as serve gathers them: a
// body with a Content-Length in one run of its exact size, which never
// moves; a chunked one, whose run doubles; and each past its route's limit.
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

// The route: the body of at most limit bytes, answered with its length and
// its last byte.
fn echo(cx, limit: i64) {
    let data = rest::body(cx, limit);
    rest::text(cx, 200, str(data.len, " ", data[data.len - 1..]));
}

// Hands text's head to the route, as serve does for a body that didn't come
// with it, then size bytes of body in pieces of 8 KB and the END, unless the
// exchange has ended. caps holds the run's capacity after the head and each
// piece. Returns the answer.
fn gather(text: const u8[:], size: i64, limit: i64, caps: i64[>..]&) -> u8[>..] {
    let req, status = http::parse(text);
    assert(status == 200);
    var out: u8[>..] = [];
    var keep = true;
    var stream = http::Stream { .. };
    var st = rest::Slot<rest::NoState> { state: rest::NoState { .. } };
    var app = rest::NoState { .. };
    reusable[] var spill: u8[>..] = [];
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: stream };
    let body = letters(size);
    fn send(kind: u8, data: const u8[:]) {
        rest::deliver(http::Event { kind: kind, req: req, data: data, whole: false, trailers: "" }, st, app, reply,
                      spill) { cx => echo(cx, limit); };
    }
    send(http::REQUEST, "");
    caps.push(st.ex.cap);
    var at = 0;
    while at < size && out.len == 0 {
        let end = min(at + 8192, size);
        let start = st.ex.at;
        let room = st.ex.cap;
        send(http::BODY, body[at..end]);
        caps.push(st.ex.cap);
        // A run that kept its capacity kept its place.
        assert(st.ex.cap != room || st.ex.at == start || out.len > 0);
        at = end;
    }
    if out.len == 0 { send(http::END, ""); }
    assert((st.ex.mode & rest::GATHERING) == 0 && st.ex.cap == 0);
    if !keep { out.append("\r\nclosed"); }
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

fn main() {
    test_length();
    test_chunked();
    test_over_limit();
    print("test_gather: ok");
}
