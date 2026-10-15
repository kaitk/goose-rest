// docs/best-practices/state.md: data known at build time in a global, and
// what one worker counts in its own state. One worker, so that the count
// below is the server's.
//
//   goose build -o build/state docs/best-practices/state/main.goose
//   build/state 8080
//   curl -s localhost:8080/holidays
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../../";

struct Holiday { date: const u8[:], name: const u8[:] }

fn format(out: u8[>..]&, h: const Holiday&) {
    out.append("{\"date\":");
    json::format_string(out, h.date);
    out.append(",\"name\":");
    json::format_string(out, h.name);
    out.push('}');
}

// Known at build time: compiled into the program, for every worker to read.
let HOLIDAYS = [
    Holiday { date: "2026-02-24", name: "Independence Day" },
    Holiday { date: "2026-06-24", name: "Midsummer Day" },
];

// The worker's own state: it lasts as long as the worker, and no other
// worker sees it.
struct App { lookups: i64 }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "GET", "/holidays") {
            rest::route(cx) {
                cx.app.lookups++;
                rest::json(cx, 200, HOLIDAYS);
            };
        } else if rest::on(cx, "GET", "/lookups") {
            rest::route(cx) { rest::text(cx, 200, str(cx.app.lookups)); };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config) {
    var app = App { lookups: 0 };
    let e = rest::serve(cfg, app) { cx => handle(cx) };
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
    let cfg = http::Config { port: port as i32, workers: 1, .. };
    thread_wait(thread_spawn(worker, cfg));
}
