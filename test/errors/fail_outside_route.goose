// error: return from attempt: no enclosing call of attempt
// rest::fail outside rest::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@2c5280c76ade5f70f69a80cd68f73b03d5b34252";
import rest from "../../";

fn main() {
    let e = rest::serve(http::Config { .. }) { cx => rest::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
