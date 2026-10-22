// gen60 behind a hand-written route, as a program serves a route its schema
// can't describe: rest::routes, PUT /uploads/:name, then the generated
// dispatch, which answers every request these benchmarks send. The difference
// from gen60 is the cost of a router and one hand-written route before
// dispatch. bench/routes.sh builds it beside gen60.
//
//   genr60 http [port]   (WORKERS 1)
import std;
import json;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../../";
import .routes_gen;
import .app;

// The worker's state, cx.app; the handlers read none of it.
struct App { unused: bool = false }

thread_fn worker(cfg: http::Config) {
    var app = App { .. };
    let e = rest::serve_epoll(cfg, app) { cx =>
        rest::routes(cx) { cx =>
            rest::put(cx, "/uploads/:name") { app::ok(cx); };
            api::dispatch(cx);
        };
    };
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    guard argv.len >= 2 && argv[1] == "http" else {
        write_stderr("usage: genr60 http [port]\n");
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
