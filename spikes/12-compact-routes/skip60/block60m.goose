// hand60m's stack around block60's routes.
// Built from a copy two levels below the package's root, which
// ../benchskip.sh makes.
//
//   block60m http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

let CORS = rest::Cors { origins: "https://a.example", .. };

// Fails 400 for a request that names a tenant other than acme; the
// benchmark's requests name none.
inline fn tenant_checked<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard !has || id == "acme" else { rest::fail(cx, 400, "unknown_tenant"); }
    F();
}

fn handle(cx) {
    rest::timed(cx, false) {
        rest::cors(cx, CORS) {
            rest::routes(cx) { cx =>
                rest::get(cx, "/health") { ok(cx); };
                rest::scope(cx, "/v1") { rest::bearer(cx) { token => v1(cx); }; };
            };
        };
    };
}

fn v1(cx) {
    rest::scope(cx,"/auth") {
        rest::post(cx, "/login") { ok(cx); };
        rest::post(cx, "/logout") { ok(cx); };
        rest::post(cx, "/refresh") { ok(cx); };
        rest::get(cx, "/session") { ok(cx); };
    };
    rest::scope(cx,"/users") {
        rest::get(cx, "/me") { ok(cx); };
        rest::patch(cx, "/me") { ok(cx); };
        rest::get(cx, "/me/settings") { ok(cx); };
        rest::put(cx, "/me/settings") { ok(cx); };
        rest::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::get(cx, "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); };
        rest::put(cx, "/:id/avatar") { rest::param_int(cx, "id"); ok(cx); };
    };
    rest::scope(cx,"/orgs") {
        rest::get(cx, "") { ok(cx); };
        rest::post(cx, "") { ok(cx); };
        rest::get(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        rest::patch(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        rest::delete(cx, "/:org") { rest::param(cx, "org"); ok(cx); };
        rest::get(cx, "/:org/members") { rest::param(cx, "org"); ok(cx); };
        rest::post(cx, "/:org/members") { rest::param(cx, "org"); ok(cx); };
        rest::delete(cx, "/:org/members/:user") {
            rest::param(cx, "org");
            rest::param_int(cx, "user");
            ok(cx);
        };
    };
    rest::scope(cx,"/projects") {
        rest::get(cx, "") {
            rest::query_int(cx, "page");
            rest::query_bool(cx, "archived");
            rest::query(cx, "q");
            ok(cx);
        };
        rest::post(cx, "") { ok(cx); };
        rest::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::post(cx, "/:id/archive") { rest::param_int(cx, "id"); ok(cx); };
        rest::post(cx, "/:id/restore") { rest::param_int(cx, "id"); ok(cx); };
        rest::get(cx, "/:id/members") { rest::param_int(cx, "id"); ok(cx); };
        rest::post(cx, "/:id/members") { rest::param_int(cx, "id"); ok(cx); };
        rest::delete(cx, "/:id/members/:user") {
            rest::param_int(cx, "id");
            rest::param_int(cx, "user");
            ok(cx);
        };
    };
    rest::scope(cx,"/tasks") {
        rest::get(cx, "") { ok(cx); };
        rest::post(cx, "") { ok(cx); };
        rest::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::post(cx, "/:id/assign") { rest::param_int(cx, "id"); ok(cx); };
        rest::get(cx, "/:id/comments") { rest::param_int(cx, "id"); ok(cx); };
        rest::post(cx, "/:id/comments") { rest::param_int(cx, "id"); ok(cx); };
        rest::patch(cx, "/:id/comments/:comment") {
            rest::param_int(cx, "id");
            rest::param(cx, "comment");
            ok(cx);
        };
    };
    rest::scope(cx,"/files") {
        rest::get(cx, "") { ok(cx); };
        rest::post(cx, "") { ok(cx); };
        rest::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::get(cx, "/:id/content") { rest::param_int(cx, "id"); ok(cx); };
        rest::put(cx, "/:id/content") { rest::param_int(cx, "id"); ok(cx); };
    };
    rest::scope(cx,"/webhooks") {
        rest::get(cx, "") { ok(cx); };
        rest::post(cx, "") { ok(cx); };
        rest::get(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::patch(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::delete(cx, "/:id") { rest::param_int(cx, "id"); ok(cx); };
        rest::get(cx, "/:id/deliveries") { rest::param_int(cx, "id"); ok(cx); };
    };
    rest::scope(cx,"/reports") {
        tenant_checked(cx) {
            rest::get(cx, "/time") { ok(cx); };
            rest::get(cx, "/time/:user") { rest::param_int(cx, "user"); ok(cx); };
            rest::get(cx, "/budget") { ok(cx); };
            rest::get(cx, "/exports") { ok(cx); };
            rest::post(cx, "/exports") { ok(cx); };
            rest::get(cx, "/exports/:id") { rest::param_int(cx, "id"); ok(cx); };
            rest::delete(cx, "/exports/:id") { rest::param_int(cx, "id"); ok(cx); };
            rest::post(cx, "/exports/:id/cancel") { rest::param_int(cx, "id"); ok(cx); };
            rest::get(cx, "/exports/:id/download") { rest::param_int(cx, "id"); ok(cx); };
        };
    };
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
