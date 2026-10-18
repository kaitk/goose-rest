// error: no matching overload for call to show
// A typed route helper given a context whose per-request state is another
// type than the one it names.
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";

struct Session { user: i64 = 0 }
struct Other { n: i64 = 0 }

type Cx = rest::Cx<Session, rest::NoState, rest::NoRouter>;

fn show(cx: Cx&) { rest::text(cx, 200, str(cx.state.user)); }

fn main() {
    var app = rest::NoState { .. };
    let out = rest::serve_one("GET / HTTP/1.1\r\n\r\n", app, Other { .. }) { cx => show(cx); };
    print(out);
}
