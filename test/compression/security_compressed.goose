import std;
import http from "github.com/kaitk/goose-http@v0.5.1";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    var options = rest::security_api();
    options.frame_options = "";
    let cfg = rest::prepare_security_headers(options);
    let out = rest::serve_one(expect::request("GET", "/big", GZIP)) { cx =>
        rest::security_headers(cx, cfg) {
            rest::compressed(cx) { cx => rest::json_bytes(cx, 200, records()); };
        };
    };
    assert(find(out, "X-Frame-Options:") < 0 && find(out, "X-XSS-Protection:") < 0);
    assert(find(out, "Content-Security-Policy: frame-ancestors 'none'\r\n") >= 0);
    assert(find(out, "Cache-Control: no-store\r\n") >= 0);
    assert(find(out, "Content-Encoding: gzip\r\n") >= 0);
    expect::same(expect::body_of(out), coded(compress::GZIP, 1));
    print("security headers with compression: ok");
}
