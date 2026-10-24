import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import compress from "github.com/kaitk/goose-compress@v0.1.4";
import plod from "../../";
import plod.compression;
import expect from "../";
import common;

fn main() {
    var options = plod::security_api();
    options.frame_options = "";
    let cfg = plod::prepare_security_headers(options);
    let out = plod::serve_one(expect::request("GET", "/big", GZIP)) { cx =>
        plod::security_headers(cx, cfg) {
            plod::compressed(cx) { cx => plod::json_bytes(cx, 200, records()); };
        };
    };
    assert(find(out, "X-Frame-Options:") < 0 && find(out, "X-XSS-Protection:") < 0);
    assert(find(out, "Content-Security-Policy: frame-ancestors 'none'\r\n") >= 0);
    assert(find(out, "Cache-Control: no-store\r\n") >= 0);
    assert(find(out, "Content-Encoding: gzip\r\n") >= 0);
    expect::same(expect::body_of(out), coded(compress::GZIP, 1));
    print("security headers with compression: ok");
}
