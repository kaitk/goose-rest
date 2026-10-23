// error: return from attempt: no enclosing call of attempt
// plod::fail outside plod::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";

fn main() {
    let e = plod::serve(http::Config { .. }) { cx => plod::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
