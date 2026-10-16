// error: return from attempt: no enclosing call of attempt
// rest::fail outside rest::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import rest from "../../";

fn main() {
    let e = rest::serve(http::Config { .. }) { cx => rest::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
