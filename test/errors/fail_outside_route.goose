// error: return from attempt: no enclosing call of attempt
// rest::fail outside rest::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";

fn main() {
    let e = rest::serve(http::Config { .. }) { cx => rest::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
