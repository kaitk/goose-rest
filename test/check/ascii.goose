// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
