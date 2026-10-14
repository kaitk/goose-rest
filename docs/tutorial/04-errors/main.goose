// docs/tutorial.md, section 4: a program's own error shape, picked by the
// type of its per-request state.
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "../../../";

// The per-request state. This program keeps nothing in it: its type picks
// the error shape.
struct St { unused: bool = false }

fn rest::error_body(body: u8[>..]&, st: const St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":{\"code\":");
    json::format_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    if detail.len > 0 {
        body.append(",\"message\":");
        json::format_string(body, detail);
    }
    body.append("}}");
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/projects/:id") {
            rest::route(cx) {
                let id = rest::param_int(cx, "id");
                guard id == 1 else { rest::fail(cx, 404, "project_not_found"); }
                rest::text(cx, 200, "goose");
            };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config) {
    var none = rest::NoState { .. };
    let e = rest::serve(cfg, none, St { .. }) { cx => handle(cx) };
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
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
