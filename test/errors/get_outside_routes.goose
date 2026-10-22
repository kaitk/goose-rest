// error: no matching overload for call to rest::get
// rest::get outside rest::routes' block, whose context alone has a router.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";

fn main() {
    let out = rest::serve_one("GET / HTTP/1.1\r\n\r\n") { cx =>
        rest::get(cx, "/") { rest::text(cx, 200, "ok"); };
    };
    print(out);
}
