// rest::path_of, on a parsed request's target and on the other forms.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../../";

fn main() {
    let r, s = http::parse("GET /projects/7?fields=name HTTP/1.1\r\nHost: x\r\n\r\n");
    assert(s == 200);
    assert(rest::path_of(r.target) == "/projects/7");
    assert(rest::path_of("http://x/a?b") == "/a");
    assert(rest::path_of("*") == "*");
    print("rest::path_of: ok");
}
