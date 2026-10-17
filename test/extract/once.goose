// rest::once: a value computed at the first call of a request, and kept for
// the calls after.
import std;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    expect::same(expect::body_of(says(get("/")) { cx =>
        var total = 0;
        for i in 3 {
            total += rest::once(cx.state.user) { cx.state.calls++; 41 };
        }
        str(total, " in ", cx.state.calls, " call")
    }), "123 in 1 call");
    print("rest::once: ok");
}
