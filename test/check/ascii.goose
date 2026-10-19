// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
