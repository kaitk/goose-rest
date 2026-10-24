import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";

enum Use { None, Response }
struct St { use: Use = Use.None }

fn main() {
    let cookie = http::Cookie { name: "sid", value: "abc", max_age: 3600, expires: 3600,
                               path: "/api", domain: "example.com", secure: true,
                               http_only: true, same_site: "Lax" };
    let out = plod::serve_one(expect::request("GET", "/")) { cx =>
        http::start(cx.out, 200);
        assert(plod::set_cookie(cx, cookie));
        assert(plod::set_cookie(cx, http::Cookie { name: "theme", value: "dark" }));
        http::finish(cx.out, http::TEXT, "ok");
    };
    expect::same(out, str("HTTP/1.1 200 OK\r\nSet-Cookie: sid=abc; Max-Age=3600; ",
                          "Expires=Thu, 01 Jan 1970 01:00:00 GMT; Path=/api; Domain=example.com; ",
                          "Secure; HttpOnly; SameSite=Lax\r\nSet-Cookie: theme=dark\r\n",
                          "Content-Type: text/plain\r\nContent-Length: 2\r\n\r\nok"), "set cookies");
    var app = plod::NoState { .. };
    let cleared = plod::serve_one(expect::request("GET", "/"), app, St { .. }) { cx =>
        plod::begin(cx, 200, "text/plain", 2, Use.Response);
        assert(plod::clear_cookie(cx, cookie));
        plod::send(cx, "ok");
        plod::end(cx);
    };
    expect::same(cleared, str("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/plain\r\n",
                              "Set-Cookie: sid=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; ",
                              "Path=/api; Domain=example.com; Secure; HttpOnly; SameSite=Lax\r\n\r\nok"), "clear cookie");
    let refused = plod::serve_one(expect::request("GET", "/")) { cx =>
        http::start(cx.out, 204);
        assert(!plod::set_cookie(cx, http::Cookie { name: "bad name", value: "abc" }));
        assert(!plod::set_cookie(cx, http::Cookie { name: "sid", value: "abc\r\nInjected: yes" }));
        assert(!plod::set_cookie(cx, http::Cookie { name: "sid", value: "abc", path: "/; Secure" }));
        assert(!plod::set_cookie(cx, http::Cookie { name: "sid", value: "abc", domain: "x\nInjected: yes" }));
        assert(!plod::set_cookie(cx, http::Cookie { name: "sid", value: "abc", same_site: "invalid" }));
        assert(!plod::clear_cookie(cx, http::Cookie { name: "bad name", value: "abc" }));
        http::finish(cx.out, http::NO_TYPE, "");
    };
    expect::same(refused, "HTTP/1.1 204 No Content\r\n\r\n", "HTTP validation writes nothing");
    print("cookies out: ok");
}
