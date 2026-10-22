// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
