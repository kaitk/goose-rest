// plod::path_of, on a parsed request's target and on the other forms.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";

fn main() {
    let r, s = http::parse("GET /projects/7?fields=name HTTP/1.1\r\nHost: x\r\n\r\n");
    assert(s == 200);
    assert(plod::path_of(r.target) == "/projects/7");
    assert(plod::path_of("http://x/a?b") == "/a");
    assert(plod::path_of("*") == "*");
    print("plod::path_of: ok");
}
