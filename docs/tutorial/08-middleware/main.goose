// docs/tutorial.md, section 8: middleware around the whole handler, around
// one scope, and a middleware of the program's own.
import std;
import os;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../../../";

// Runs F with the request's X-Tenant, or fails with 400 tenant_required.
inline fn tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}

fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            var r = http::router(cx.req);
            if http::on(r, "GET", "/health") {
                rest::text(cx, 200, "ok");
            } else if rest::scope(r, "/v1") {
                rest::route(cx) {
                    tenant(cx) { id => v1(cx, r, id); };
                };
            } else if rest::scope(r, "/admin") {
                rest::route(cx) {
                    rest::bearer(cx) { token =>
                        guard token == "secret" else { rest::invalid_token(cx); }
                        admin(cx, r);
                    };
                };
            } else {
                rest::otherwise(cx, r);
            }
        };
    };
}

fn v1(cx, r: http::Router&, tenant: const u8[:]) {
    if http::on(r, "GET", "/projects") {
        rest::text(cx, 200, str("the projects of ", tenant));
    } else {
        rest::otherwise(cx, r);
    }
}

fn admin(cx, r: http::Router&) {
    if http::on(r, "POST", "/reindex") {
        rest::text(cx, 202, "reindexing");
    } else {
        rest::otherwise(cx, r);
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
