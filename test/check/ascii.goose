// plod::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";

fn main() {
    assert(plod::is_ascii(""));
    assert(plod::is_ascii("#ff0000 ~\x7F"));
    assert(!plod::is_ascii("hané"));
    assert(!plod::is_ascii("\x80"));
    assert(!plod::is_ascii("😀"));
    print("plod::is_ascii: ok");
}
