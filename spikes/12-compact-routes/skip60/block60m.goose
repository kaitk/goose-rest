// hand60m's stack around block60's routes.
// Built from a copy two levels below the package's root, which
// ../benchskip.sh makes.
//
//   block60m http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
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
                plod::get(cx, "/health") { ok(cx); };
                plod::scope(cx, "/v1") { plod::bearer(cx) { token => v1(cx); }; };
            };
        };
    };
}

fn v1(cx) {
    plod::scope(cx,"/auth") {
        plod::post(cx, "/login") { ok(cx); };
        plod::post(cx, "/logout") { ok(cx); };
        plod::post(cx, "/refresh") { ok(cx); };
        plod::get(cx, "/session") { ok(cx); };
    };
    plod::scope(cx,"/users") {
        plod::get(cx, "/me") { ok(cx); };
        plod::patch(cx, "/me") { ok(cx); };
        plod::get(cx, "/me/settings") { ok(cx); };
        plod::put(cx, "/me/settings") { ok(cx); };
        plod::get(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::get(cx, "/:id/avatar") { plod::param_int(cx, "id"); ok(cx); };
        plod::put(cx, "/:id/avatar") { plod::param_int(cx, "id"); ok(cx); };
    };
    plod::scope(cx,"/orgs") {
        plod::get(cx, "") { ok(cx); };
        plod::post(cx, "") { ok(cx); };
        plod::get(cx, "/:org") { plod::param(cx, "org"); ok(cx); };
        plod::patch(cx, "/:org") { plod::param(cx, "org"); ok(cx); };
        plod::delete(cx, "/:org") { plod::param(cx, "org"); ok(cx); };
        plod::get(cx, "/:org/members") { plod::param(cx, "org"); ok(cx); };
        plod::post(cx, "/:org/members") { plod::param(cx, "org"); ok(cx); };
        plod::delete(cx, "/:org/members/:user") {
            plod::param(cx, "org");
            plod::param_int(cx, "user");
            ok(cx);
        };
    };
    plod::scope(cx,"/projects") {
        plod::get(cx, "") {
            plod::query_int(cx, "page");
            plod::query_bool(cx, "archived");
            plod::query(cx, "q");
            ok(cx);
        };
        plod::post(cx, "") { ok(cx); };
        plod::get(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::patch(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::delete(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::post(cx, "/:id/archive") { plod::param_int(cx, "id"); ok(cx); };
        plod::post(cx, "/:id/restore") { plod::param_int(cx, "id"); ok(cx); };
        plod::get(cx, "/:id/members") { plod::param_int(cx, "id"); ok(cx); };
        plod::post(cx, "/:id/members") { plod::param_int(cx, "id"); ok(cx); };
        plod::delete(cx, "/:id/members/:user") {
            plod::param_int(cx, "id");
            plod::param_int(cx, "user");
            ok(cx);
        };
    };
    plod::scope(cx,"/tasks") {
        plod::get(cx, "") { ok(cx); };
        plod::post(cx, "") { ok(cx); };
        plod::get(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::patch(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::delete(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::post(cx, "/:id/assign") { plod::param_int(cx, "id"); ok(cx); };
        plod::get(cx, "/:id/comments") { plod::param_int(cx, "id"); ok(cx); };
        plod::post(cx, "/:id/comments") { plod::param_int(cx, "id"); ok(cx); };
        plod::patch(cx, "/:id/comments/:comment") {
            plod::param_int(cx, "id");
            plod::param(cx, "comment");
            ok(cx);
        };
    };
    plod::scope(cx,"/files") {
        plod::get(cx, "") { ok(cx); };
        plod::post(cx, "") { ok(cx); };
        plod::get(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::delete(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::get(cx, "/:id/content") { plod::param_int(cx, "id"); ok(cx); };
        plod::put(cx, "/:id/content") { plod::param_int(cx, "id"); ok(cx); };
    };
    plod::scope(cx,"/webhooks") {
        plod::get(cx, "") { ok(cx); };
        plod::post(cx, "") { ok(cx); };
        plod::get(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::patch(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::delete(cx, "/:id") { plod::param_int(cx, "id"); ok(cx); };
        plod::get(cx, "/:id/deliveries") { plod::param_int(cx, "id"); ok(cx); };
    };
    plod::scope(cx,"/reports") {
        tenant_checked(cx) {
            plod::get(cx, "/time") { ok(cx); };
            plod::get(cx, "/time/:user") { plod::param_int(cx, "user"); ok(cx); };
            plod::get(cx, "/budget") { ok(cx); };
            plod::get(cx, "/exports") { ok(cx); };
            plod::post(cx, "/exports") { ok(cx); };
            plod::get(cx, "/exports/:id") { plod::param_int(cx, "id"); ok(cx); };
            plod::delete(cx, "/exports/:id") { plod::param_int(cx, "id"); ok(cx); };
            plod::post(cx, "/exports/:id/cancel") { plod::param_int(cx, "id"); ok(cx); };
            plod::get(cx, "/exports/:id/download") { plod::param_int(cx, "id"); ok(cx); };
        };
    };
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
        write_stderr("usage: block60m http [port]\n");
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
