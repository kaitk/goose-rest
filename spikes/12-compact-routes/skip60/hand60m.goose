// hand60 behind a stack as tier M's: plod::timed and plod::cors outside
// plod::routes, and plod::bearer around /v1, in today's form.
// Built from a copy two levels below the package's root, which
// ../benchskip.sh makes.
//
//   hand60m http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

let CORS = plod::Cors { origins: "https://a.example", .. };

// Fails 400 for a request that names a tenant other than acme; the
// benchmark's requests name none.
inline fn tenant_checked<F>(cx) {
    let id, has = plod::header(cx, "X-Tenant");
    guard !has || id == "acme" else { plod::fail(cx, 400, "unknown_tenant"); }
    F();
}

fn handle(cx) {
    plod::timed(cx, false) {
        plod::cors(cx, CORS) {
            plod::routes(cx) { cx =>
                if plod::on(cx, "GET", "/health") {
                    ok(cx);
                } else if plod::scope(cx, "/v1") {
                    plod::route(cx) { plod::bearer(cx) { token => v1(cx); }; };
                } else {
                    plod::otherwise(cx);
                }
            };
        };
    };
}

fn v1(cx) {
    if plod::scope(cx,"/auth") {
        if plod::on(cx,"POST", "/login") { ok(cx); }
        else if plod::on(cx,"POST", "/logout") { ok(cx); }
        else if plod::on(cx,"POST", "/refresh") { ok(cx); }
        else if plod::on(cx,"GET", "/session") { ok(cx); }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/users") {
        if plod::on(cx,"GET", "/me") { ok(cx); }
        else if plod::on(cx,"PATCH", "/me") { ok(cx); }
        else if plod::on(cx,"GET", "/me/settings") { ok(cx); }
        else if plod::on(cx,"PUT", "/me/settings") { ok(cx); }
        else if plod::on(cx,"GET", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"GET", "/:id/avatar") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PUT", "/:id/avatar") { plod::param_int(cx, "id"); ok(cx); }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/orgs") {
        if plod::on(cx,"GET", "") { ok(cx); }
        else if plod::on(cx,"POST", "") { ok(cx); }
        else if plod::on(cx,"GET", "/:org") { plod::param(cx, "org"); ok(cx); }
        else if plod::on(cx,"PATCH", "/:org") { plod::param(cx, "org"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:org") { plod::param(cx, "org"); ok(cx); }
        else if plod::on(cx,"GET", "/:org/members") { plod::param(cx, "org"); ok(cx); }
        else if plod::on(cx,"POST", "/:org/members") { plod::param(cx, "org"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:org/members/:user") {
            plod::param(cx, "org");
            plod::param_int(cx, "user");
            ok(cx);
        }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/projects") {
        if plod::on(cx,"GET", "") {
            plod::query_int(cx, "page");
            plod::query_bool(cx, "archived");
            plod::query(cx, "q");
            ok(cx);
        }
        else if plod::on(cx,"POST", "") { ok(cx); }
        else if plod::on(cx,"GET", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PATCH", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"POST", "/:id/archive") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"POST", "/:id/restore") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"GET", "/:id/members") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"POST", "/:id/members") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:id/members/:user") {
            plod::param_int(cx, "id");
            plod::param_int(cx, "user");
            ok(cx);
        }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/tasks") {
        if plod::on(cx,"GET", "") { ok(cx); }
        else if plod::on(cx,"POST", "") { ok(cx); }
        else if plod::on(cx,"GET", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PATCH", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"POST", "/:id/assign") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"GET", "/:id/comments") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"POST", "/:id/comments") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PATCH", "/:id/comments/:comment") {
            plod::param_int(cx, "id");
            plod::param(cx, "comment");
            ok(cx);
        }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/files") {
        if plod::on(cx,"GET", "") { ok(cx); }
        else if plod::on(cx,"POST", "") { ok(cx); }
        else if plod::on(cx,"GET", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"GET", "/:id/content") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PUT", "/:id/content") { plod::param_int(cx, "id"); ok(cx); }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/webhooks") {
        if plod::on(cx,"GET", "") { ok(cx); }
        else if plod::on(cx,"POST", "") { ok(cx); }
        else if plod::on(cx,"GET", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"PATCH", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"DELETE", "/:id") { plod::param_int(cx, "id"); ok(cx); }
        else if plod::on(cx,"GET", "/:id/deliveries") { plod::param_int(cx, "id"); ok(cx); }
        else { plod::otherwise(cx); }
    } else if plod::scope(cx,"/reports") {
        tenant_checked(cx) {
            if plod::on(cx,"GET", "/time") { ok(cx); }
            else if plod::on(cx,"GET", "/time/:user") { plod::param_int(cx, "user"); ok(cx); }
            else if plod::on(cx,"GET", "/budget") { ok(cx); }
            else if plod::on(cx,"GET", "/exports") { ok(cx); }
            else if plod::on(cx,"POST", "/exports") { ok(cx); }
            else if plod::on(cx,"GET", "/exports/:id") { plod::param_int(cx, "id"); ok(cx); }
            else if plod::on(cx,"DELETE", "/exports/:id") { plod::param_int(cx, "id"); ok(cx); }
            else if plod::on(cx,"POST", "/exports/:id/cancel") { plod::param_int(cx, "id"); ok(cx); }
            else if plod::on(cx,"GET", "/exports/:id/download") { plod::param_int(cx, "id"); ok(cx); }
            else { plod::otherwise(cx); }
        };
    } else {
        plod::otherwise(cx);
    }
}

thread_fn worker(cfg: http::Config) {
    let e = plod::serve_epoll(cfg) { cx => handle(cx) };
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    guard argv.len >= 2 && argv[1] == "http" else {
        write_stderr("usage: hand60m http [port]\n");
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
