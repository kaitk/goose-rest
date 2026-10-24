// error: return from attempt: no enclosing call of attempt
// plod::fail outside plod::route: serve's handler runs outside any route, so
// the failure has no route to leave.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";

fn main() {
    let e = plod::serve(http::Config { .. }) { cx => plod::fail(cx, 404, "x"); };
    http::exit_on_error(e);
}
