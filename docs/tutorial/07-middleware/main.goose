// docs/tutorial/07-middleware.md: middleware around the whole handler, around
// one scope, and a middleware of the program's own.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../../";

// Runs F with the request's X-Tenant, or fails with 400 tenant_required.
inline fn resolve_tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}

// The routes that need the token and a tenant: one level for a scope.
inline fn member_routes<F>(cx) {
    rest::bearer(cx) { token =>
        guard token == "secret" else { rest::invalid_token(cx); }
        resolve_tenant(cx) { tenant => F(tenant); };
    };
}

fn handle(cx) {
    // Around every route, so that every answer gets the timing and CORS fields.
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            // The routes, with the middleware that can fail inside each scope.
            rest::routes(cx) { cx =>
                rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
                rest::scope(cx, "/v1") {
                    // Every route under /v1 needs a tenant.
                    resolve_tenant(cx) { tenant => v1(cx, tenant); };
                };
                rest::scope(cx, "/admin") {
                    // Every route under /admin needs the token.
                    rest::bearer(cx) { token =>
                        guard token == "secret" else { rest::invalid_token(cx); }
                        admin(cx);
                    };
                };
                rest::scope(cx, "/v2") {
                    // The token and a tenant, as the member_routes stack.
                    member_routes(cx) { tenant => v1(cx, tenant); };
                };
            };
        };
    };
}

fn v1(cx, tenant: const u8[:]) {
    rest::get(cx, "/projects") { rest::text(cx, 200, str("the projects of ", tenant)); };
}

fn admin(cx) {
    rest::post(cx, "/reindex") { rest::text(cx, 202, "reindexing"); };
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, .. };
    http::run(cfg, worker);
}
