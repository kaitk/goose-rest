// bench/routes.sh's baseline:routes60.goose's server with only its last route,
// GET /v1/reports/exports/:id/download, answering "ok", so that its last
// route and a 404 in its last scope are compared on the same request and
// response bytes.
//
//   routes1_last http [port]   (WORKERS 1)
import std;
import http from "github.com/kaitk/goose-http@v0.3.1";

fn handle(req: const http::Request&, out: http::Reply) {
    var r = http::router(req);
    if http::on(r, "GET", "/v1/reports/exports/:id/download") {
        http::respond(out, 200, "text/plain", "ok");
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
        write_stderr("usage: routes1_last http [port]\n");
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
