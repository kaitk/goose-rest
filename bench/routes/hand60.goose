// routes60.goose's 60 routes written by hand on goose-rest, as a program
// without a schema writes them: rest::serve_epoll, rest::scope for each
// prefix, the routes inside rest::route, and each path parameter read as
// test/gen/routes.json types it, as gen60 reads them. Each route answers "ok"
// as routes60's do, and rest::otherwise answers a 404 and a 405 in the JSON
// error shape, as gen60 does. It checks no session; gen60 calls a check that
// accepts every request. GET /v1/projects reads its three query parameters.
//
//   hand60 http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../../";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

fn handle(cx) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/health") {
        ok(cx);
    } else if rest::scope(r, "/v1") {
        rest::route(cx) { v1(cx, r); };
    } else {
        rest::otherwise(cx, r);
    }
}

fn v1(cx, r: http::Router&) {
    if rest::scope(r, "/auth") {
        if http::on(r, "POST", "/login") { ok(cx); }
        else if http::on(r, "POST", "/logout") { ok(cx); }
        else if http::on(r, "POST", "/refresh") { ok(cx); }
        else if http::on(r, "GET", "/session") { ok(cx); }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/users") {
        if http::on(r, "GET", "/me") { ok(cx); }
        else if http::on(r, "PATCH", "/me") { ok(cx); }
        else if http::on(r, "GET", "/me/settings") { ok(cx); }
        else if http::on(r, "PUT", "/me/settings") { ok(cx); }
        else if http::on(r, "GET", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/:id/avatar") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PUT", "/:id/avatar") { rest::param_int(cx, r, "id"); ok(cx); }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/orgs") {
        if http::on(r, "GET", "") { ok(cx); }
        else if http::on(r, "POST", "") { ok(cx); }
        else if http::on(r, "GET", "/:org") { rest::param(cx, r, "org"); ok(cx); }
        else if http::on(r, "PATCH", "/:org") { rest::param(cx, r, "org"); ok(cx); }
        else if http::on(r, "DELETE", "/:org") { rest::param(cx, r, "org"); ok(cx); }
        else if http::on(r, "GET", "/:org/members") { rest::param(cx, r, "org"); ok(cx); }
        else if http::on(r, "POST", "/:org/members") { rest::param(cx, r, "org"); ok(cx); }
        else if http::on(r, "DELETE", "/:org/members/:user") {
            rest::param(cx, r, "org");
            rest::param_int(cx, r, "user");
            ok(cx);
        }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/projects") {
        if http::on(r, "GET", "") {
            rest::query_int(cx, "page");
            rest::query_bool(cx, "archived");
            rest::query(cx, "q");
            ok(cx);
        }
        else if http::on(r, "POST", "") { ok(cx); }
        else if http::on(r, "GET", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PATCH", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/:id/archive") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/:id/restore") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/:id/members") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/:id/members") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/:id/members/:user") {
            rest::param_int(cx, r, "id");
            rest::param_int(cx, r, "user");
            ok(cx);
        }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/tasks") {
        if http::on(r, "GET", "") { ok(cx); }
        else if http::on(r, "POST", "") { ok(cx); }
        else if http::on(r, "GET", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PATCH", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/:id/assign") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/:id/comments") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/:id/comments") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PATCH", "/:id/comments/:comment") {
            rest::param_int(cx, r, "id");
            rest::param(cx, r, "comment");
            ok(cx);
        }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/files") {
        if http::on(r, "GET", "") { ok(cx); }
        else if http::on(r, "POST", "") { ok(cx); }
        else if http::on(r, "GET", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/:id/content") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PUT", "/:id/content") { rest::param_int(cx, r, "id"); ok(cx); }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/webhooks") {
        if http::on(r, "GET", "") { ok(cx); }
        else if http::on(r, "POST", "") { ok(cx); }
        else if http::on(r, "GET", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "PATCH", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/:id/deliveries") { rest::param_int(cx, r, "id"); ok(cx); }
        else { rest::otherwise(cx, r); }
    } else if rest::scope(r, "/reports") {
        if http::on(r, "GET", "/time") { ok(cx); }
        else if http::on(r, "GET", "/time/:user") { rest::param_int(cx, r, "user"); ok(cx); }
        else if http::on(r, "GET", "/budget") { ok(cx); }
        else if http::on(r, "GET", "/exports") { ok(cx); }
        else if http::on(r, "POST", "/exports") { ok(cx); }
        else if http::on(r, "GET", "/exports/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "DELETE", "/exports/:id") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "POST", "/exports/:id/cancel") { rest::param_int(cx, r, "id"); ok(cx); }
        else if http::on(r, "GET", "/exports/:id/download") { rest::param_int(cx, r, "id"); ok(cx); }
        else { rest::otherwise(cx, r); }
    } else {
        rest::otherwise(cx, r);
    }
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve_epoll(cfg) { cx => handle(cx) };
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    guard argv.len >= 2 && argv[1] == "http" else {
        write_stderr("usage: hand60 http [port]\n");
        exit(2);
    }
    var cfg = http::Config { workers: 1, .. };
    if argv.len > 2 {
        let p, ok = parse_int(argv[2]);
        guard ok && p > 0 && p < 65536 else { write_stderr("bad port\n"); exit(2); }
        cfg.port = p as i32;
    }
    var w: u8[>..] = [];
    if env("WORKERS", w) {
        let n, ok = parse_int(w);
        guard ok && n > 0 else { write_stderr("WORKERS must be a positive number\n"); exit(2); }
        cfg.workers = n;
    }
    let s = http::stop_on_signals();
    guard s == 0 else { http::report(http::Error { call: "sigaction", code: -s }); exit(1); }
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
