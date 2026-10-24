// plod::is_email, format email's check.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";

fn main() {
    for s in ["a@b.co", "first.last+tag@example.com", "x_y@sub.do-main.org", "1@2.3"] {
        if !plod::is_email(s) { print("is_email refused ", s); assert(false); }
    }
    for s in ["", "@b.co", "a@", "a@b", "a@.b.co", "a@b.co.", "a@-b.co", "a@b-.co", "a b@c.de",
              "a@b@c.de", ".a@b.co", "a.@b.co", "\"a\"@b.co", "a@[1.2.3.4]", "a@b_c.de"] {
        if plod::is_email(s) { print("is_email took ", s); assert(false); }
    }
    print("plod::is_email: ok");
}
