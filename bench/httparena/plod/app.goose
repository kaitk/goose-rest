// Plod's HttpArena entry: the endpoints of the profiles it subscribes to
// (meta.json), written as an application on Plod writes them. server.goose
// and server_tls.goose are its root files: the second adds the TLS
// listeners, and links OpenSSL, which the first doesn't map.
//
//   GET, POST  /baseline11?a=&b=   a + b, plus the body's integer for a POST
//   GET        /baseline2?a=&b=    the same, as the h2 profiles name it
//   GET        /pipeline           "ok"
//   GET        /json/:count?m=     the dataset's first count items, compressed
//                                  as the request's Accept-Encoding takes
//   GET        /delay/:ms          ms, after ms milliseconds
//   POST       /echo               the body, as it came
//   GET        /static/*name       the file of /data/static
//   GET        /ws                 a WebSocket that echoes each message
import std;
import os;
import json;
import http;
import plod;
import plod.compression;
import plod.websocket;

enum Use {
    None,
    Delay { ms: i64 },
    File,
    Echo,
}

struct St {
    use: Use = Use.None,
    file: http::FileBody = http::FileBody { .. },
    ws: http::WebSocket = http::WebSocket { .. },
}

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/baseline11") { sum(cx, ""); };
        plod::post(cx, "/baseline11") { sum(cx, plod::body(cx)); };
        plod::get(cx, "/baseline2") { sum(cx, ""); };
        plod::get(cx, "/pipeline") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/json") {
            plod::compressed(cx) { cx =>
                plod::get(cx, "/:count") { items(cx, plod::param_int(cx, "count")); };
            };
        };
        plod::get(cx, "/delay/:ms") {
            let ms = plod::param_int(cx, "ms");
            guard ms >= 0 && ms <= 3600000 else { plod::fail(cx, 400, "invalid_delay"); }
            plod::pause(cx, ms, Use.Delay { ms: ms });
        };
        plod::post(cx, "/echo") { http::respond(cx.out, 200, "application/octet-stream", plod::body(cx)); };
        plod::get(cx, "/static/*name") {
            var path: u8[>..] = [];
            guard http::file_path(STATIC, plod::param(cx, "name"), path) else { plod::fail(cx, 404, "file_not_found"); }
            plod::file(cx, path, cx.state.file, Use.File);
        };
        plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };
    };
}

// The query's a and b, and n, the body's integer if it has one.
fn sum(cx, body: const u8[:]) {
    let a, _ = plod::query_int(cx, "a");
    let b, _ = plod::query_int(cx, "b");
    let n, _ = parse_int(trim(body));
    var text: u8[..24] = [];
    format(text, a + b + n);
    plod::text(cx, 200, text);
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

fn resume(u: Use.Delay, cx) {
    var text: u8[..24] = [];
    format(text, u.ms);
    plod::text(cx, 200, text);
}

fn resume(u: Use.File, cx) { plod::send_file(cx, cx.state.file); }

fn resume(u: Use.Echo, cx) {
    plod::ws_read(cx, cx.state.ws) { op, data => http::ws_send(cx.out, op, data); };
}

fn on_call(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        handle(cx);
    }
}

// Where HttpArena mounts the static profiles' files.
let STATIC = "/data/static";

// The dataset's items, which main loads before the workers start, and each
// worker copies.
struct Rating { score: i64, count: i64 }

struct Item {
    id: i64,
    name: u8[..48],
    category: u8[..24],
    price: i64,
    quantity: i64,
    active: bool,
    tags: u8[..24][..6],
    rating: Rating,
}

var dataset: Item[>..];

fn format(out: u8[>..]&, r: const Rating&) { plod::format_fields(out, r); }

// The first count items, each with its total at multiplier m, as
// {"items":[...],"count":count}.
struct Listing { count: i64, m: i64 }

fn format(out: u8[>..]&, l: const Listing&) {
    out.append("{\"items\":[");
    for i in l.count {
        let it = dataset[i];
        if i > 0 { out.push(','); }
        format(out, "{\"id\":", it.id, ",\"name\":");
        http::json_string(out, it.name);
        out.append(",\"category\":");
        http::json_string(out, it.category);
        format(out, ",\"price\":", it.price, ",\"quantity\":", it.quantity, ",\"active\":", it.active, ",\"tags\":[");
        for t, k in it.tags {
            if k > 0 { out.push(','); }
            http::json_string(out, t);
        }
        out.append("],\"rating\":");
        format(out, it.rating);
        format(out, ",\"total\":", it.price * it.quantity * l.m, "}");
    }
    format(out, "],\"count\":", l.count, "}");
}

fn items(cx, count: i64) {
    guard dataset.len > 0 else { plod::fail(cx, 404, "no_dataset"); }
    guard count >= 1 && count <= dataset.len else { plod::fail(cx, 400, "invalid_count"); }
    var m, has_m = plod::query_int(cx, "m");
    if !has_m { m = 1; }
    plod::json(cx, 200, Listing { count: count, m: m });
}

// The string at r's cursor, or false where it's longer than cap.
fn string_of(r: json::Reader&, scratch: u8[>..]&, cap: i64) -> const u8[:], bool {
    scratch.clear();
    let s = json::read_string(r, scratch);
    return if s.len <= cap { s } else { "" }, s.len <= cap;
}

// Loads DATASET's file, /data/dataset.json by default. Without one,
// /json/:count answers 404; one that doesn't parse ends the process.
fn load_dataset() {
    var path: u8[>..] = [];
    if !env("DATASET", path) { path.append("/data/dataset.json"); }
    var text: u8[>..] = [];
    guard read_file(path, text) else { return; }
    var scratch: u8[>..] = [];
    var fits = true;
    var r = json::reader(text);
    json::each_element(r) {
        var it = Item { .. };
        json::each_member(r) { key =>
            if key == "id" { it.id = json::read_int(r); }
            else if key == "name" {
                let s, ok = string_of(r, scratch, it.name.cap);
                it.name.append(s);
                fits = fits && ok;
            } else if key == "category" {
                let s, ok = string_of(r, scratch, it.category.cap);
                it.category.append(s);
                fits = fits && ok;
            } else if key == "price" { it.price = json::read_int(r); }
            else if key == "quantity" { it.quantity = json::read_int(r); }
            else if key == "active" { it.active = json::read_bool(r); }
            else if key == "tags" {
                json::each_element(r) {
                    if it.tags.len < it.tags.cap {
                        let t .= it.tags.push("");
                        let s, ok = string_of(r, scratch, t.cap);
                        t.append(s);
                        fits = fits && ok;
                    } else {
                        json::skip(r);
                        fits = false;
                    }
                };
            } else if key == "rating" {
                json::each_member(r) { k =>
                    if k == "score" { it.rating.score = json::read_int(r); }
                    else if k == "count" { it.rating.count = json::read_int(r); }
                    else { json::skip(r); }
                };
            } else { json::skip(r); }
        };
        dataset.push(it);
    };
    guard json::finish(r) else { abort(str(path, ": ", json::message(r))); }
    guard fits else { abort(str(path, ": a name, category, or tag too long, or more than 6 tags")); }
}

// The configuration both root files serve: HttpArena's 8080, h2c on 8082,
// and /delay's timers, up to 16,384 waiting a worker, as many as its
// connections.
fn config() -> http::Config {
    var cfg = http::Config { port: 8080, mail_slots: 256, max_waiting: 16384, .. };
    cfg.listeners.push(http::Listener { port: 8082, h2c: true });
    return cfg;
}
