// error: no matching overload for call to plod::get
// plod::get outside plod::routes' block, whose context alone has a router.
import std;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../";

fn main() {
    let out = plod::serve_one("GET / HTTP/1.1\r\n\r\n") { cx =>
        plod::get(cx, "/") { plod::text(cx, 200, "ok"); };
    };
    print(out);
}
