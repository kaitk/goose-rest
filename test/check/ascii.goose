// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
