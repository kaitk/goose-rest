// Path parameters, rest::param and rest::param_int, decoded, each failure's
// answer, and given a program's own http::router.
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import expect from "../";
import common;

// says, inside the route /users/:id/files/:name.
fn matched<F>(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        rest::routes(cx) { cx =>
            assert(rest::on(cx, "GET", "/users/:id/files/:name"));
            rest::route(cx) { rest::text(cx, 200, str(F(cx))); };
        };
    };
}

fn main() {
    let p = "/users/7/files/a%20b%2Fc";
    expect::same(expect::body_of(matched(get(p)) { cx => str(rest::param_int(cx, "id"), " ", rest::param(cx, "name")) }),
                 "7 a b/c");
    expect::same(expect::body_of(matched(get("/users/%37/files/x")) { cx => rest::param_int(cx, "id") }), "7");
    let out = matched(get("/users/x7/files/x")) { cx => rest::param_int(cx, "id") };
    expect::same(out, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 52\r\n\r\n",
                          bad("id: integer")));
    expect::same(expect::body_of(matched(get("/users/-/files/x")) { cx => rest::param_int(cx, "id") }),
                 bad("id: integer"));
    expect::same(expect::body_of(matched(get("/users/9223372036854775808/files/x")) { cx => rest::param_int(cx, "id") }),
                 bad("id: integer"));
    expect::same(expect::body_of(matched(get("/users/-9223372036854775807/files/x")) { cx => rest::param_int(cx, "id") }),
                 "-9223372036854775807");
    // A program's own http::router, given to the extractors.
    expect::same(expect::body_of(says(get(p)) { cx =>
        var r = http::router(cx.req);
        assert(http::on(r, "GET", "/users/:id/files/:name"));
        str(rest::param_int(cx, r, "id"), " ", rest::param(cx, r, "name"))
    }), "7 a b/c");
    print("path parameters: ok");
}
