// routes60.goose's 60 routes written by hand on goose-rest, as a program
// without a schema writes them: rest::serve_epoll, rest::routes, rest::scope
// for each prefix, the routes inside rest::route, and each path parameter read as
// test/gen/routes.json types it, as gen60 reads them. Each route answers "ok"
// as routes60's do, and rest::otherwise answers a 404 and a 405 in the JSON
// error shape, as gen60 does. It checks no session; gen60 calls a check that
// accepts every request. GET /v1/projects reads its three query parameters.
//
//   hand60 http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            ok(cx);
        } else if rest::scope(cx, "/v1") {
            rest::route(cx) { v1(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn v1(cx) {
    if rest::scope(cx,"/auth") {
        if rest::on(cx,"POST", "/login") { ok(cx); }
        else if rest::on(cx,"POST", "/logout") { ok(cx); }
        else if rest::on(cx,"POST", "/refresh") { ok(cx); }
        else if rest::on(cx,"GET", "/session") { ok(cx); }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/users") {
        if rest::on(cx,"GET", "/me") { ok(cx); }
        else if rest::on(cx,"PATCH", "/me") { ok(cx); }
        else if rest::on(cx,"GET", "/me/settings") { ok(cx); }
        else if rest::on(cx,"PUT", "/me/settings") { ok(cx); }
        else if rest::on(cx,"GET", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PUT", "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/orgs") {
        if rest::on(cx,"GET", "") { ok(cx); }
        else if rest::on(cx,"POST", "") { ok(cx); }
        else if rest::on(cx,"GET", "/:org") { rest::param(cx, "org"); ok(cx); }
        else if rest::on(cx,"PATCH", "/:org") { rest::param(cx, "org"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:org") { rest::param(cx, "org"); ok(cx); }
        else if rest::on(cx,"GET", "/:org/members") { rest::param(cx, "org"); ok(cx); }
        else if rest::on(cx,"POST", "/:org/members") { rest::param(cx, "org"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:org/members/:user") {
            rest::param(cx, "org");
            rest::param_int(cx, "user");
            ok(cx);
        }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/projects") {
        if rest::on(cx,"GET", "") {
            rest::query_int(cx, "page");
            rest::query_bool(cx, "archived");
            rest::query(cx, "q");
            ok(cx);
        }
        else if rest::on(cx,"POST", "") { ok(cx); }
        else if rest::on(cx,"GET", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PATCH", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/:id/archive") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/:id/restore") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/:id/members") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/:id/members") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:id/members/:user") {
            rest::param_int(cx, "id");
            rest::param_int(cx, "user");
            ok(cx);
        }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/tasks") {
        if rest::on(cx,"GET", "") { ok(cx); }
        else if rest::on(cx,"POST", "") { ok(cx); }
        else if rest::on(cx,"GET", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PATCH", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/:id/assign") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/:id/comments") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/:id/comments") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PATCH", "/:id/comments/:comment") {
            rest::param_int(cx, "id");
            rest::param(cx, "comment");
            ok(cx);
        }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/files") {
        if rest::on(cx,"GET", "") { ok(cx); }
        else if rest::on(cx,"POST", "") { ok(cx); }
        else if rest::on(cx,"GET", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/:id/content") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PUT", "/:id/content") { rest::param_int(cx, "id"); ok(cx); }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/webhooks") {
        if rest::on(cx,"GET", "") { ok(cx); }
        else if rest::on(cx,"POST", "") { ok(cx); }
        else if rest::on(cx,"GET", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"PATCH", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/:id/deliveries") { rest::param_int(cx, "id"); ok(cx); }
        else { rest::otherwise(cx); }
    } else if rest::scope(cx,"/reports") {
        if rest::on(cx,"GET", "/time") { ok(cx); }
        else if rest::on(cx,"GET", "/time/:user") { rest::param_int(cx, "user"); ok(cx); }
        else if rest::on(cx,"GET", "/budget") { ok(cx); }
        else if rest::on(cx,"GET", "/exports") { ok(cx); }
        else if rest::on(cx,"POST", "/exports") { ok(cx); }
        else if rest::on(cx,"GET", "/exports/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"DELETE", "/exports/:id") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"POST", "/exports/:id/cancel") { rest::param_int(cx, "id"); ok(cx); }
        else if rest::on(cx,"GET", "/exports/:id/download") { rest::param_int(cx, "id"); ok(cx); }
        else { rest::otherwise(cx); }
    } else {
        rest::otherwise(cx);
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
    http::exit_on_error(http::stop_on_signals());
    http::run(cfg, worker);
}
