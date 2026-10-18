// The worker's gather budget, through rest::serve_one: a body with a length
// past it refused at its head, in the route's first run, and one it holds.
import std;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    // Through serve_one: refused in the route's first run, before the body.
    let text = str(head(100000), letters(100000));
    var runs = 0;
    let small = rest::Config { gather_budget: 100000 };
    var app = rest::NoState { .. };
    let out = rest::serve_one(text, app, St { .. }, http::Config { .. }, small) { cx =>
        runs++;
        route(cx, 1 << 20);
    };
    expect::same(out, UNAVAILABLE, "a length past the budget");
    assert(runs == 1);
    // The run is the head and the body: a budget of both takes it.
    let fits = rest::Config { gather_budget: head(100000).len + 100000 };
    expect::same(expect::body_of(rest::serve_one(text, app, St { .. }, http::Config { .. }, fits) { cx =>
        route(cx, 1 << 20);
    }), "100000 d", "a length within the budget");
    print("the budget at a body's head: ok");
}
