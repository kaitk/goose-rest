// docs/tutorial/03-errors.md: a program's own error shape, picked by the
// type of its request state.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../../";

// The request state. This program keeps nothing in it: its type picks
// the error shape.
struct St { unused: bool = false }

fn plod::error_body(body: u8[>..]&, st: const St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":{\"code\":");
    http::json_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    if detail.len > 0 {
        body.append(",\"message\":");
        http::json_string(body, detail);
    }
    body.append("}}");
}

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/projects/:id") {
            let id = plod::param_int(cx, "id");
            guard id == 1 else { plod::fail(cx, 404, "project_not_found"); }
            plod::text(cx, 200, "goose");
        };
    };
}

thread_fn worker(cfg: http::Config) {
    var none = plod::NoState { .. };
    let e = plod::serve(cfg, none, St { .. }) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, .. };
    http::run(cfg, worker);
}
