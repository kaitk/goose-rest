import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import expect from "../";
import common;

fn secured(cfg: const plod::SecurityFields&, method: const u8[:] = "GET") -> u8[>..] {
    return answer(expect::request(method, "/")) { cx =>
        plod::security_headers(cx, cfg) { plod::text(cx, 200, "ok"); };
    };
}

fn security_header(out: const u8[:], name: const u8[:], value: const u8[:]) {
    let line = str("\r\n", name, ": ");
    let at = find(out, line);
    assert(at >= 0);
    let from = at + line.len;
    let end = find(out[from..], "\r\n");
    assert(end >= 0);
    expect::same(out[from..from + end], value);
    assert(find(out[from + end..], line) < 0);
}

fn security_omitted(out: const u8[:], name: const u8[:]) {
    assert(find(out, str("\r\n", name, ":")) < 0);
}

fn security_baseline_field(name: const u8[:], html: const u8[:], api: const u8[:]) {
    let h = plod::prepare_security_headers(plod::security_html());
    let a = plod::prepare_security_headers(plod::security_api());
    let hout = secured(h);
    let aout = secured(a);
    if html.len > 0 { security_header(hout, name, html); } else { security_omitted(hout, name); }
    if api.len > 0 { security_header(aout, name, api); } else { security_omitted(aout, name); }
}

let HTML_FIELDS = "X-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nX-XSS-Protection: 0\r\nReferrer-Policy: strict-origin-when-cross-origin\r\nStrict-Transport-Security: max-age=31536000; includeSubDomains\r\nCross-Origin-Opener-Policy: same-origin\r\nCross-Origin-Resource-Policy: same-origin\r\nX-Permitted-Cross-Domain-Policies: none\r\nX-DNS-Prefetch-Control: off\r\n";

let API_FIELDS = "X-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nStrict-Transport-Security: max-age=31536000; includeSubDomains\r\nContent-Security-Policy: frame-ancestors 'none'\r\nX-Permitted-Cross-Domain-Policies: none\r\nCache-Control: no-store\r\n";
