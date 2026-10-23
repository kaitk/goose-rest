// The C of the three forms, compiled with -O2 and not run: long (today's),
// short (design A), and short_b (design B) each serve the same four routes,
// a guard among them, and a scope behind plod::bearer.
import std;
import os;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import .compact;
import .marked;

fn admin(cx) -> bool {
    let v, has = plod::header(cx, "X-Admin");
    return has && v == "yes";
}

fn project(cx, id: i64) {
    guard id != 0 else { plod::fail(cx, 404, "project_not_found"); }
    plod::text(cx, 200, str("project ", id));
}

fn long(cx) {
    plod::routes(cx) { cx =>
        if plod::on(cx, "GET", "/health") {
            plod::route(cx) { plod::text(cx, 200, "ok"); };
        } else if plod::on(cx, "GET", "/projects/:id") {
            plod::route(cx) { project(cx, plod::param_int(cx, "id")); };
        } else if plod::on(cx, "DELETE", "/projects/:id") {
            plod::route(cx) { plod::empty(cx, 204); };
        } else if admin(cx) && plod::on(cx, "GET", "/admin") {
            plod::route(cx) { plod::text(cx, 200, "admin"); };
        } else if compact::scope(cx, "/reports") {
            plod::route(cx) {
                plod::bearer(cx) { token =>
                    guard token == "secret" else { plod::invalid_token(cx); }
                    if plod::on(cx, "GET", "/daily") { plod::text(cx, 200, "daily"); }
                    else { plod::otherwise(cx); }
                };
            };
        } else {
            plod::otherwise(cx);
        }
    };
}

fn short(cx) {
    compact::routes(cx) { cx =>
        compact::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        compact::get(cx, "/projects/:id") { project(cx, plod::param_int(cx, "id")); };
        compact::delete(cx, "/projects/:id") { plod::empty(cx, 204); };
        if admin(cx) { compact::get(cx, "/admin") { plod::text(cx, 200, "admin"); }; }
        if compact::scope(cx, "/reports") {
            plod::bearer(cx) { token =>
                guard token == "secret" else { plod::invalid_token(cx); }
                compact::get(cx, "/daily") { plod::text(cx, 200, "daily"); };
            };
        }
    };
}

fn short_b(cx) {
    marked::routes(cx) { cx =>
        marked::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        marked::get(cx, "/projects/:id") { project(cx, plod::param_int(cx, "id")); };
        marked::delete(cx, "/projects/:id") { plod::empty(cx, 204); };
        if admin(cx) { marked::get(cx, "/admin") { plod::text(cx, 200, "admin"); }; }
        if compact::scope(cx, "/reports") {
            marked::route(cx) { cx =>
                plod::bearer(cx) { token =>
                    guard token == "secret" else { plod::invalid_token(cx); }
                    marked::get(cx, "/daily") { plod::text(cx, 200, "daily"); };
                };
            };
        }
    };
}

thread_fn worker_long(cfg: http::Config) { plod::serve(cfg) { cx => long(cx) }; }
thread_fn worker_short(cfg: http::Config) { plod::serve(cfg) { cx => short(cx) }; }
thread_fn worker_short_b(cfg: http::Config) { plod::serve(cfg) { cx => short_b(cx) }; }

fn main() {
    let cfg = http::Config { .. };
    let n = args().len;
    if n > 2 { http::run(cfg, worker_short_b); }
    else if n > 1 { http::run(cfg, worker_short); }
    else { http::run(cfg, worker_long); }
}
