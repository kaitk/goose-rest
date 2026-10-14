// Task 008's server: routes60.goose's 60 routes through the router goose-rest
// gen writes from test/gen/routes.json, each answering "ok" as routes60's do,
// on the same loop, http::serve_epoll. It also does what routes60 doesn't:
// it calls the session check and parses each integer parameter. bench/routes.sh
// builds it from build/routes/gen/, beside the generated routes_gen.goose.
//
//   gen60 http [port]   (WORKERS 1)
import std;
import json;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../../../";
import .routes_gen;
import .app;

thread_fn worker(cfg: http::Config) {
    let e = http::serve_epoll(cfg) { req, body, out =>
        var state = rest::NoState { .. };
        var scratch: u8[>..] = [];
        var cx = rest::Cx<rest::NoState> { req: req, body: body, out: out, state: state, scratch: scratch };
        api::dispatch(cx, state);
    };
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
