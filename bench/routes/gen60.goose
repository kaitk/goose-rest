// The generated router's server: routes60.goose's 60 routes through the router goose-rest
// gen writes from test/gen/routes.json, each answering "ok" as routes60's do,
// on the same loop, through rest::serve_epoll as a program serves it. It also
// does what routes60 doesn't: it calls the session check and parses each
// integer parameter. bench/routes.sh builds it from build/routes/gen/, beside
// the generated routes_gen.goose.
//
//   gen60 http [port]   (WORKERS 1)
import std;
import json;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../../";
import .routes_gen;
import .app;

// The worker's state, cx.app; the handlers read none of it.
struct App { unused: bool = false }

thread_fn worker(cfg: http::Config) {
    var app = App { .. };
    let e = rest::serve_epoll(cfg, app) { cx => api::dispatch(cx) };
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    guard argv.len >= 2 && argv[1] == "http" else {
        write_stderr("usage: gen60 http [port]\n");
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
