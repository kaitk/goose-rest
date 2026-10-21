// The application's entry: the program's types, its constant, and its
// routes. main.goose imports it to serve, and a test imports it as a package,
// `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import rest;

struct Holiday { date: const u8[:], name: const u8[:] }

fn format(out: u8[>..]&, h: const Holiday&) {
    out.append("{\"date\":");
    http::json_string(out, h.date);
    out.append(",\"name\":");
    http::json_string(out, h.name);
    out.push('}');
}

// Known at build time: compiled into the program, for every worker to read.
let HOLIDAYS = [
    Holiday { date: "2026-02-24", name: "Independence Day" },
    Holiday { date: "2026-06-24", name: "Midsummer Day" },
];

// The worker state: it lasts as long as the worker, and no other
// worker sees it.
struct App { lookups: i64 }

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        rest::get(cx, "/holidays") {
            // This worker's own count: each worker keeps one.
            cx.app.lookups++;
            // The global, compiled into the program, which every worker reads.
            rest::json(cx, 200, HOLIDAYS);
        };
        rest::get(cx, "/lookups") { rest::text(cx, 200, str(cx.app.lookups)); };
    };
}
