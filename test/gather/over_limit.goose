// Bodies past their route's limit: one with a Content-Length refused at its
// head, and a chunked one once it passes, which closes the connection.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    // A Content-Length over the limit: 413 at the head, nothing gathered.
    var none: i64[>..] = [];
    expect::same(expect::body_of(gather(head(30000), 30000, 20000, none)), "{\"error\":\"payload_too_large\"}",
                 "a length");
    assert(none.len == 1 && none[0] == 0);
    // A chunked body: 413 once it passes the limit, and the connection closes.
    var caps: i64[>..] = [];
    expect::same(expect::body_of(gather(head(-1), 30000, 20000, caps)),
                 "{\"error\":\"payload_too_large\"}\r\nclosed", "chunked");
    assert(caps.len == 4);
    print("bodies past the limit: ok");
}
