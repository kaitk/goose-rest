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
//
// production-stack's, behind its edge, which verifies the JWT and passes
// X-User-Id on /api:
//
//   GET        /public/baseline?a=&b=, /public/json/:count
//                                  as /baseline2 and /json/:count
//   GET        /api/items/:id      the item, from the cache or Postgres, with
//                                  X-Cache HIT or MISS
//   POST       /api/items/:id      {"name","price","quantity"}: updates the
//                                  item, and drops it from the cache; 204
//   GET        /api/me             the user X-User-Id names, through the cache
import std;
import os;
import dictionary;
import json;
import http;
import plod;
import plod.compression;
import plod.websocket;
import pg;
import pg.pool;
import pg.socket;

enum Use {
    None,
    Delay { ms: i64 },
    File,
    Echo,
    Items { lo: i64, hi: i64, limit: i64 },
    Cache,
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
        plod::scope(cx, "/public") {
            plod::get(cx, "/baseline") { sum(cx, ""); };
            plod::scope(cx, "/json") {
                plod::compressed(cx) { cx =>
                    plod::get(cx, "/:count") { items(cx, plod::param_int(cx, "count")); };
                };
            };
        };
        plod::scope(cx, "/api") {
            // The edge sets it after authsvc has verified the token; without
            // it, the request didn't come through the edge.
            let user, has_user = plod::header(cx, "X-User-Id");
            guard has_user else { plod::fail(cx, 401, "unauthorized"); }
            plod::get(cx, "/items/:id") {
                let id = plod::param_int(cx, "id");
                ask_cache(cx, id, id, CacheJob.Item { id: id });
            };
            plod::post(cx, "/items/:id") {
                let id = plod::param_int(cx, "id");
                let b = plod::take<ItemUpdate>(cx);
                ask_cache(cx, id, id, CacheJob.Update { id: id, name: b.name, price: b.price, quantity: b.quantity });
            };
            plod::get(cx, "/me") {
                let id = plod::int_of(cx, user, "X-User-Id");
                turn++;
                ask_cache(cx, id, turn, CacheJob.User { id: id });
            };
        };
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

// The columns item_of reads, in its order.
let ITEMS = "SELECT id, name, category, price, quantity, active, tags, rating_score, rating_count FROM items WHERE price BETWEEN $1 AND $2 LIMIT $3";

fn async_db(cx) {
    var lo, has_lo = plod::query_int(cx, "min");
    var hi, has_hi = plod::query_int(cx, "max");
    var limit, has_limit = plod::query_int(cx, "limit");
    if !has_lo { lo = 10; }
    if !has_hi { hi = 50; }
    limit = if has_limit { min(max(limit, 1), 50) } else { 50 };
    guard db_ok else {
        no_items(cx);
        return;
    }
    plod::own_waits(cx, Use.Items { lo: lo, hi: hi, limit: limit });
    resume(cx.state.use, cx);
}

// What HttpArena asks for when Postgres doesn't answer.
fn no_items(cx) {
    var none: Item[>..] = [];
    plod::json(cx, 200, Listing<Item> { items: none, count: 0 });
}

// At the request, and at each later event of the query: a connection handed
// over, the socket ready, its time limit passed, or the client gone, where
// the pool gives its connection back. The block sees every row in the call
// that finds the whole answer.
fn resume(u: Use.Items, cx) {
    var rows: Item[>..] = [];
    var fits = true;
    let n = pg::query(cx.app.db, cx.state.ticket, cx.out, cx.kind, cx.reply, 5000, ITEMS, u.lo, u.hi, u.limit) { r =>
        let it .= rows.push(Item { .. });
        fits = item_of(r, it) && fits;
    };
    if n == pg::WAITS { return; }
    if n == pg::FAILS {
        no_items(cx);
        return;
    }
    guard fits else { plod::fail(cx, 500, "too_long"); }
    plod::json(cx, 200, Listing<Item> { items: rows, count: n });
}

// it from a row of ITEMS' columns, or false where a string doesn't fit Item.
fn item_of(r, it: Item&) -> bool {
    var scratch: u8[>..] = [];
    it.id = pg::int(r, 0);
    var fits = fill(it.name, pg::text(r, 1)) && fill(it.category, pg::text(r, 2));
    it.price = pg::int(r, 3);
    it.quantity = pg::int(r, 4);
    it.active = pg::boolean(r, 5);
    var tags = json::reader(pg::text(r, 6));
    fits = read_tags(tags, scratch, it.tags) && json::finish(tags) && fits;
    it.rating = Rating { score: pg::int(r, 7), count: pg::int(r, 8) };
    return fits;
}

// production-stack's cache, of lanes, each a thread that owns the cache of
// the ids it's given and a Postgres connection. One lane answers for each
// item, so that a write and the reads after it meet one cache, where a
// worker's own would miss the writes other workers took. Users, which
// nothing writes, go to each lane in turn, so that /api/me, whose user is
// the same on every request, doesn't queue on one lane.
//
// A lane blocks on Postgres for each miss, and the jobs behind it wait, so
// there are as many lanes as workers: the misses grow with the load the
// workers take. A lane costs a thread and its box, and waits on the box
// while idle. The lanes' connections take at most half of
// DATABASE_MAX_CONN, and the workers' pools share the rest.
let ITEM_TTL_NS: i64 = 1000000000;
let USER_TTL_NS: i64 = 30000000000;

enum CacheJob {
    Item { id: i64 },
    Update { id: i64, name: u8[..64], price: i64, quantity: i64 },
    User { id: i64 },
}

// What the cache holds for an id: its row, until when, by the monotonic
// clock, and, in a reply, whether it came from the cache.
struct Cached<T> { v: T, until: i64 = 0, hit: bool = false }

var caches: plod::Lane<CacheJob, Use>[>..];

// The worker's count of /api/me requests, which picks their lanes.
var turn = 0;

// A reply's slot: a Cached<Item>, the job it echoes, and the job's length
// take under 512 bytes.
let REPLY_SLOT: i32 = 512;

// A reply's promise from the worker's gather budget, 64 MB: ask's default,
// 64 KB, would hold 1,024 waits, where this holds max_waiting's 16,384.
let REPLY_MOST = 4096;

// Opens cache_lanes lanes, and sizes the boxes from the waits there can be:
// each worker's box takes a reply for each of its max_waiting waits, and
// each lane's box a job for its share of every worker's, so that neither
// refuses one while the waits are within their bound. A box's slots are a
// power of two.
fn open_caches(cfg: http::Config&) {
    guard cache_lanes > 0 else { return; }
    let workers = http::worker_count(cfg);
    let lane_slots = power_of_two((workers * cfg.max_waiting + cache_lanes - 1) / cache_lanes);
    for i in cache_lanes {
        caches.push(plod::lane_open<CacheJob>(http::LaneConfig { slots: lane_slots, .. }, Use.Cache, cache));
    }
    cfg.mail_slots = max(cfg.mail_slots, power_of_two(cfg.max_waiting));
    cfg.mail_size = REPLY_SLOT;
    write_stderr(str("cache: ", workers, " workers, ", cache_lanes, " lanes of ", lane_slots, " slots, ",
                     cfg.mail_slots, " reply slots a worker, pools of ", per_worker, "\n"));
}

// The least power of two of at least n and 2, a box's slots.
fn power_of_two(n: i64) -> i32 {
    var p = 2;
    while p < n { p *= 2; }
    return p as i32;
}

fn stop_caches() {
    for l in caches { plod::lane_stop(l); }
}

// Asks the lane owner picks for job.
fn ask_cache(cx, id: i64, owner: i64, job: CacheJob) {
    guard id > 0 else { plod::fail(cx, 404, "not_found"); }
    guard caches.len > 0 else { plod::fail(cx, 503, "no_cache"); }
    plod::ask(cx, caches[owner % caches.len], job, 5000, REPLY_MOST);
}

fn resume(u: Use.Cache, cx) { resume(plod::job<CacheJob>(cx), cx); }
fn resume(u: CacheJob.Item, cx) { cached(cx, plod::answer<Cached<Item>>(cx)); }
fn resume(u: CacheJob.User, cx) { cached(cx, plod::answer<Cached<User>>(cx)); }
fn resume(u: CacheJob.Update, cx) { plod::empty(cx, 204); }

// Answers c's row as JSON, with X-Cache.
fn cached(cx, c) {
    var body: u8[>..] = [];
    format(body, c.v);
    http::start(cx.out, 200);
    http::field(cx.out, "X-Cache", if c.hit { "HIT" } else { "MISS" });
    http::finish(cx.out, http::JSON, body);
}

thread_fn cache(box: http::Box, jobs: plod::Jobs<CacheJob>) {
    var items = dictionary<i64, Cached<Item>> {};
    var users = dictionary<i64, Cached<User>> {};
    var db = pg::Db { t: pg::Socket { .. }, .. };
    plod::lane(box, jobs) { u, a => run(u, items, users, db, a); };
    pg::close(db);
}

// ITEMS' columns, for item_of.
let ITEM = "SELECT id, name, category, price, quantity, active, tags, rating_score, rating_count FROM items WHERE id = $1";
let USER = "SELECT id, name, email, plan FROM users WHERE id = $1";
let UPDATE_ITEM = "UPDATE items SET name = $1, price = $2, quantity = $3 WHERE id = $4";

struct User { id: i64, name: u8[..64], email: u8[..64], plan: u8[..16] }

fn format(out: u8[>..]&, u: const User&) { plod::format_fields(out, u); }

fn run(u: CacheJob.Item, items: dictionary<i64, Cached<Item>>&, users: dictionary<i64, Cached<User>>&, db, a) {
    cache_aside(items, db, a, u.id, ITEM, ITEM_TTL_NS) { r, it => item_of(r, it) };
}

fn run(u: CacheJob.User, items: dictionary<i64, Cached<Item>>&, users: dictionary<i64, Cached<User>>&, db, a) {
    cache_aside(users, db, a, u.id, USER, USER_TTL_NS) { r, us =>
        us.id = pg::int(r, 0);
        fill(us.name, pg::text(r, 1)) && fill(us.email, pg::text(r, 2)) && fill(us.plan, pg::text(r, 3))
    };
}

fn run(u: CacheJob.Update, items: dictionary<i64, Cached<Item>>&, users: dictionary<i64, Cached<User>>&, db, a) {
    var n: i64 = 0;
    let failed = pg::run() {
        connected(db);
        n = pg::exec(db, UPDATE_ITEM, u.name[..], u.price, u.quantity, u.id);
    };
    guard failed.len == 0 else { plod::fail(a, 503, "database_unavailable"); }
    guard n == 1 else { plod::fail(a, 404, "not_found"); }
    items.remove(u.id);
    plod::reply_value(a, n);
}

// Replies the row cache holds for key while it holds, or else the row sql
// finds for key, which F reads into a T, returning false where it doesn't
// fit, and which cache then holds for ttl_ns.
inline fn cache_aside<F, T>(cache: dictionary<i64, Cached<T>>&, db, a, key: i64, sql: const u8[:], ttl_ns: i64) {
    let now = clock_ns();
    let held = cache.get(key);
    if held && held.until > now {
        var c = held;
        c.hit = true;
        plod::reply_value(a, c);
    } else {
        var c = Cached<T> { v: default<T>(), until: now + ttl_ns };
        // A reference, which F's untyped parameter takes as one, where it
        // would take the field c.v as a copy.
        let v .= c.v;
        var fits = true;
        var n: i64 = 0;
        let failed = pg::run() {
            connected(db);
            n = pg::query(db, sql, key) { r => fits = F(r, v); };
        };
        guard failed.len == 0 else { plod::fail(a, 503, "database_unavailable"); }
        guard n == 1 else { plod::fail(a, 404, "not_found"); }
        guard fits else { plod::fail(a, 500, "too_long"); }
        cache.insert(key, c);
        plod::reply_value(a, c);
    }
}

// Opens the lane's connection, again after one that broke.
fn connected(db) {
    if !pg::ready(db.c) { pg::open(db, db_cfg, 5000); }
}

// A POST /api/items/:id body.
struct ItemUpdate { name: u8[..64], price: i64, quantity: i64 }

fn read_update(r: json::Reader&, scratch: u8[>..]&) -> ItemUpdate {
    var name = r.text[..0];
    var price: i64 = 0;
    var quantity: i64 = 0;
    var has = 0;
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); has |= 1; }
        else if key == "price" { price = json::read_int(r); has |= 2; }
        else if key == "quantity" { quantity = json::read_int(r); has |= 4; }
        else { json::skip(r); }
    };
    if has != 7 { json::fail(r, "name, price, and quantity: required"); }
    if name.len > 64 { json::fail(r, "name: longer than 64 bytes"); }
    if r.error.len > 0 { return ItemUpdate { name: "", price: 0, quantity: 0 }; }
    return ItemUpdate { name: name, price: price, quantity: quantity };
}

fn plod::from_request(cx, v: const ItemUpdate?) -> ItemUpdate {
    plod::json_body(cx) { r, scratch => read_update(r, scratch) }
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

// An item as the dataset and Postgres's items table hold it, which
// /async-db and /api/items answer. The dataset's, which main loads before the
// workers start, each worker copies.
struct Rating { score: i64, count: i64 }

struct Item {
    id: i64,
    name: u8[..64],
    category: u8[..24],
    price: i64,
    quantity: i64,
    active: bool,
    tags: u8[..24][..6],
    rating: Rating,
}

var dataset: Item[>..];

fn format(out: u8[>..]&, r: const Rating&) { plod::format_fields(out, r); }
fn format(out: u8[>..]&, it: const Item&) { plod::format_fields(out, it); }

// /json's item: the dataset's, with its total at the request's multiplier.
struct Priced {
    id: i64,
    name: u8[..64],
    category: u8[..24],
    price: i64,
    quantity: i64,
    active: bool,
    tags: u8[..24][..6],
    rating: Rating,
    total: i64,
}

fn format(out: u8[>..]&, p: const Priced&) { plod::format_fields(out, p); }

// The answer of /json and /async-db: {"items":[...],"count":n}.
struct Listing<T> { items: const T[:], count: i64 }

fn format<T>(out: u8[>..]&, l: const Listing<T>&) { plod::format_fields(out, l); }

// The first count items, each with its total at multiplier m.
fn items(cx, count: i64) {
    guard dataset.len > 0 else { plod::fail(cx, 404, "no_dataset"); }
    guard count >= 1 && count <= dataset.len else { plod::fail(cx, 400, "invalid_count"); }
    var m, has_m = plod::query_int(cx, "m");
    if !has_m { m = 1; }
    var priced: Priced[>..] = [];
    for it in dataset[..count] {
        priced.push(Priced { id: it.id, name: it.name, category: it.category, price: it.price,
                             quantity: it.quantity, active: it.active, tags: it.tags, rating: it.rating,
                             total: it.price * it.quantity * m });
    }
    plod::json(cx, 200, Listing<Priced> { items: priced, count: count });
}

// s in to, or false where it's longer than to holds.
fn fill<T>(to: T&, s: const u8[:]) -> bool {
    guard s.len <= to.cap else { return false; }
    to.clear();
    to.append(s);
    return true;
}

// The string at r's cursor in to, or false where it doesn't fit.
fn read_text<T>(r: json::Reader&, scratch: u8[>..]&, to: T&) -> bool {
    scratch.clear();
    return fill(to, json::read_string(r, scratch));
}

// The array of strings at r's cursor in tags, or false where one doesn't fit.
fn read_tags(r: json::Reader&, scratch: u8[>..]&, tags: u8[..24][..6]&) -> bool {
    var fits = true;
    json::each_element(r) {
        if tags.len < tags.cap {
            let t .= tags.push("");
            fits = read_text(r, scratch, t) && fits;
        } else {
            json::skip(r);
            fits = false;
        }
    };
    return fits;
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
            else if key == "name" { fits = read_text(r, scratch, it.name) && fits; }
            else if key == "category" { fits = read_text(r, scratch, it.category) && fits; }
            else if key == "price" { it.price = json::read_int(r); }
            else if key == "quantity" { it.quantity = json::read_int(r); }
            else if key == "active" { it.active = json::read_bool(r); }
            else if key == "tags" { fits = read_tags(r, scratch, it.tags) && fits; }
            else if key == "rating" {
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
// worker copies: db_ok once DATABASE_URL is usable, each worker's share of
// DATABASE_MAX_CONN, and the cache's lanes, one connection each.
var db_cfg: pg::Config;
var db_ok = false;
var per_worker = 1;
var cache_lanes = 0;

// Reads DATABASE_URL and DATABASE_MAX_CONN, the connections over all of
// cfg's workers and the cache's lanes, 256 without it, less one: HttpArena's
// Postgres allows exactly DATABASE_MAX_CONN, and a pool that took them all
// would refuse any other client, such as a check with psql. The lanes are only
// where API_CACHE is set, as production-stack's compose file sets it.
// Without a usable URL, /async-db answers no_items, and /api 503.
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
    total = max(total - 1, 1);
    let workers = http::worker_count(cfg);
    var on: u8[>..] = [];
    if env("API_CACHE", on) { cache_lanes = max(min(workers, total / 2), 1); }
    per_worker = max((total - cache_lanes) / workers, 1);
}

// The configuration both root files serve: HttpArena's 8080, h2c on 8082,
// and the waits of /delay and /async-db, as many a worker as its
// connections. Its box takes the pool's hand-overs, one per connection of a
// pool of fewer than 256.
fn config() -> http::Config {
    var cfg = http::Config { port: 8080, mail_slots: 256, .. };
    cfg.max_waiting = cfg.max_conns;
    cfg.listeners.push(http::Listener { port: 8082, h2c: true });
    return cfg;
}
