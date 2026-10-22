// plod::code_points, which the generated readers call: the count of a
// string's code points, or -1 for one that isn't UTF-8.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";

fn main() {
    assert(plod::code_points("") == 0);
    assert(plod::code_points("goose") == 5);
    assert(plod::code_points("hané") == 4);
    assert(plod::code_points("€𝄞") == 2);
    assert(plod::code_points("\xF4\x8F\xBF\xBF") == 1);
    // A stray continuation byte, an overlong form, a truncated sequence, a
    // surrogate, a code point past U+10FFFF, and a lead byte no code point has.
    for b in ["\x80", "\xC0\x80", "\xC3", "\xE0\x80\x80", "\xED\xA0\x80", "\xF4\x90\x80\x80",
              "\xF5\x80\x80\x80", "\xE2\x82", "a\xE2\x82\x28"] {
        if plod::code_points(b) != -1 { print("code_points took ", b); assert(false); }
    }
    print("plod::code_points: ok");
}
