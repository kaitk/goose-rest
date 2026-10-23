// error: no matching overload for call to show
// A typed route helper given a context whose per-request state is another
// type than the one it names.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";

struct Session { user: i64 = 0 }
struct Other { n: i64 = 0 }

type Cx = plod::Cx<Session, plod::NoState, plod::NoRouter>;

fn show(cx: Cx&) { plod::text(cx, 200, str(cx.state.user)); }

fn main() {
    var app = plod::NoState { .. };
    let out = plod::serve_one("GET / HTTP/1.1\r\n\r\n", app, Other { .. }) { cx => show(cx); };
    print(out);
}
