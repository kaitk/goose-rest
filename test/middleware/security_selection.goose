import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    let defaults = plod::security_html();
    var options = defaults;
    options.frame_options = "";
    options.content_security_policy = "frame-ancestors https://partner.example";
    options.resource_policy = "cross-origin";
    options.hsts = false;
    let site = plod::prepare_security_headers(defaults);
    let embed = plod::prepare_security_headers(options);
    for path in ["/", "/embed"] {
        let out = answer(expect::request("GET", path, "Origin: https://a.example\r\n")) { cx =>
            plod::security_headers(cx, if starts_with(cx.req.target, "/embed") { embed } else { site }) {
                plod::timed(cx, false) {
                    plod::cors(cx, CORS) {
                        plod::routes(cx) { cx => plod::text(cx, 200, "ok"); };
                    };
                };
            };
            expect::same(cx.out.common, "");
        };
        if path == "/embed" {
            security_omitted(out, "X-Frame-Options");
            security_omitted(out, "Strict-Transport-Security");
            security_header(out, "Content-Security-Policy", "frame-ancestors https://partner.example");
            security_header(out, "Cross-Origin-Resource-Policy", "cross-origin");
        } else {
            security_header(out, "X-Frame-Options", "DENY");
            security_header(out, "Strict-Transport-Security", "max-age=31536000; includeSubDomains");
            security_omitted(out, "Content-Security-Policy");
            security_header(out, "Cross-Origin-Resource-Policy", "same-origin");
        }
        security_header(out, "X-Content-Type-Options", "nosniff");
        security_header(out, "Access-Control-Allow-Origin", "https://a.example");
        let after_time = timing_in(out, 0);
        assert(find(after_time, "Access-Control-Allow-Origin:") >= 0);
        expect::same(expect::body_of(out), "ok");
    }
    expect::same(secured(site), str("HTTP/1.1 200 OK\r\n", HTML_FIELDS, OK));
    print("security headers selected by request target: ok");
}
