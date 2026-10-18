// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
