import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    let cfg = rest::prepare_security_headers(rest::security_api());
    expect::same(secured(cfg), str("HTTP/1.1 200 OK\r\n", API_FIELDS, OK));
    let empty = answer(expect::request("GET", "/")) { cx =>
        rest::security_headers(cx, cfg) { rest::empty(cx, 204); };
    };
    expect::same(empty, str("HTTP/1.1 204 No Content\r\n", API_FIELDS, "\r\n"));
    print("security headers API: ok");
}
