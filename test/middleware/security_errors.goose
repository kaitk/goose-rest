import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    let cfg = plod::prepare_security_headers(plod::security_api());
    let out = answer(expect::request("GET", "/")) { cx =>
        plod::security_headers(cx, cfg) { plod::route(cx) { plod::fail(cx, 403, "forbidden"); }; };
    };
    expect::same(out, str("HTTP/1.1 403 Forbidden\r\n", API_FIELDS,
                 "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"forbidden\"}"));
    let missing = answer(expect::request("GET", "/missing")) { cx =>
        plod::security_headers(cx, cfg) { plod::routes(cx) { cx => plod::get(cx, "/") { plod::text(cx, 200, "ok"); }; }; };
    };
    expect::same(missing, str("HTTP/1.1 404 Not Found\r\n", API_FIELDS,
                 "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    print("security headers on route and router errors: ok");
}
