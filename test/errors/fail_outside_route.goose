// error: return from attempt: no enclosing call of attempt
// rest::fail outside rest::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../";

fn main() {
    let e = rest::serve(http::Config { .. }) { cx => rest::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
