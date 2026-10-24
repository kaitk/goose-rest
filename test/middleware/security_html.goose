import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    let cfg = plod::prepare_security_headers(plod::security_html());
    expect::same(secured(cfg), str("HTTP/1.1 200 OK\r\n", HTML_FIELDS, OK));
    let direct = answer(expect::request("GET", "/")) { cx =>
        let before = cx.scratch.len;
        plod::security_headers(cx, cfg) {
            assert(cx.scratch.len == before);
            expect::same(cx.out.common, cfg.fields);
            plod::text(cx, 200, "ok");
        };
        assert(cx.scratch.len == before);
        expect::same(cx.out.common, "");
    };
    expect::same(direct, str("HTTP/1.1 200 OK\r\n", HTML_FIELDS, OK));
    let common = "X-Outer: kept\r\n";
    let combined = answer(expect::request("GET", "/")) { cx =>
        cx.out.common = common;
        let before = cx.scratch.len;
        plod::security_headers(cx, cfg) {
            assert(cx.scratch.len == before + common.len + cfg.fields.len);
            plod::text(cx, 200, "ok");
        };
        expect::same(cx.out.common, common);
    };
    expect::same(combined, str("HTTP/1.1 200 OK\r\n", common, HTML_FIELDS, OK));
    expect::same(secured(cfg, "HEAD"), str("HTTP/1.1 200 OK\r\n", HTML_FIELDS,
                 "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\n"));
    print("security headers HTML: ok");
}
