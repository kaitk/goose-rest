// error: no matching overload for call to rest::on
// rest::on outside rest::routes' block, whose context alone has a router.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";

fn main() {
    let out = rest::serve_one("GET / HTTP/1.1\r\n\r\n") { cx =>
        if rest::on(cx, "GET", "/") { rest::text(cx, 200, "ok"); }
    };
    print(out);
}
