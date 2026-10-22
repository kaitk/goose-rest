import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    let cfg = rest::prepare_security_headers(rest::security_api());
    let out = answer(expect::request("GET", "/")) { cx =>
        rest::security_headers(cx, cfg) { rest::route(cx) { rest::fail(cx, 403, "forbidden"); }; };
    };
    expect::same(out, str("HTTP/1.1 403 Forbidden\r\n", API_FIELDS,
                 "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"forbidden\"}"));
    let missing = answer(expect::request("GET", "/missing")) { cx =>
        rest::security_headers(cx, cfg) { rest::routes(cx) { cx => rest::get(cx, "/") { rest::text(cx, 200, "ok"); }; }; };
    };
    expect::same(missing, str("HTTP/1.1 404 Not Found\r\n", API_FIELDS,
                 "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    print("security headers on route and router errors: ok");
}
