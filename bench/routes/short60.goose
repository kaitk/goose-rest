// hand60.goose's routes in the shorter form of spike 12
// (spikes/12-compact-routes): compact::routes, which answers 404, 405, and
// 501 itself, and a call per method that matches a route and opens it, so
// no rest::otherwise. Each path parameter is read as hand60 reads it.
//
//   short60 http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import compact from "../../spikes/12-compact-routes";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

fn handle(cx) {
    compact::routes(cx) { cx =>
        compact::get(cx, "/health") { ok(cx); };
        if rest::scope(cx, "/v1") { v1(cx); }
    };
}

fn v1(cx) {
    if rest::scope(cx,"/auth") {
        compact::post(cx, "/login") { ok(cx); };
        compact::post(cx, "/logout") { ok(cx); };
        compact::post(cx, "/refresh") { ok(cx); };
        compact::get(cx, "/session") { ok(cx); };
    } else if rest::scope(cx,"/users") {
        compact::get(cx, "/me") { ok(cx); };
        compact::patch(cx, "/me") { ok(cx); };
        compact::get(cx, "/me/settings") { ok(cx); };
        compact::put(cx, "/me/settings") { ok(cx); };
        compact::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); };
        compact::put(cx, "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); };
    } else if rest::scope(cx,"/orgs") {
        compact::get(cx, "") { ok(cx); };
        compact::post(cx, "") { ok(cx); };
        compact::get(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        compact::patch(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        compact::delete(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        compact::get(cx, "/:org/members") { rest::param(cx, "org"); ok(cx); };
        compact::post(cx, "/:org/members") { rest::param(cx, "org"); ok(cx); };
        compact::delete(cx, "/:org/members/:user") {
            rest::param(cx, "org");
            rest::param_int(cx, "user");
            ok(cx);
        };
    } else if rest::scope(cx,"/projects") {
        compact::get(cx, "") {
            rest::query_int(cx, "page");
            rest::query_bool(cx, "archived");
            rest::query(cx, "q");
            ok(cx);
        };
        compact::post(cx, "") { ok(cx); };
        compact::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/:id/archive") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/:id/restore") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/:id/members") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/:id/members") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/:id/members/:user") {
            rest::param_int(cx, "id");
            rest::param_int(cx, "user");
            ok(cx);
        };
    } else if rest::scope(cx,"/tasks") {
        compact::get(cx, "") { ok(cx); };
        compact::post(cx, "") { ok(cx); };
        compact::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/:id/assign") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/:id/comments") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/:id/comments") { rest::param_int(cx, "id"); ok(cx); };
        compact::patch(cx, "/:id/comments/:comment") {
            rest::param_int(cx, "id");
            rest::param(cx, "comment");
            ok(cx);
        };
    } else if rest::scope(cx,"/files") {
        compact::get(cx, "") { ok(cx); };
        compact::post(cx, "") { ok(cx); };
        compact::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/:id/content") { rest::param_int(cx, "id"); ok(cx); };
        compact::put(cx, "/:id/content") { rest::param_int(cx, "id"); ok(cx); };
    } else if rest::scope(cx,"/webhooks") {
        compact::get(cx, "") { ok(cx); };
        compact::post(cx, "") { ok(cx); };
        compact::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/:id/deliveries") { rest::param_int(cx, "id"); ok(cx); };
    } else if rest::scope(cx,"/reports") {
        compact::get(cx, "/time") { ok(cx); };
        compact::get(cx, "/time/:user") { rest::param_int(cx, "user"); ok(cx); };
        compact::get(cx, "/budget") { ok(cx); };
        compact::get(cx, "/exports") { ok(cx); };
        compact::post(cx, "/exports") { ok(cx); };
        compact::get(cx, "/exports/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::delete(cx, "/exports/:id") { rest::param_int(cx, "id"); ok(cx); };
        compact::post(cx, "/exports/:id/cancel") { rest::param_int(cx, "id"); ok(cx); };
        compact::get(cx, "/exports/:id/download") { rest::param_int(cx, "id"); ok(cx); };
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
        write_stderr("usage: short60 http [port]\n");
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
