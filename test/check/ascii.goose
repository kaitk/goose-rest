// plod::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";

fn main() {
    assert(plod::is_ascii(""));
    assert(plod::is_ascii("#ff0000 ~\x7F"));
    assert(!plod::is_ascii("hané"));
    assert(!plod::is_ascii("\x80"));
    assert(!plod::is_ascii("😀"));
    print("plod::is_ascii: ok");
}
