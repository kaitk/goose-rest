// Unit tests for the package, and that it reaches goose-http at its pin.
// scripts/test-unit.sh runs them through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@04791ac50b69d99e93c08dc2c3f3ff8d4ab1867c";
import rest from "../";

fn test_path_of() {
    let r, s = http::parse("GET /projects/7?fields=name HTTP/1.1\r\nHost: x\r\n\r\n");
    assert(s == 200);
    assert(rest::path_of(r.target) == "/projects/7");
    assert(rest::path_of("http://x/a?b") == "/a");
    assert(rest::path_of("*") == "*");
}

fn main() {
    test_path_of();
    print("test_rest: ok");
}
