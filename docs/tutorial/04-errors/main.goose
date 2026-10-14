// docs/tutorial.md, section 4: a program's own error shape, picked by the
// type of its per-request state.
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
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
    var r = http::router(cx.req);
    if http::on(r, "GET", "/projects/:id") {
        rest::route(cx) {
            let id = rest::param_int(cx, r, "id");
            guard id == 1 else { rest::fail(cx, 404, "project_not_found"); }
            rest::text(cx, 200, "goose");
        };
    } else {
        rest::otherwise(cx, r);
    }
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg, St { .. }) { cx => handle(cx) };
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
