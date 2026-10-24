// Fixed response fields, prepared before serving and selected per request.
namespace plod;

import std;
import http from "github.com/kaitk/goose-http@v0.5.10";

struct SecurityHeaders {
    nosniff: bool = true,
    frame_options: const u8[:] = "DENY",
    xss_protection: bool = true,
    referrer_policy: const u8[:] = "strict-origin-when-cross-origin",
    hsts: bool = true,
    hsts_max_age: i64 = 31536000,
    hsts_subdomains: bool = true,
    hsts_preload: bool = false,
    opener_policy: const u8[:] = "same-origin",
    resource_policy: const u8[:] = "same-origin",
    embedder_policy: const u8[:] = "",
    content_security_policy: const u8[:] = "",
    report_only: bool = false,
    permissions_policy: const u8[:] = "",
    cross_domain_policy: const u8[:] = "none",
    dns_prefetch_control: bool = true,
    cache_control: const u8[:] = "",
    no_cache: bool = false,
}

fn security_html() -> SecurityHeaders { SecurityHeaders { .. } }

fn security_api() -> SecurityHeaders {
    SecurityHeaders { xss_protection: false, referrer_policy: "",
                      opener_policy: "", resource_policy: "", dns_prefetch_control: false,
                      content_security_policy: "frame-ancestors 'none'",
                      cache_control: "no-store", .. }
}

// Keep this value in worker setup and pass it by reference to the middleware.
struct SecurityFields { fields: u8[] }

fn prepare_security_headers(c: SecurityHeaders) -> SecurityFields {
    return SecurityFields { fields: security_fields(c) };
}

fn security_choice(value: const u8[:], choices: const u8[:]) -> bool {
    var found = value.len == 0;
    each_split(choices, ' ') { if value == it { found = true; } };
    return found;
}

fn security_field(out: u8[>..]&, name: const u8[:], value: const u8[:]) {
    guard value.len > 0 else { return; }
    assert(http::is_field(name, value));
    format(out, name, ": ", value, "\r\n");
}

fn security_fields(c: const SecurityHeaders&) -> u8[>..] {
    assert(security_choice(c.frame_options, "DENY SAMEORIGIN"));
    assert(security_choice(c.referrer_policy,
        "no-referrer no-referrer-when-downgrade origin origin-when-cross-origin same-origin strict-origin strict-origin-when-cross-origin unsafe-url"));
    assert(security_choice(c.opener_policy, "same-origin same-origin-allow-popups unsafe-none"));
    assert(security_choice(c.resource_policy, "same-origin same-site cross-origin"));
    assert(security_choice(c.embedder_policy, "require-corp credentialless unsafe-none"));
    assert(c.hsts_max_age >= 0);
    var out: u8[>..] = [];
    if c.nosniff { out.append("X-Content-Type-Options: nosniff\r\n"); }
    security_field(out, "X-Frame-Options", c.frame_options);
    if c.xss_protection { out.append("X-XSS-Protection: 0\r\n"); }
    security_field(out, "Referrer-Policy", c.referrer_policy);
    if c.hsts {
        format(out, "Strict-Transport-Security: max-age=", c.hsts_max_age);
        if c.hsts_subdomains { out.append("; includeSubDomains"); }
        if c.hsts_preload { out.append("; preload"); }
        out.append("\r\n");
    }
    security_field(out, "Cross-Origin-Opener-Policy", c.opener_policy);
    security_field(out, "Cross-Origin-Resource-Policy", c.resource_policy);
    security_field(out, "Cross-Origin-Embedder-Policy", c.embedder_policy);
    security_field(out, if c.report_only { "Content-Security-Policy-Report-Only" }
                        else { "Content-Security-Policy" }, c.content_security_policy);
    security_field(out, "Permissions-Policy", c.permissions_policy);
    security_field(out, "X-Permitted-Cross-Domain-Policies", c.cross_domain_policy);
    if c.dns_prefetch_control { out.append("X-DNS-Prefetch-Control: off\r\n"); }
    if c.no_cache {
        out.append("Cache-Control: no-cache, no-store, max-age=0, must-revalidate\r\nPragma: no-cache\r\nExpires: 0\r\n");
    } else {
        security_field(out, "Cache-Control", c.cache_control);
    }
    return out;
}

// Put outside route so that route writes errors while these fields are active.
// Inside plod::routes, F runs in plod::scoped.
// Select one prepared policy here; nesting this middleware is unsupported.
inline fn security_headers<S, A, R, F>(cx: Cx<S, A, R>&, cfg: const SecurityFields&) {
    guard cx.kind == http::REQUEST else { scoped(cx) { F(); }; return; }
    let common = cx.out.common;
    let from = cx.scratch.len;
    if common.len == 0 {
        cx.out.common = cfg.fields;
    } else {
        cx.scratch.append(common);
        cx.scratch.append(cfg.fields);
        cx.out.common = cx.scratch[from..];
    }
    let mark = cx.out.buf.len;
    scoped(cx) { F(); };
    if cx.out.buf.len == mark {
        if common.len == 0 {
            var k .= cx.kept;
            if k && !k.taken && answers_later(cx) {
                // keep_fields records scratch offsets, not the prepared slice.
                let at = cx.scratch.len;
                cx.scratch.append(cfg.fields);
                keep_fields(cx, at, cx.scratch.len);
            }
        } else {
            keep_fields(cx, from, from + common.len + cfg.fields.len);
        }
    }
    cx.out.common = common;
}
