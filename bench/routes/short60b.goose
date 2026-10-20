// hand60.goose's routes in design B of spike 12 (spikes/12-compact-routes),
// in every scope, /v1/reports's behind tenant_checked included:
// marked::routes, which answers 404, 405, and 501 itself, one marked::route
// around /v1, as hand60 has one rest::route there, and a call per method
// that, inside it, only matches. Each path parameter is read as hand60
// reads it.
//
//   short60b http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import marked from "../../spikes/12-compact-routes";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

// Fails 400 for a request that names a tenant other than acme; the
// benchmark's requests name none.
inline fn tenant_checked<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard !has || id == "acme" else { rest::fail(cx, 400, "unknown_tenant"); }
    F();
}

fn handle(cx) {
    marked::routes(cx) { cx =>
        marked::get(cx, "/health") { ok(cx); };
        if rest::scope(cx, "/v1") { marked::route(cx) { cx => v1(cx); }; }
    };
}

fn v1(cx) {
    if marked::scope(cx,"/auth") {
        marked::post(cx, "/login") { ok(cx); };
        marked::post(cx, "/logout") { ok(cx); };
        marked::post(cx, "/refresh") { ok(cx); };
        marked::get(cx, "/session") { ok(cx); };
    } else if marked::scope(cx,"/users") {
        marked::get(cx, "/me") { ok(cx); };
        marked::patch(cx, "/me") { ok(cx); };
        marked::get(cx, "/me/settings") { ok(cx); };
        marked::put(cx, "/me/settings") { ok(cx); };
        marked::get(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::get(cx, "/:id/avatar") { marked::param_int(cx, "id"); ok(cx); };
        marked::put(cx, "/:id/avatar") { marked::param_int(cx, "id"); ok(cx); };
    } else if marked::scope(cx,"/orgs") {
        marked::get(cx, "") { ok(cx); };
        marked::post(cx, "") { ok(cx); };
        marked::get(cx, "/:org") { marked::param(cx, "org"); ok(cx); };
        marked::patch(cx, "/:org") { marked::param(cx, "org"); ok(cx); };
        marked::delete(cx, "/:org") { marked::param(cx, "org"); ok(cx); };
        marked::get(cx, "/:org/members") { marked::param(cx, "org"); ok(cx); };
        marked::post(cx, "/:org/members") { marked::param(cx, "org"); ok(cx); };
        marked::delete(cx, "/:org/members/:user") {
            marked::param(cx, "org");
            marked::param_int(cx, "user");
            ok(cx);
        };
    } else if marked::scope(cx,"/projects") {
        marked::get(cx, "") {
            rest::query_int(cx, "page");
            rest::query_bool(cx, "archived");
            rest::query(cx, "q");
            ok(cx);
        };
        marked::post(cx, "") { ok(cx); };
        marked::get(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::patch(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::delete(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::post(cx, "/:id/archive") { marked::param_int(cx, "id"); ok(cx); };
        marked::post(cx, "/:id/restore") { marked::param_int(cx, "id"); ok(cx); };
        marked::get(cx, "/:id/members") { marked::param_int(cx, "id"); ok(cx); };
        marked::post(cx, "/:id/members") { marked::param_int(cx, "id"); ok(cx); };
        marked::delete(cx, "/:id/members/:user") {
            marked::param_int(cx, "id");
            marked::param_int(cx, "user");
            ok(cx);
        };
    } else if marked::scope(cx,"/tasks") {
        marked::get(cx, "") { ok(cx); };
        marked::post(cx, "") { ok(cx); };
        marked::get(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::patch(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::delete(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::post(cx, "/:id/assign") { marked::param_int(cx, "id"); ok(cx); };
        marked::get(cx, "/:id/comments") { marked::param_int(cx, "id"); ok(cx); };
        marked::post(cx, "/:id/comments") { marked::param_int(cx, "id"); ok(cx); };
        marked::patch(cx, "/:id/comments/:comment") {
            marked::param_int(cx, "id");
            marked::param(cx, "comment");
            ok(cx);
        };
    } else if marked::scope(cx,"/files") {
        marked::get(cx, "") { ok(cx); };
        marked::post(cx, "") { ok(cx); };
        marked::get(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::delete(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::get(cx, "/:id/content") { marked::param_int(cx, "id"); ok(cx); };
        marked::put(cx, "/:id/content") { marked::param_int(cx, "id"); ok(cx); };
    } else if marked::scope(cx,"/webhooks") {
        marked::get(cx, "") { ok(cx); };
        marked::post(cx, "") { ok(cx); };
        marked::get(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::patch(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::delete(cx, "/:id") { marked::param_int(cx, "id"); ok(cx); };
        marked::get(cx, "/:id/deliveries") { marked::param_int(cx, "id"); ok(cx); };
    } else if marked::scope(cx,"/reports") {
        tenant_checked(cx) {
            marked::get(cx, "/time") { ok(cx); };
            marked::get(cx, "/time/:user") { marked::param_int(cx, "user"); ok(cx); };
            marked::get(cx, "/budget") { ok(cx); };
            marked::get(cx, "/exports") { ok(cx); };
            marked::post(cx, "/exports") { ok(cx); };
            marked::get(cx, "/exports/:id") { marked::param_int(cx, "id"); ok(cx); };
            marked::delete(cx, "/exports/:id") { marked::param_int(cx, "id"); ok(cx); };
            marked::post(cx, "/exports/:id/cancel") { marked::param_int(cx, "id"); ok(cx); };
            marked::get(cx, "/exports/:id/download") { marked::param_int(cx, "id"); ok(cx); };
        };
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
        write_stderr("usage: short60b http [port]\n");
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
