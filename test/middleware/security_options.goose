import std;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    var c = plod::security_html();
    c.nosniff = false;
    c.frame_options = "SAMEORIGIN";
    c.xss_protection = false;
    c.hsts_max_age = 0;
    c.hsts_subdomains = false;
    c.hsts_preload = true;
    c.content_security_policy = "default-src 'self'";
    c.report_only = true;
    c.permissions_policy = "camera=()";
    c.cross_domain_policy = "master-only";
    c.dns_prefetch_control = false;
    c.no_cache = true;
    let cfg = plod::prepare_security_headers(c);
    let out = secured(cfg);
    security_omitted(out, "X-Content-Type-Options");
    security_omitted(out, "X-XSS-Protection");
    security_omitted(out, "X-DNS-Prefetch-Control");
    security_omitted(out, "Content-Security-Policy");
    security_header(out, "X-Frame-Options", "SAMEORIGIN");
    security_header(out, "Strict-Transport-Security", "max-age=0; preload");
    security_header(out, "Content-Security-Policy-Report-Only", "default-src 'self'");
    security_header(out, "Permissions-Policy", "camera=()");
    security_header(out, "X-Permitted-Cross-Domain-Policies", "master-only");
    security_header(out, "Cache-Control", "no-cache, no-store, max-age=0, must-revalidate");
    security_header(out, "Pragma", "no-cache");
    security_header(out, "Expires", "0");
    for policy in ["no-referrer", "no-referrer-when-downgrade", "origin", "origin-when-cross-origin",
                   "same-origin", "strict-origin", "strict-origin-when-cross-origin", "unsafe-url"] {
        var options = plod::security_html();
        options.referrer_policy = policy;
        let prepared = plod::prepare_security_headers(options);
        security_header(secured(prepared), "Referrer-Policy", policy);
    }
    for policy in ["same-origin", "same-origin-allow-popups", "unsafe-none", ""] {
        var options = plod::security_html();
        options.opener_policy = policy;
        let prepared = plod::prepare_security_headers(options);
        let response = secured(prepared);
        if policy.len > 0 { security_header(response, "Cross-Origin-Opener-Policy", policy); }
        else { security_omitted(response, "Cross-Origin-Opener-Policy"); }
    }
    for policy in ["same-origin", "same-site", "cross-origin", ""] {
        var options = plod::security_html();
        options.resource_policy = policy;
        let prepared = plod::prepare_security_headers(options);
        let response = secured(prepared);
        if policy.len > 0 { security_header(response, "Cross-Origin-Resource-Policy", policy); }
        else { security_omitted(response, "Cross-Origin-Resource-Policy"); }
    }
    for policy in ["require-corp", "credentialless", "unsafe-none", ""] {
        var options = plod::security_html();
        options.embedder_policy = policy;
        let prepared = plod::prepare_security_headers(options);
        let response = secured(prepared);
        if policy.len > 0 { security_header(response, "Cross-Origin-Embedder-Policy", policy); }
        else { security_omitted(response, "Cross-Origin-Embedder-Policy"); }
    }
    c.frame_options = "";
    c.referrer_policy = "";
    c.hsts = false;
    c.content_security_policy = "";
    c.permissions_policy = "";
    c.cross_domain_policy = "";
    let omitted = plod::prepare_security_headers(c);
    let response = secured(omitted);
    security_omitted(response, "X-Frame-Options");
    security_omitted(response, "Referrer-Policy");
    security_omitted(response, "Strict-Transport-Security");
    security_omitted(response, "Content-Security-Policy-Report-Only");
    security_omitted(response, "Permissions-Policy");
    security_omitted(response, "X-Permitted-Cross-Domain-Policies");
    var api = plod::security_api();
    api.hsts = false;
    let without_hsts = plod::prepare_security_headers(api);
    security_omitted(secured(without_hsts), "Strict-Transport-Security");
    print("security headers options and omissions: ok");
}
