// Answers compressed by the request's Accept-Encoding: a service's event log
// behind rest::compressed, which only a program that imports
// rest.compression builds with, and goose-compress with it. A listing past
// 1 KB comes compressed; one event, an error, or /health is too short for it.
//
//   goose build -o build/examples/compress examples/compress/main.goose
//   build/examples/compress 8080
//   curl -s --compressed -D - 'localhost:8080/v1/events?limit=100'
import std;
import http from "github.com/kaitk/goose-http@v0.3.1";
import compress from "github.com/kaitk/goose-compress@2c7df270b88ed8a00e2d73b6f84d50908cf5a558";
import rest from "../../";
import rest.compression;

// The log holds this many events, made up from their ids.
let EVENTS: i64 = 1000;

struct Event { id: i64 }

fn format(out: u8[>..]&, e: const Event&) {
    format(out, "{\"id\":", e.id, ",\"level\":\"", if e.id % 10 == 0 { "warn" } else { "info" },
           "\",\"message\":\"disk check on node-", e.id % 8, "\"}");
}

// The first limit events, as a JSON array.
struct Listing { limit: i64 }

fn format(out: u8[>..]&, l: const Listing&) {
    out.push('[');
    for i in l.limit {
        if i > 0 { out.push(','); }
        format(out, Event { id: i + 1 });
    }
    out.push(']');
}

fn handle(cx) {
    rest::timed(cx) {
        rest::compressed(cx) { cx =>
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    rest::route(cx) { events(cx); };
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}

// The routes under /v1, inside the route.
fn events(cx) {
    if rest::on(cx, "GET", "/events") {
        var limit, has_limit = rest::query_int(cx, "limit");
        if !has_limit { limit = 50; }
        guard limit >= 0 && limit <= EVENTS else { rest::fail(cx, 400, "invalid_limit"); }
        rest::json(cx, 200, Listing { limit: limit });
    } else if rest::on(cx, "GET", "/events/:id") {
        let id = rest::param_int(cx, "id");
        guard id >= 1 && id <= EVENTS else { rest::fail(cx, 404, "event_not_found"); }
        rest::json(cx, 200, Event { id: id });
    } else {
        rest::otherwise(cx);
    }
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
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
