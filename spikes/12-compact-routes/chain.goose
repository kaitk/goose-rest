// The C of both forms, compiled with -O2 and not run: long and short each
// serve the same four routes, a guard among them.
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import .compact;

fn admin(cx) -> bool {
    let v, has = rest::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::text(cx, 200, str("project ", id));
}

fn long(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::route(cx) { rest::text(cx, 200, "ok"); };
        } else if rest::on(cx, "GET", "/projects/:id") {
            rest::route(cx) { project(cx, rest::param_int(cx, "id")); };
        } else if rest::on(cx, "DELETE", "/projects/:id") {
            rest::route(cx) { rest::empty(cx, 204); };
        } else if admin(cx) && rest::on(cx, "GET", "/admin") {
            rest::route(cx) { rest::text(cx, 200, "admin"); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn short(cx) {
    compact::routes(cx) { cx =>
        compact::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        compact::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        compact::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        if admin(cx) { compact::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
    };
}

thread_fn worker_long(cfg: http::Config) { rest::serve(cfg) { cx => long(cx) }; }
thread_fn worker_short(cfg: http::Config) { rest::serve(cfg) { cx => short(cx) }; }

fn main() {
    let cfg = http::Config { .. };
    if args().len > 1 { http::run(cfg, worker_short); } else { http::run(cfg, worker_long); }
}
