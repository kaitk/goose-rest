// Answers compressed by the request's Accept-Encoding: a service's event log
// behind rest::compressed, which only a program that imports
// rest.compression builds with, and goose-compress with it. Under /v1, with
// goose-http's defaults, a listing past 1 KB comes compressed; one event, an
// error, or /health is too short for it. /v1/export sends the events in
// pieces, compressed as they go. /archive serves the same events with options
// of its own.
//
//   goose build -o build/examples/compress examples/compress/main.goose
//   build/examples/compress 8080
//   curl -s --compressed -D - 'localhost:8080/v1/events?limit=100'
//   curl -s --compressed -D - 'localhost:8080/v1/export?limit=1000'
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import compress from "github.com/kaitk/goose-compress@v0.1.0";
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

// The archive's options: gzip and deflate at level 9, their smallest and
// slowest, no zstd, and bodies from 256 bytes. Only zstd can be turned off:
// gzip and deflate are always offered, and the request's Accept-Encoding
// picks among the codings left.
let ARCHIVE = http::Compression { min_size: 256, level: 9, zstd: false, .. };

fn handle(cx) {
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            if rest::on(cx, "GET", "/health") {
                rest::text(cx, 200, "ok");
            } else if rest::scope(cx, "/v1") {
                // goose-http's defaults: level 1, zstd offered, from 1 KB.
                rest::compressed(cx) { cx =>
                    rest::route(cx) { events(cx); };
                };
            } else if rest::scope(cx, "/archive") {
                rest::compressed(cx, ARCHIVE) { cx =>
                    rest::route(cx) { events(cx); };
                };
            } else {
                rest::otherwise(cx);
            }
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
    } else if rest::on(cx, "GET", "/export") {
        var limit, has_limit = rest::query_int(cx, "limit");
        if !has_limit { limit = EVENTS; }
        guard limit >= 0 && limit <= EVENTS else { rest::fail(cx, 400, "invalid_limit"); }
        rest::begin(cx, 200, "application/x-ndjson", -1, Waiting.Export { limit: limit });
    } else if rest::on(cx, "GET", "/events/:id") {
        let id = rest::param_int(cx, "id");
        guard id >= 1 && id <= EVENTS else { rest::fail(cx, 404, "event_not_found"); }
        rest::json(cx, 200, Event { id: id });
    } else {
        rest::otherwise(cx);
    }
}

// The export's events sent at each MORE.
let EXPORT_PIECE: i64 = 100;

enum Waiting {
    None,
    Export { limit: i64 },
}

struct St {
    waiting: Waiting = Waiting.None,
    next: i64 = 0,   // the export's next event
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The next events of the export, a line each, and the end after the last.
// It runs outside rest::compressed: the response keeps the coding it began
// with.
fn resume(w: Waiting.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: the state holds nothing to release
    var piece: u8[>..] = [];
    let end = min(cx.state.next + EXPORT_PIECE, w.limit);
    while cx.state.next < end {
        cx.state.next++;
        format(piece, Event { id: cx.state.next });
        piece.push('\n');
    }
    rest::send(cx, piece);
    if cx.state.next == w.limit { rest::end(cx); }
}

thread_fn worker(cfg: http::Config) {
    var none = rest::NoState { .. };
    let e = rest::serve(cfg, none, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::route(cx) { resume(cx.state.waiting, cx); };
        } else {
            handle(cx);
        }
    };
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
