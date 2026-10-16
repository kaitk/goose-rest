// rest::serve_one with bodies: one that comes whole with its head, a long
// one gathered and the route run again with it whole, one past rest::body's
// limit, and one past the server's max_body.
import std;
import http from "github.com/kaitk/goose-http@v0.3.4";
import rest from "../../";
import expect from "../";

fn put(n: i64) -> u8[>..] {
    var text = str("PUT /up HTTP/1.1\r\nHost: x\r\nContent-Length: ", n, "\r\n\r\n");
    for i in n { text.push('a' + (i % 26) as u8); }
    return text;
}

// A route that counts its runs up to its rest::body, then answers with the
// body's length and the runs.
fn upload(text: const u8[:], limit: i64 = rest::BODY_LIMIT) -> u8[>..], i64 {
    var runs = 0;
    let out = rest::serve_one(text) { cx =>
        runs++;
        let data = rest::body(cx, limit);
        rest::text(cx, 200, str(data.len, " ", data[data.len - 1..]));
    };
    return out, runs;
}

fn main() {
    // A body that fits in the read buffer with its head comes whole.
    let short, once = upload(put(100));
    expect::same(expect::body_of(short), "100 v", "short body");
    assert(once == 1);
    // A longer one comes in pieces, gathered, and the route runs again.
    let long, twice = upload(put(100000));
    expect::same(expect::body_of(long), "100000 d", "long body");
    assert(twice == 2);
    // Past rest::body's limit: refused from its Content-Length, in the first run.
    let big, runs = upload(put(100000), 50000);
    expect::same(expect::body_of(big), "{\"error\":\"payload_too_large\"}", "past the limit");
    assert(runs == 1);
    // Past the server's max_body: goose-http refuses it before the route.
    expect::same(expect::status_of(upload(put(2000000))), "HTTP/1.1 413 Content Too Large", "past max_body");
    print("rest::serve_one's bodies: ok");
}
