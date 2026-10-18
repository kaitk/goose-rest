// rest::is_ascii, format ascii's check.
import std;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "../../";

fn main() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
    print("rest::is_ascii: ok");
}
