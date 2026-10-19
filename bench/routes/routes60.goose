// bench/routes.sh's if chain: 60 routes shaped like a real API, an if chain over
// http::router grouped under prefix scopes, each route answering "ok". Its
// first route is GET /health and its last GET /v1/reports/exports/:id/download.
//
//   routes60 http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.4.0";

// Whether path is prefix or below it. The prefix is compared byte for byte,
// so a path that escapes an unreserved byte in it, which http::on would
// match, misses the scope and is answered 404.
fn under(path: const u8[:], prefix: const u8[:]) -> bool {
    guard path.len >= prefix.len && path[..prefix.len] == prefix else { return false; }
    return path.len == prefix.len || path[prefix.len] == '/';
}

fn ok(out: http::Reply) { http::respond(out, 200, "text/plain", "ok"); }

fn handle(req: const http::Request&, out: http::Reply) {
    var r = http::router(req);
    if http::on(r, "GET", "/health") {
        ok(out);
    } else if under(r.path, "/v1/auth") {
        if http::on(r, "POST", "/v1/auth/login") { ok(out); }
        else if http::on(r, "POST", "/v1/auth/logout") { ok(out); }
        else if http::on(r, "POST", "/v1/auth/refresh") { ok(out); }
        else if http::on(r, "GET", "/v1/auth/session") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/users") {
        if http::on(r, "GET", "/v1/users/me") { ok(out); }
        else if http::on(r, "PATCH", "/v1/users/me") { ok(out); }
        else if http::on(r, "GET", "/v1/users/me/settings") { ok(out); }
        else if http::on(r, "PUT", "/v1/users/me/settings") { ok(out); }
        else if http::on(r, "GET", "/v1/users/:id") { ok(out); }
        else if http::on(r, "GET", "/v1/users/:id/avatar") { ok(out); }
        else if http::on(r, "PUT", "/v1/users/:id/avatar") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/orgs") {
        if http::on(r, "GET", "/v1/orgs") { ok(out); }
        else if http::on(r, "POST", "/v1/orgs") { ok(out); }
        else if http::on(r, "GET", "/v1/orgs/:org") { ok(out); }
        else if http::on(r, "PATCH", "/v1/orgs/:org") { ok(out); }
        else if http::on(r, "DELETE", "/v1/orgs/:org") { ok(out); }
        else if http::on(r, "GET", "/v1/orgs/:org/members") { ok(out); }
        else if http::on(r, "POST", "/v1/orgs/:org/members") { ok(out); }
        else if http::on(r, "DELETE", "/v1/orgs/:org/members/:user") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/projects") {
        if http::on(r, "GET", "/v1/projects") { ok(out); }
        else if http::on(r, "POST", "/v1/projects") { ok(out); }
        else if http::on(r, "GET", "/v1/projects/:id") { ok(out); }
        else if http::on(r, "PATCH", "/v1/projects/:id") { ok(out); }
        else if http::on(r, "DELETE", "/v1/projects/:id") { ok(out); }
        else if http::on(r, "POST", "/v1/projects/:id/archive") { ok(out); }
        else if http::on(r, "POST", "/v1/projects/:id/restore") { ok(out); }
        else if http::on(r, "GET", "/v1/projects/:id/members") { ok(out); }
        else if http::on(r, "POST", "/v1/projects/:id/members") { ok(out); }
        else if http::on(r, "DELETE", "/v1/projects/:id/members/:user") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/tasks") {
        if http::on(r, "GET", "/v1/tasks") { ok(out); }
        else if http::on(r, "POST", "/v1/tasks") { ok(out); }
        else if http::on(r, "GET", "/v1/tasks/:id") { ok(out); }
        else if http::on(r, "PATCH", "/v1/tasks/:id") { ok(out); }
        else if http::on(r, "DELETE", "/v1/tasks/:id") { ok(out); }
        else if http::on(r, "POST", "/v1/tasks/:id/assign") { ok(out); }
        else if http::on(r, "GET", "/v1/tasks/:id/comments") { ok(out); }
        else if http::on(r, "POST", "/v1/tasks/:id/comments") { ok(out); }
        else if http::on(r, "PATCH", "/v1/tasks/:id/comments/:comment") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/files") {
        if http::on(r, "GET", "/v1/files") { ok(out); }
        else if http::on(r, "POST", "/v1/files") { ok(out); }
        else if http::on(r, "GET", "/v1/files/:id") { ok(out); }
        else if http::on(r, "DELETE", "/v1/files/:id") { ok(out); }
        else if http::on(r, "GET", "/v1/files/:id/content") { ok(out); }
        else if http::on(r, "PUT", "/v1/files/:id/content") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/webhooks") {
        if http::on(r, "GET", "/v1/webhooks") { ok(out); }
        else if http::on(r, "POST", "/v1/webhooks") { ok(out); }
        else if http::on(r, "GET", "/v1/webhooks/:id") { ok(out); }
        else if http::on(r, "PATCH", "/v1/webhooks/:id") { ok(out); }
        else if http::on(r, "DELETE", "/v1/webhooks/:id") { ok(out); }
        else if http::on(r, "GET", "/v1/webhooks/:id/deliveries") { ok(out); }
        else { http::otherwise(r, out); }
    } else if under(r.path, "/v1/reports") {
        if http::on(r, "GET", "/v1/reports/time") { ok(out); }
        else if http::on(r, "GET", "/v1/reports/time/:user") { ok(out); }
        else if http::on(r, "GET", "/v1/reports/budget") { ok(out); }
        else if http::on(r, "GET", "/v1/reports/exports") { ok(out); }
        else if http::on(r, "POST", "/v1/reports/exports") { ok(out); }
        else if http::on(r, "GET", "/v1/reports/exports/:id") { ok(out); }
        else if http::on(r, "DELETE", "/v1/reports/exports/:id") { ok(out); }
        else if http::on(r, "POST", "/v1/reports/exports/:id/cancel") { ok(out); }
        else if http::on(r, "GET", "/v1/reports/exports/:id/download") { ok(out); }
        else { http::otherwise(r, out); }
    } else {
        http::otherwise(r, out);
    }
}

thread_fn worker(cfg: http::Config) {
    let e = http::serve_epoll(cfg) { req, body, out => handle(req, out) };
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    guard argv.len >= 2 && argv[1] == "http" else {
        write_stderr("usage: routes60 http [port]\n");
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
