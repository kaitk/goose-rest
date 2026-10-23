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
//   GET        /static/*name       the file of /data/static, or its .br or .gz
//                                  copy as the request's Accept-Encoding takes
//   GET        /ws                 a WebSocket that echoes each message
//   GET        /async-db?min=&max=&limit=
//                                  the items priced min to max, at most limit,
//                                  from Postgres at DATABASE_URL
import std;
import os;
import json;
import http;
import plod;
import plod.compression;
import plod.websocket;
import pg;
import pg.pool;

enum Use {
    None,
    Delay { ms: i64 },
    File,
    Echo,
    Items { lo: i64, hi: i64, limit: i64 },
}

struct St {
    use: Use = Use.None,
    file: http::FileBody = http::FileBody { .. },
    ws: http::WebSocket = http::WebSocket { .. },
    ticket: pg::Ticket = pg::Ticket { .. },
}

// The worker state: the worker's pool of Postgres connections, which ends it.
struct App { db: pg::Pool }

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
        plod::get(cx, "/static/*name") { plod::files(cx, STATIC, "name", cx.state.file, Use.File); };
        plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };
        plod::get(cx, "/async-db") { async_db(cx); };
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

let ITEMS = "SELECT id, name, category, price, quantity, active, tags, rating_score, rating_count FROM items WHERE price BETWEEN $1 AND $2 LIMIT $3";

// What HttpArena asks for when Postgres doesn't answer.
let NO_ITEMS = "{\"items\":[],\"count\":0}";

fn async_db(cx) {
    var lo, has_lo = plod::query_int(cx, "min");
    var hi, has_hi = plod::query_int(cx, "max");
    var limit, has_limit = plod::query_int(cx, "limit");
    if !has_lo { lo = 10; }
    if !has_hi { hi = 50; }
    limit = if has_limit { min(max(limit, 1), 50) } else { 50 };
    guard db_ok else {
        plod::json_bytes(cx, 200, NO_ITEMS);
        return;
    }
    plod::own_waits(cx, Use.Items { lo: lo, hi: hi, limit: limit });
    resume(cx.state.use, cx);
}

// At the request, and at each later event of the query: a connection handed
// over, the socket ready, its time limit passed, or the client gone, where
// the pool gives its connection back. The block sees every row in the call
// that finds the whole answer.
fn resume(u: Use.Items, cx) {
    var body: u8[>..] = [];
    body.append("{\"items\":[");
    let n = pg::query(cx.app.db, cx.state.ticket, cx.out, cx.kind, cx.reply, 5000, ITEMS, u.lo, u.hi, u.limit) { r =>
        if body.len > 10 { body.push(','); }
        format(body, "{\"id\":", pg::text(r, 0), ",\"name\":");
        http::json_string(body, pg::text(r, 1));
        body.append(",\"category\":");
        http::json_string(body, pg::text(r, 2));
        format(body, ",\"price\":", pg::text(r, 3), ",\"quantity\":", pg::text(r, 4), ",\"active\":",
               if pg::boolean(r, 5) { "true" } else { "false" }, ",\"tags\":", pg::text(r, 6),
               ",\"rating\":{\"score\":", pg::text(r, 7), ",\"count\":", pg::text(r, 8), "}}");
    };
    if n == pg::WAITS { return; }
    if n == pg::FAILS {
        plod::json_bytes(cx, 200, NO_ITEMS);
        return;
    }
    format(body, "],\"count\":", n, "}");
    plod::json_bytes(cx, 200, body);
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

// The Postgres settings, which main reads before the workers start, and each
// worker copies: db_ok once DATABASE_URL is usable, and each worker's share
// of DATABASE_MAX_CONN.
var db_cfg: pg::Config;
var db_ok = false;
var per_worker = 1;

// Reads DATABASE_URL and DATABASE_MAX_CONN, the connections over all of
// cfg's workers, 256 without it. Without a usable URL, /async-db answers
// NO_ITEMS.
fn load_database(cfg: http::Config) {
    var url: u8[>..] = [];
    guard env("DATABASE_URL", url) else { return; }
    let settings, why = pg::url_settings(url);
    guard why.len == 0 else { return; }
    db_cfg = settings;
    db_ok = true;
    var text: u8[>..] = [];
    var total = 256;
    if env("DATABASE_MAX_CONN", text) {
        let n, ok = parse_int(trim(text));
        if ok && n > 0 { total = n; }
    }
    per_worker = max(total / http::worker_count(cfg), 1);
}

// The configuration both root files serve: HttpArena's 8080, h2c on 8082,
// and the waits of /delay and /async-db, up to 16,384 a worker, as many as
// its connections.
fn config() -> http::Config {
    var cfg = http::Config { port: 8080, mail_slots: 256, max_waiting: 16384, .. };
    cfg.listeners.push(http::Listener { port: 8082, h2c: true });
    return cfg;
}
