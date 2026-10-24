// plod::once: a value computed at the first call of a request, and kept for
// the calls after.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    expect::same(expect::body_of(says(get("/")) { cx =>
        var total = 0;
        for i in 3 {
            total += plod::once(cx.state.user) { cx.state.calls++; 41 };
        }
        str(total, " in ", cx.state.calls, " call")
    }), "123 in 1 call");
    print("plod::once: ok");
}
