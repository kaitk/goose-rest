// The C of the three forms, compiled with -O2 and not run: long (today's),
// short (design A), and short_b (design B) each serve the same four routes,
// a guard among them, and a scope behind rest::bearer.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import .compact;
import .marked;

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
        } else if rest::scope(cx, "/reports") {
            rest::route(cx) {
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    if rest::on(cx, "GET", "/daily") { rest::text(cx, 200, "daily"); }
                    else { rest::otherwise(cx); }
                };
            };
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
        if rest::scope(cx, "/reports") {
            rest::bearer(cx) { token =>
                guard token == "secret" else { rest::invalid_token(cx); }
                compact::get(cx, "/daily") { rest::text(cx, 200, "daily"); };
            };
        }
    };
}

fn short_b(cx) {
    marked::routes(cx) { cx =>
        marked::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        marked::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
        marked::delete(cx, "/projects/:id") { rest::empty(cx, 204); };
        if admin(cx) { marked::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        if rest::scope(cx, "/reports") {
            marked::route(cx) { cx =>
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    marked::get(cx, "/daily") { rest::text(cx, 200, "daily"); };
                };
            };
        }
    };
}

thread_fn worker_long(cfg: http::Config) { rest::serve(cfg) { cx => long(cx) }; }
thread_fn worker_short(cfg: http::Config) { rest::serve(cfg) { cx => short(cx) }; }
thread_fn worker_short_b(cfg: http::Config) { rest::serve(cfg) { cx => short_b(cx) }; }

fn main() {
    let cfg = http::Config { .. };
    let n = args().len;
    if n > 2 { http::run(cfg, worker_short_b); }
    else if n > 1 { http::run(cfg, worker_short); }
    else { http::run(cfg, worker_long); }
}
