// docs/tutorial/07-middleware.md: middleware around the whole handler, around
// one scope, and a middleware of the program's own.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../../../";

// Runs F with the request's X-Tenant, or fails with 400 tenant_required.
inline fn tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}

fn handle(cx) {
    // Outside every route, so that its errors get the timing and CORS fields too.
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            // The routes, with the middleware that can fail inside each scope's route.
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    // Every route under /v1 needs a tenant.
                    rest::route(cx) {
                        tenant(cx) { id => v1(cx, id); };
                    };
                } else if rest::scope(cx, "/admin") {
                    // Every route under /admin needs the token.
                    rest::route(cx) {
                        rest::bearer(cx) { token =>
                            guard token == "secret" else { rest::invalid_token(cx); }
                            admin(cx);
                        };
                    };
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}

fn v1(cx, tenant: const u8[:]) {
    if rest::on(cx, "GET", "/projects") {
        rest::text(cx, 200, str("the projects of ", tenant));
    } else {
        rest::otherwise(cx);
    }
}

fn admin(cx) {
    if rest::on(cx, "POST", "/reindex") {
        rest::text(cx, 202, "reindexing");
    } else {
        rest::otherwise(cx);
    }
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
