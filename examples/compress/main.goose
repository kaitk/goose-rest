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
import http from "github.com/kaitk/goose-http@v0.4.3";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
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
            rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
            // goose-http's defaults: level 1, zstd offered, from 1 KB.
            rest::scope(cx, "/v1") { rest::compressed(cx) { cx => events(cx); }; };
            rest::scope(cx, "/archive") { rest::compressed(cx, ARCHIVE) { cx => events(cx); }; };
        };
    };
}

// The routes under /v1 and /archive.
fn events(cx) {
    rest::get(cx, "/events") {
        var limit, has_limit = rest::query_int(cx, "limit");
        if !has_limit { limit = 50; }
        guard limit >= 0 && limit <= EVENTS else { rest::fail(cx, 400, "invalid_limit"); }
        rest::json(cx, 200, Listing { limit: limit });
    };
    rest::get(cx, "/export") {
        var limit, has_limit = rest::query_int(cx, "limit");
        if !has_limit { limit = EVENTS; }
        guard limit >= 0 && limit <= EVENTS else { rest::fail(cx, 400, "invalid_limit"); }
        rest::begin(cx, 200, "application/x-ndjson", -1, Use.Export { limit: limit });
    };
    rest::get(cx, "/events/:id") {
        let id = rest::param_int(cx, "id");
        guard id >= 1 && id <= EVENTS else { rest::fail(cx, 404, "event_not_found"); }
        rest::json(cx, 200, Event { id: id });
    };
}

// The export's events sent at each MORE.
let EXPORT_PIECE: i64 = 100;

enum Use {
    None,
    Export { limit: i64 },
}

struct St {
    use: Use = Use.None,
    next: i64 = 0,   // the export's next event
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The next events of the export, a line each, and the end after the last.
// It runs outside rest::compressed: the response keeps the coding it began
// with.
fn resume(u: Use.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: the state holds nothing to release
    var piece: u8[>..] = [];
    let end = min(cx.state.next + EXPORT_PIECE, u.limit);
    while cx.state.next < end {
        cx.state.next++;
        format(piece, Event { id: cx.state.next });
        piece.push('\n');
    }
    rest::send(cx, piece);
    if cx.state.next == u.limit { rest::end(cx); }
}

thread_fn worker(cfg: http::Config) {
    var none = rest::NoState { .. };
    let e = rest::serve(cfg, none, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::on_reply(cx) { resume(cx.state.use, cx); };
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
    http::run(cfg, worker);
}
