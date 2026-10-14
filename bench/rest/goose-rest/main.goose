// goose-http's task 021 REST server on goose-rest (task 010): the same routes,
// records, and JSON as goose-http's bench/rest/goose at e27ab21, served through
// rest::serve, an http::router chain per tier, rest's extractors, its bearer
// middleware, and rest::fail with each tier's error shape (error_body below).
// It loads the generator's dataset files (goose-http's bench/rest/gen.goose)
// at startup. Tier A is HttpArena's production-stack application layer:
//
//   GET  /api/items/:id    the item, and servedAt, the time in seconds
//   GET  /api/me           the user X-User-Id names, and servedAt
//   POST /api/items/:id    a body of name, price, and quantity, each optional:
//                          204, or 422 for a body that isn't one; the data
//                          doesn't change, so every server serves the same
//
// Tier B is snowtime's k6 hot path, answered as snowtime's Hono routes answer:
//
//   GET   /api/v1/session                        the session, or null
//   GET   /api/v1/timer                          the running timer, or null
//   GET   /api/v1/organizations/:org/entries     ?from=&to=&userId=
//   GET   /api/v1/organizations/:org/projects    ?includeArchived=
//   PATCH /api/v1/organizations/:org/entries/:id {"description"}
//   POST  /api/v1/organizations/:org/timer/start {"id","description",...}
//   POST  /api/v1/timer/stop                     {"id"}
//
// Tier C is a clinic's schedule and records, synthetic, behind a bearer JWT:
//
//   GET   /api/v2/schedule/version               ?since=, the schedule's poll
//   GET   /api/v2/schedule/bookings              ?start=&end=&staff=1,2,...
//   GET   /api/v2/schedule/shifts                ?start=&end=&staff=1,2,...
//   GET   /api/v2/encounters/:id                 the visit, and its case's notes
//   GET   /api/v2/clients/:id/encounters         ?limit=, the past visits
//   GET   /api/v2/clients/:id                    the client
//
// Tier D is writes with large bodies, answered from the body alone, beside
// tier C's routes, behind the same token:
//
//   POST  /api/v3/imports                        a CSV: its rows, and each column's count and sum
//   POST  /api/v3/attachments                    multipart: the fields, the file's size and Adler-32
//   POST  /api/v3/bookings/batch                 JSON: each booking's id, or 422 with the errors
//   POST  /api/v3/forms                          a form: its fields, decoded
//
//   REST_DATA=DIR TIER=a|b|c|d WORKERS=n [LOOP=epoll] [JSON=template] rest [port]
//
// TIER picks the dataset to load, tier A's by default. JSON=template answers
// from each record's JSON, written once at startup, with the per-request
// values added, where the default writes each response's JSON from the
// records. Tier D's answers are written the one way, as each is new. Its
// bodies come whole, gathered by rest::body.
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../../../";
import .github_app;
import .github_gen;

struct Item {
    id: i64,
    name: u8[..48],
    category: u8[..24],
    price: i64,
    quantity: i64,
    active: bool,
    tags: u8[..24][..4],
    score: i64,
    count: i64,
}

struct User { id: i64, name: u8[..48], email: u8[..48], plan: u8[..16] }

// Loaded by main before the workers start, each of which copies them.
var items: Item[>..];
var users: User[>..];
var template: bool;
// JSON=template's prebuilt records, without their closing brace: item i's
// is item_json[item_at[i]..item_at[i + 1]].
var item_json: u8[>..];
var item_at: i64[>..];
var user_json: u8[>..];
var user_at: i64[>..];

fn load(dir: const u8[:], name: const u8[:], text: u8[>..]&) {
    let path = str(dir, "/", name);
    guard read_file(path, text) else { abort(str("can't read ", path, "; run bench/rest/gen.goose")); }
}

// The string at r's cursor, at most cap bytes, which a field of that capacity
// appends: a field given here as an untyped parameter would be a copy.
fn string_of(r: json::Reader&, scratch: u8[>..]&, cap: i64) -> const u8[:] {
    scratch.clear();
    let s = json::read_string(r, scratch);
    guard s.len <= cap else { abort(str("a string longer than ", cap, ": ", s)); }
    return s;
}

fn load_items(dir: const u8[:]) {
    var text: u8[>..] = [];
    load(dir, "arena-items.json", text);
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_element(r) {
        var it = Item { .. };
        json::each_member(r) { key =>
            if key == "id" { it.id = json::read_int(r); }
            else if key == "name" { it.name.append(string_of(r, scratch, it.name.cap)); }
            else if key == "category" { it.category.append(string_of(r, scratch, it.category.cap)); }
            else if key == "price" { it.price = json::read_int(r); }
            else if key == "quantity" { it.quantity = json::read_int(r); }
            else if key == "active" { it.active = json::read_bool(r); }
            else if key == "tags" {
                json::each_element(r) {
                    guard it.tags.len < it.tags.cap else { abort("more than 4 tags"); }
                    let t .= it.tags.push("");
                    t.append(string_of(r, scratch, t.cap));
                };
            } else if key == "rating" {
                json::each_member(r) { k =>
                    if k == "score" { it.score = json::read_int(r); }
                    else if k == "count" { it.count = json::read_int(r); }
                    else { json::skip(r); }
                };
            } else { json::skip(r); }
        };
        guard it.id == items.len + 1 else { abort("arena-items.json's ids aren't 1, 2, ..."); }
        items.push(it);
    };
    guard json::finish(r) else { abort(json::message(r)); }
}

fn load_users(dir: const u8[:]) {
    var text: u8[>..] = [];
    load(dir, "arena-users.json", text);
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_element(r) {
        var u = User { .. };
        json::each_member(r) { key =>
            if key == "id" { u.id = json::read_int(r); }
            else if key == "name" { u.name.append(string_of(r, scratch, u.name.cap)); }
            else if key == "email" { u.email.append(string_of(r, scratch, u.email.cap)); }
            else if key == "plan" { u.plan.append(string_of(r, scratch, u.plan.cap)); }
            else { json::skip(r); }
        };
        guard u.id == users.len + 1 else { abort("arena-users.json's ids aren't 1, 2, ..."); }
        users.push(u);
    };
    guard json::finish(r) else { abort(json::message(r)); }
}

// An item's JSON without its closing brace.
fn item_open(out: u8[>..]&, it: Item) {
    out.append("{\"id\":");
    format(out, it.id);
    out.append(",\"name\":");
    json::format_string(out, it.name);
    out.append(",\"category\":");
    json::format_string(out, it.category);
    out.append(",\"price\":");
    format(out, it.price);
    out.append(",\"quantity\":");
    format(out, it.quantity);
    out.append(if it.active { ",\"active\":true,\"tags\":[" } else { ",\"active\":false,\"tags\":[" });
    for t, i in it.tags {
        if i > 0 { out.push(','); }
        json::format_string(out, t);
    }
    out.append("],\"rating\":{\"score\":");
    format(out, it.score);
    out.append(",\"count\":");
    format(out, it.count);
    out.push('}');
}

fn user_open(out: u8[>..]&, u: User) {
    out.append("{\"id\":");
    format(out, u.id);
    out.append(",\"name\":");
    json::format_string(out, u.name);
    out.append(",\"email\":");
    json::format_string(out, u.email);
    out.append(",\"plan\":");
    json::format_string(out, u.plan);
}

fn prebuild() {
    for it in items {
        item_at.push(item_json.len);
        item_open(item_json, it);
    }
    item_at.push(item_json.len);
    for u in users {
        user_at.push(user_json.len);
        user_open(user_json, u);
    }
    user_at.push(user_json.len);
}

// The record's JSON, and servedAt, the time in seconds, into body.
fn served(body: u8[>..]&) {
    body.append(",\"servedAt\":");
    format(body, http::net_time_s());
    body.push('}');
}

// id as a record's index, or -1 when it isn't one of n.
fn index_of(id: const u8[:], n: i64) -> i64 {
    let v, ok = parse_int(id);
    return if ok && v >= 1 && v <= n { v - 1 } else { -1 };
}

// A write's body: an object of name (a string), price, and quantity
// (integers), each optional. Whether it's one.
fn valid_write(body: const u8[:]) -> bool {
    var scratch: u8[>..] = [];
    var r = json::reader(body);
    guard json::peek(r) == '{' else { return false; }
    json::each_member(r) { key =>
        if key == "name" { json::read_string(r, scratch); }
        else if key == "price" || key == "quantity" { json::read_int(r); }
        else { json::skip(r); }
    };
    return json::finish(r);
}

// Tier B, snowtime's k6 hot path, under /api/v1. A session cookie names the
// user, by its token; a write needs Origin to be the app's. The data doesn't
// change: a PATCH answers the entry with the description it was sent, and
// timer start and stop answer as of now, as if the timer had started.

// Functions, as a worker's globals must be flat and a literal is a slice.
fn app_url() -> const u8[:] { "https://time.bench.example.com" }
fn session_cookie() -> const u8[:] { "__Secure-better-auth.session_token" }

let DAY: i64 = 86400000;
let MINUTE: i64 = 60000;

struct Org { id: u8[..36], name: u8[..16], slug: u8[..16], links: u8[..64], first: i64, count: i64 }

struct Project {
    id: u8[..36],
    name: u8[..48],
    color: u8[..7],         // empty for null
    archived: i64,          // ms, -1 for null
    has_entries: bool,
    teams: u8[..36][..2],
}

struct Member { org: i64, role: u8[..6] }

struct Settings {
    time_zone: u8[..32],
    week_start: u8[..3],
    locale: u8[..2],
    theme: u8[..6],
    timer_layout: u8[..5],
    show_summary: bool,
    compact_rows: bool,
    wide_timer: bool,
    timer_view: u8[..8],
    calendar_weekend: bool,
    app_icon: u8[..8],
    scene_collection: u8[..16],
    scene_pin: u8[..16],    // empty for null
    scene_background: bool,
    scene_strength: u8[..6],
    surfaces: u8[..5],
    scene_weather: bool,
    scene_intro: bool,
    scene_tagline: bool,
    duration_format: u8[..5],
    date_format: u8[..3],
    time_format: u8[..3],
    copy_pattern: u8[..16],
    copy_control: u8[..6],
    country: u8[..2],       // empty for null
}

struct Fill {
    date: u8[..10],
    timer_started: i64,     // -1 for null
    today: u8[..6],
    last_day: u8[..10],     // empty for null
    last_day_filled: bool,
    last_week: i64,         // 0, 1, or -1 for null
    last_month: i64,
    caught_up: bool,
    empty_days: i64,
    streak: i64,
}

struct Person {
    id: u8[..36],
    name: u8[..48],
    email: u8[..48],
    image: u8[..96],        // empty for null
    token: u8[..64],
    signed_in: i64,
    orgs: Member[..6],      // as the session lists them
    active: i64,
    teams: u8[..36][..2],   // in the active organization
    settings: Settings,
    fill: Fill,
    first: i64,             // the person's entries, entries[first..first + count]
    count: i64,
    running: i64,           // an entry, or -1
}

struct Entry {
    id: u8[..36],
    user: i64,
    org: i64,
    project: i64,           // -1 for null
    description: u8[..96],
    ticket: u8[..16],       // empty for null
    started: i64,
    stopped: i64,           // -1 for null
}

var orgs: Org[>..];
var projects: Project[>..];
var people: Person[>..];
var entries: Entry[>..];        // by person, then by start
var by_token: i64[>..];         // people, by token
var by_person_id: i64[>..];     // people, by id
var by_entry_id: i64[>..];      // entries, by id
// JSON=template's: each session, each project, and each entry whole; each
// running timer as GET /timer answers it; and where in each entry the
// description's value starts and ends, for a PATCH to put another there.
var session_json: u8[>..];
var session_at: i64[>..];
var project_json: u8[>..];
var project_at: i64[>..];
var entry_json: u8[>..];
var entry_at: i64[>..];
var entry_desc: i64[>..];
var entry_tail: i64[>..];
var timer_json: u8[>..];
var timer_at: i64[>..];

fn digits(out: u8[>..]&, v: i64, n: i64) {
    var div = 1;
    for i in n - 1 { div *= 10; }
    while div > 0 {
        out.push(('0' + v / div % 10) as u8);
        div /= 10;
    }
}

// ms since the epoch as JavaScript's toISOString writes it, from Howard
// Hinnant's civil_from_days.
fn format_iso(out: u8[>..]&, ms: i64) {
    let day = ms / DAY;
    let t = ms - day * DAY;
    let z = day + 719468;
    let era = (if z >= 0 { z } else { z - 146096 }) / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    digits(out, yoe + era * 400 + (if m <= 2 { 1 } else { 0 }), 4);
    out.push('-');
    digits(out, m, 2);
    out.push('-');
    digits(out, doy - (153 * mp + 2) / 5 + 1, 2);
    out.push('T');
    digits(out, t / 3600000, 2);
    out.push(':');
    digits(out, t / MINUTE % 60, 2);
    out.push(':');
    digits(out, t / 1000 % 60, 2);
    out.push('.');
    digits(out, t % 1000, 3);
    out.push('Z');
}

fn number_at(s: const u8[:], at: i64, n: i64) -> i64 {
    var v = 0;
    for i in at..at + n {
        guard s[i] >= '0' && s[i] <= '9' else { return -1; }
        v = v * 10 + (s[i] - '0');
    }
    return v;
}

// "YYYY-MM-DDTHH:MM:SS.sssZ", or without the milliseconds, as ms since the
// epoch (days_from_civil); false for anything else.
fn parse_iso(s: const u8[:]) -> i64, bool {
    guard (s.len == 24 || s.len == 20) && s[4] == '-' && s[7] == '-' && s[10] == 'T' && s[13] == ':' &&
          s[16] == ':' && s[s.len - 1] == 'Z' else { return 0, false; }
    let y = number_at(s, 0, 4);
    let m = number_at(s, 5, 2);
    let d = number_at(s, 8, 2);
    let h = number_at(s, 11, 2);
    let mi = number_at(s, 14, 2);
    let sec = number_at(s, 17, 2);
    let ms = if s.len == 24 && s[19] == '.' { number_at(s, 20, 3) } else if s.len == 20 { 0 } else { -1 };
    guard y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31 && h >= 0 && h < 24 && mi >= 0 && mi < 60 &&
          sec >= 0 && sec < 60 && ms >= 0 else { return 0, false; }
    return days_from(y, m, d) * DAY + ((h * 60 + mi) * 60 + sec) * 1000 + ms, true;
}

// "YYYY-MM-DD" as ms since the epoch at its midnight in UTC.
fn parse_day(s: const u8[:]) -> i64, bool {
    guard s.len == 10 && s[4] == '-' && s[7] == '-' else { return 0, false; }
    let y = number_at(s, 0, 4);
    let m = number_at(s, 5, 2);
    let d = number_at(s, 8, 2);
    guard y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31 else { return 0, false; }
    return days_from(y, m, d) * DAY, true;
}

// Howard Hinnant's days_from_civil.
fn days_from(y: i64, m: i64, d: i64) -> i64 {
    let yy = if m <= 2 { y - 1 } else { y };
    let era = (if yy >= 0 { yy } else { yy - 399 }) / 400;
    let yoe = yy - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    return era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468;
}

fn is_lower_hex(c: u8) -> bool { c >= '0' && c <= '9' || c >= 'a' && c <= 'f' }

// snowtime's Uuidv7: 8-4-4-4-12 lower-case hex digits, version 7, variant 8
// to b.
fn is_uuid7(s: const u8[:]) -> bool {
    guard s.len == 36 && s[14] == '7' && (s[19] == '8' || s[19] == '9' || s[19] == 'a' || s[19] == 'b')
        else { return false; }
    for c, i in s {
        if i == 8 || i == 13 || i == 18 || i == 23 { if c != '-' { return false; } }
        else if !is_lower_hex(c) { return false; }
    }
    return true;
}

// The time a uuidv7 was made, from its first 48 bits.
fn uuid_ms(s: const u8[:]) -> i64 {
    var v = 0;
    for c, i in s[..13] {
        if i == 8 { continue; }
        v = v * 16 + (if c <= '9' { c - '0' } else { c - 'a' + 10 });
    }
    return v;
}

// snowtime's ticket key: [A-Z][A-Z0-9]{1,9}-[1-9][0-9]{0,6}.
fn is_ticket(s: const u8[:]) -> bool {
    let dash = position(s, '-');
    guard dash >= 2 && dash <= 10 && s[0] >= 'A' && s[0] <= 'Z' else { return false; }
    for c in s[1..dash] { if !(c >= 'A' && c <= 'Z' || c >= '0' && c <= '9') { return false; } }
    let n = s[dash + 1..];
    guard n.len >= 1 && n.len <= 7 && n[0] >= '1' && n[0] <= '9' else { return false; }
    for c in n { if c < '0' || c > '9' { return false; } }
    return true;
}

fn now_ms() -> i64 { time_ns() / 1000000 }

fn iso_or_null(out: u8[>..]&, ms: i64) {
    if ms < 0 { out.append("null"); return; }
    out.push('"');
    format_iso(out, ms);
    out.push('"');
}

fn string_or_null(out: u8[>..]&, s: const u8[:]) {
    if s.len == 0 { out.append("null"); } else { json::format_string(out, s); }
}

// A string member, or null as empty.
fn read_nullable(r: json::Reader&, scratch: u8[>..]&, cap: i64) -> const u8[:] {
    if json::peek(r) == 'n' { json::skip(r); return ""; }
    return string_of(r, scratch, cap);
}

fn read_time(r: json::Reader&, scratch: u8[>..]&) -> i64 {
    if json::peek(r) == 'n' { json::skip(r); return -1; }
    let v, ok = parse_iso(string_of(r, scratch, 24));
    guard ok else { abort("a time that isn't toISOString's"); }
    return v;
}

fn read_flag(r: json::Reader&) -> i64 {
    if json::peek(r) == 'n' { json::skip(r); return -1; }
    return if json::read_bool(r) { 1 } else { 0 };
}

fn org_index(id: const u8[:]) -> i64 {
    for o, i in orgs { if o.id == id { return i; } }
    return -1;
}

fn project_index(id: const u8[:], org: i64) -> i64 {
    let o = orgs[org];
    for i in o.first..o.first + o.count { if projects[i].id == id { return i; } }
    return -1;
}

fn person_index(id: const u8[:]) -> i64 {
    let k = lower_bound(by_person_id) { compare(people[it].id, id) < 0 };
    return if k < by_person_id.len && people[by_person_id[k]].id == id { by_person_id[k] } else { -1 };
}

fn entry_index(id: const u8[:]) -> i64 {
    let k = lower_bound(by_entry_id) { compare(entries[it].id, id) < 0 };
    return if k < by_entry_id.len && entries[by_entry_id[k]].id == id { by_entry_id[k] } else { -1 };
}

fn load_orgs(dir: const u8[:]) {
    var text: u8[>..] = [];
    load(dir, "snow-orgs.json", text);
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_element(r) {
        var o = Org { .. };
        json::each_member(r) { key =>
            if key == "id" { o.id.append(string_of(r, scratch, o.id.cap)); }
            else if key == "name" { o.name.append(string_of(r, scratch, o.name.cap)); }
            else if key == "slug" { o.slug.append(string_of(r, scratch, o.slug.cap)); }
            else if key == "issueLinks" { o.links.append(read_nullable(r, scratch, o.links.cap)); }
            else if key == "projects" {
                o.first = projects.len;
                json::each_element(r) {
                    var p = Project { archived: -1, .. };
                    json::each_member(r) { k =>
                        if k == "id" { p.id.append(string_of(r, scratch, p.id.cap)); }
                        else if k == "name" { p.name.append(string_of(r, scratch, p.name.cap)); }
                        else if k == "color" { p.color.append(read_nullable(r, scratch, p.color.cap)); }
                        else if k == "archivedAt" { p.archived = read_time(r, scratch); }
                        else if k == "hasEntries" { p.has_entries = json::read_bool(r); }
                        else if k == "teamIds" {
                            json::each_element(r) {
                                guard p.teams.len < p.teams.cap else { abort("more than 2 teams"); }
                                let t .= p.teams.push("");
                                t.append(string_of(r, scratch, t.cap));
                            };
                        } else { json::skip(r); }
                    };
                    projects.push(p);
                };
                o.count = projects.len - o.first;
            } else { json::skip(r); }
        };
        orgs.push(o);
    };
    guard json::finish(r) else { abort(json::message(r)); }
}

fn load_settings(r: json::Reader&, scratch: u8[>..]&, s: Settings&) {
    json::each_member(r) { k =>
        if k == "timeZone" { s.time_zone.append(string_of(r, scratch, s.time_zone.cap)); }
        else if k == "weekStart" { s.week_start.append(string_of(r, scratch, s.week_start.cap)); }
        else if k == "locale" { s.locale.append(string_of(r, scratch, s.locale.cap)); }
        else if k == "theme" { s.theme.append(string_of(r, scratch, s.theme.cap)); }
        else if k == "timerLayout" { s.timer_layout.append(string_of(r, scratch, s.timer_layout.cap)); }
        else if k == "showSummary" { s.show_summary = json::read_bool(r); }
        else if k == "compactRows" { s.compact_rows = json::read_bool(r); }
        else if k == "wideTimer" { s.wide_timer = json::read_bool(r); }
        else if k == "timerView" { s.timer_view.append(string_of(r, scratch, s.timer_view.cap)); }
        else if k == "calendarWeekend" { s.calendar_weekend = json::read_bool(r); }
        else if k == "appIcon" { s.app_icon.append(string_of(r, scratch, s.app_icon.cap)); }
        else if k == "sceneCollection" { s.scene_collection.append(string_of(r, scratch, s.scene_collection.cap)); }
        else if k == "scenePin" { s.scene_pin.append(read_nullable(r, scratch, s.scene_pin.cap)); }
        else if k == "sceneBackground" { s.scene_background = json::read_bool(r); }
        else if k == "sceneStrength" { s.scene_strength.append(string_of(r, scratch, s.scene_strength.cap)); }
        else if k == "surfaces" { s.surfaces.append(string_of(r, scratch, s.surfaces.cap)); }
        else if k == "sceneWeather" { s.scene_weather = json::read_bool(r); }
        else if k == "sceneIntro" { s.scene_intro = json::read_bool(r); }
        else if k == "sceneTagline" { s.scene_tagline = json::read_bool(r); }
        else if k == "durationFormat" { s.duration_format.append(string_of(r, scratch, s.duration_format.cap)); }
        else if k == "dateFormat" { s.date_format.append(string_of(r, scratch, s.date_format.cap)); }
        else if k == "timeFormat" { s.time_format.append(string_of(r, scratch, s.time_format.cap)); }
        else if k == "copyDurationPattern" { s.copy_pattern.append(string_of(r, scratch, s.copy_pattern.cap)); }
        else if k == "copyDurationControl" { s.copy_control.append(string_of(r, scratch, s.copy_control.cap)); }
        else if k == "country" { s.country.append(read_nullable(r, scratch, s.country.cap)); }
        else { json::skip(r); }
    };
}

fn load_fill(r: json::Reader&, scratch: u8[>..]&, f: Fill&) {
    json::each_member(r) { k =>
        if k == "date" { f.date.append(string_of(r, scratch, f.date.cap)); }
        else if k == "timerStartedAt" {
            f.timer_started = if json::peek(r) == 'n' { json::skip(r); -1 } else { json::read_int(r) };
        } else if k == "today" { f.today.append(string_of(r, scratch, f.today.cap)); }
        else if k == "lastWorkingDay" {
            if json::peek(r) == 'n' { json::skip(r); }
            else {
                json::each_member(r) { kk =>
                    if kk == "date" { f.last_day.append(string_of(r, scratch, f.last_day.cap)); }
                    else if kk == "filled" { f.last_day_filled = json::read_bool(r); }
                    else { json::skip(r); }
                };
            }
        } else if k == "lastWeek" { f.last_week = read_flag(r); }
        else if k == "lastMonth" { f.last_month = read_flag(r); }
        else if k == "caughtUp" { f.caught_up = json::read_bool(r); }
        else if k == "emptyDays" { f.empty_days = json::read_int(r); }
        else if k == "streak" { f.streak = json::read_int(r); }
        else { json::skip(r); }
    };
}

fn load_people(dir: const u8[:]) {
    var text: u8[>..] = [];
    load(dir, "snow-users.json", text);
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_element(r) {
        var p = Person { active: -1, running: -1, .. };
        json::each_member(r) { key =>
            if key == "id" { p.id.append(string_of(r, scratch, p.id.cap)); }
            else if key == "name" { p.name.append(string_of(r, scratch, p.name.cap)); }
            else if key == "email" { p.email.append(string_of(r, scratch, p.email.cap)); }
            else if key == "image" { p.image.append(read_nullable(r, scratch, p.image.cap)); }
            else if key == "token" { p.token.append(string_of(r, scratch, p.token.cap)); }
            else if key == "signedInAt" { p.signed_in = read_time(r, scratch); }
            else if key == "organizations" {
                json::each_element(r) {
                    guard p.orgs.len < p.orgs.cap else { abort("more than 6 organizations"); }
                    let m .= p.orgs.push(Member { org: -1, .. });
                    json::each_member(r) { k =>
                        if k == "id" { m.org = org_index(string_of(r, scratch, 36)); }
                        else if k == "role" { m.role.append(string_of(r, scratch, m.role.cap)); }
                        else { json::skip(r); }
                    };
                    guard m.org >= 0 else { abort("a member of an organization snow-orgs.json lacks"); }
                };
            } else if key == "activeOrganizationId" { p.active = org_index(string_of(r, scratch, 36)); }
            else if key == "teamIds" {
                json::each_element(r) {
                    guard p.teams.len < p.teams.cap else { abort("more than 2 teams"); }
                    let t .= p.teams.push("");
                    t.append(string_of(r, scratch, t.cap));
                };
            } else if key == "settings" { load_settings(r, scratch, p.settings); }
            else if key == "fill" { load_fill(r, scratch, p.fill); }
            else { json::skip(r); }
        };
        guard p.active >= 0 && p.token.len == 64 else { abort("a user without an organization or a token"); }
        people.push(p);
    };
    guard json::finish(r) else { abort(json::message(r)); }
    for i in people.len { by_token.push(i); by_person_id.push(i); }
    sort(by_token) { a, b => compare(people[a].token, people[b].token) < 0 };
    sort(by_person_id) { a, b => compare(people[a].id, people[b].id) < 0 };
}

fn load_entries(dir: const u8[:]) {
    var text: u8[>..] = [];
    load(dir, "snow-entries.json", text);
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_element(r) {
        var e = Entry { user: -1, org: -1, project: -1, .. };
        var project: u8[..36] = "";
        json::each_member(r) { key =>
            if key == "id" { e.id.append(string_of(r, scratch, e.id.cap)); }
            else if key == "organizationId" { e.org = org_index(string_of(r, scratch, 36)); }
            else if key == "userId" {
                let id = string_of(r, scratch, 36);
                // The file has each user's entries together.
                e.user = if entries.len > 0 && people[last(entries).user].id == id { last(entries).user }
                         else { person_index(id) };
            } else if key == "projectId" { project.append(read_nullable(r, scratch, project.cap)); }
            else if key == "description" { e.description.append(string_of(r, scratch, e.description.cap)); }
            else if key == "ticket" { e.ticket.append(read_nullable(r, scratch, e.ticket.cap)); }
            else if key == "startedAt" { e.started = read_time(r, scratch); }
            else if key == "stoppedAt" { e.stopped = read_time(r, scratch); }
            else { json::skip(r); }
        };
        guard e.user >= 0 && e.org >= 0 else { abort("an entry of a user or organization the files lack"); }
        if project.len > 0 {
            e.project = project_index(project, e.org);
            guard e.project >= 0 else { abort("an entry of a project snow-orgs.json lacks"); }
        }
        let p .= people[e.user];
        if p.count == 0 { p.first = entries.len; }
        guard p.first + p.count == entries.len else { abort("snow-entries.json doesn't have each user's entries together"); }
        guard p.count == 0 || last(entries).started < e.started else { abort("a user's entries out of order"); }
        p.count++;
        if e.stopped < 0 { p.running = entries.len; }
        entries.push(e);
    };
    guard json::finish(r) else { abort(json::message(r)); }
    for i in entries.len { by_entry_id.push(i); }
    sort(by_entry_id) { a, b => compare(entries[a].id, entries[b].id) < 0 };
}

fn session_open(out: u8[>..]&, p: Person) {
    out.append("{\"user\":{\"id\":");
    json::format_string(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.append(",\"email\":");
    json::format_string(out, p.email);
    out.append(",\"image\":");
    string_or_null(out, p.image);
    out.append("},\"signedInAt\":");
    iso_or_null(out, p.signed_in);
    out.append(",\"organizations\":[");
    for m, i in p.orgs {
        let o = orgs[m.org];
        if i > 0 { out.push(','); }
        out.append("{\"id\":");
        json::format_string(out, o.id);
        out.append(",\"name\":");
        json::format_string(out, o.name);
        out.append(",\"slug\":");
        json::format_string(out, o.slug);
        out.append(",\"issueLinks\":");
        string_or_null(out, o.links);
        out.append(",\"role\":");
        json::format_string(out, m.role);
        out.push('}');
    }
    out.append("],\"activeOrganizationId\":");
    json::format_string(out, orgs[p.active].id);
    let s = p.settings;
    out.append(",\"settings\":{\"timeZone\":");
    json::format_string(out, s.time_zone);
    out.append(",\"weekStart\":");
    json::format_string(out, s.week_start);
    out.append(",\"locale\":");
    json::format_string(out, s.locale);
    out.append(",\"theme\":");
    json::format_string(out, s.theme);
    out.append(",\"timerLayout\":");
    json::format_string(out, s.timer_layout);
    out.append(",\"showSummary\":");
    json::format_bool(out, s.show_summary);
    out.append(",\"compactRows\":");
    json::format_bool(out, s.compact_rows);
    out.append(",\"wideTimer\":");
    json::format_bool(out, s.wide_timer);
    out.append(",\"timerView\":");
    json::format_string(out, s.timer_view);
    out.append(",\"calendarWeekend\":");
    json::format_bool(out, s.calendar_weekend);
    out.append(",\"appIcon\":");
    json::format_string(out, s.app_icon);
    out.append(",\"sceneCollection\":");
    json::format_string(out, s.scene_collection);
    out.append(",\"scenePin\":");
    string_or_null(out, s.scene_pin);
    out.append(",\"sceneBackground\":");
    json::format_bool(out, s.scene_background);
    out.append(",\"sceneStrength\":");
    json::format_string(out, s.scene_strength);
    out.append(",\"surfaces\":");
    json::format_string(out, s.surfaces);
    out.append(",\"sceneWeather\":");
    json::format_bool(out, s.scene_weather);
    out.append(",\"sceneIntro\":");
    json::format_bool(out, s.scene_intro);
    out.append(",\"sceneTagline\":");
    json::format_bool(out, s.scene_tagline);
    out.append(",\"durationFormat\":");
    json::format_string(out, s.duration_format);
    out.append(",\"dateFormat\":");
    json::format_string(out, s.date_format);
    out.append(",\"timeFormat\":");
    json::format_string(out, s.time_format);
    out.append(",\"copyDurationPattern\":");
    json::format_string(out, s.copy_pattern);
    out.append(",\"copyDurationControl\":");
    json::format_string(out, s.copy_control);
    out.append(",\"country\":");
    string_or_null(out, s.country);
    let f = p.fill;
    out.append("},\"fill\":{\"date\":");
    json::format_string(out, f.date);
    out.append(",\"timerStartedAt\":");
    if f.timer_started >= 0 { format(out, f.timer_started); } else { out.append("null"); }
    out.append(",\"today\":");
    json::format_string(out, f.today);
    out.append(",\"lastWorkingDay\":");
    if f.last_day.len == 0 { out.append("null"); }
    else {
        out.append("{\"date\":");
        json::format_string(out, f.last_day);
        out.append(",\"filled\":");
        json::format_bool(out, f.last_day_filled);
        out.push('}');
    }
    out.append(",\"lastWeek\":");
    out.append(if f.last_week < 0 { "null" } else if f.last_week > 0 { "true" } else { "false" });
    out.append(",\"lastMonth\":");
    out.append(if f.last_month < 0 { "null" } else if f.last_month > 0 { "true" } else { "false" });
    out.append(",\"caughtUp\":");
    json::format_bool(out, f.caught_up);
    out.append(",\"emptyDays\":");
    format(out, f.empty_days);
    out.append(",\"streak\":");
    format(out, f.streak);
    out.append("},\"invitationId\":null,\"appUrl\":\"");
    out.append(app_url());
    out.append("\"}");
}

// An entry up to its description's value, and from the member after it, so
// that a PATCH writes another description between the two.
fn entry_head(out: u8[>..]&, e: Entry) {
    out.append("{\"id\":");
    json::format_string(out, e.id);
    out.append(",\"organizationId\":");
    json::format_string(out, orgs[e.org].id);
    out.append(",\"userId\":");
    json::format_string(out, people[e.user].id);
    out.append(",\"projectId\":");
    string_or_null(out, if e.project >= 0 { projects[e.project].id } else { "" });
    out.append(",\"description\":");
}

// The members after the description, without stoppedAt's value and the
// closing brace.
fn entry_tail_open(out: u8[>..]&, e: Entry) {
    out.append(",\"ticket\":");
    string_or_null(out, e.ticket);
    out.append(",\"startedAt\":");
    iso_or_null(out, e.started);
    out.append(",\"stoppedAt\":");
}

fn entry_full(out: u8[>..]&, e: Entry, description: const u8[:], stopped: i64) {
    entry_head(out, e);
    json::format_string(out, description);
    entry_tail_open(out, e);
    iso_or_null(out, stopped);
    out.push('}');
}

fn project_full(out: u8[>..]&, p: Project) {
    out.append("{\"id\":");
    json::format_string(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.append(",\"color\":");
    string_or_null(out, p.color);
    out.append(",\"archivedAt\":");
    iso_or_null(out, p.archived);
    out.append(if p.has_entries { ",\"hasEntries\":true,\"teamIds\":[" } else { ",\"hasEntries\":false,\"teamIds\":[" });
    for t, i in p.teams {
        if i > 0 { out.push(','); }
        json::format_string(out, t);
    }
    out.append("]}");
}

// GET /timer's answer for a running entry: the entry and its project.
fn timer_full(out: u8[>..]&, e: Entry) {
    entry_head(out, e);
    json::format_string(out, e.description);
    entry_tail_open(out, e);
    out.append("null,\"project\":");
    if e.project < 0 { out.append("null}"); return; }
    let p = projects[e.project];
    out.append("{\"id\":");
    json::format_string(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.append(",\"color\":");
    string_or_null(out, p.color);
    out.append("}}");
}

fn prebuild_snow() {
    for p in people {
        session_at.push(session_json.len);
        session_open(session_json, p);
        timer_at.push(timer_json.len);
        if p.running >= 0 { timer_full(timer_json, entries[p.running]); } else { timer_json.append("null"); }
    }
    session_at.push(session_json.len);
    timer_at.push(timer_json.len);
    for p in projects {
        project_at.push(project_json.len);
        project_full(project_json, p);
    }
    project_at.push(project_json.len);
    for e in entries {
        entry_at.push(entry_json.len);
        entry_head(entry_json, e);
        entry_desc.push(entry_json.len);
        json::format_string(entry_json, e.description);
        entry_tail.push(entry_json.len);
        entry_tail_open(entry_json, e);
        iso_or_null(entry_json, e.stopped);
        entry_json.push('}');
    }
    entry_at.push(entry_json.len);
}

fn snow_entry(out: u8[>..]&, i: i64) {
    if template { out.append(entry_json[entry_at[i]..entry_at[i + 1]]); }
    else { let e = entries[i]; entry_full(out, e, e.description, e.stopped); }
}

// Entry i with another description.
fn snow_entry_as(out: u8[>..]&, i: i64, description: const u8[:]) {
    if template {
        out.append(entry_json[entry_at[i]..entry_desc[i]]);
        json::format_string(out, description);
        out.append(entry_json[entry_tail[i]..entry_at[i + 1]]);
    } else {
        let e = entries[i];
        entry_full(out, e, description, e.stopped);
    }
}

// Running entry i stopped at ms, as stopRunning stops it: after it started,
// and at most a day after.
fn snow_stopped(out: u8[>..]&, i: i64, now: i64) {
    let e = entries[i];
    let at = min(max(now, e.started + 1), e.started + DAY);
    if template {
        // A running entry's JSON ends in "null}".
        out.append(entry_json[entry_at[i]..entry_at[i + 1] - 5]);
        iso_or_null(out, at);
        out.push('}');
    } else {
        entry_full(out, e, e.description, at);
    }
}

// The person the session cookie names, or -1.
fn person_of(cx) -> i64 {
    let v, has = rest::cookie(cx, session_cookie());
    guard has && v.len > 65 && v[64] == '.' else { return -1; }
    let token = v[..64];
    let k = lower_bound(by_token) { compare(people[it].token, token) < 0 };
    return if k < by_token.len && people[by_token[k]].token == token { by_token[k] } else { -1 };
}

// The person's membership of the organization the path names, or -1.
fn membership(p: Person, id: const u8[:]) -> i64 {
    for m, i in p.orgs { if orgs[m.org].id == id { return i; } }
    return -1;
}

fn is_admin(m: Member) -> bool { m.role == "owner" || m.role == "admin" }

// listProjects's visibility: an admin sees every project, a member those
// with no team and those of a team of theirs.
fn sees(p: Person, m: Member, j: Project) -> bool {
    if is_admin(m) || j.teams.len == 0 { return true; }
    if m.org != p.active { return false; }
    for t in j.teams { if contains(p.teams, t) { return true; } }
    return false;
}

// Tier B's per-request state. Its error_body writes snowtime's two shapes:
// {"error":{"message"}} for the codes below, and {"error":{"code","key"}},
// the code named by the status, for the rest.
struct Snow { unused: bool = false }

fn rest::error_body(body: u8[>..]&, st: const Snow&, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
    let message = if code == "no_such_call" { "No such call." }
                  else if code == "cross_origin" { "Cross-origin request refused." }
                  else if code == "invalid_input" { "Invalid input." }
                  else if code == "not_json" { "The body is not JSON." }
                  else { "" };
    if message.len > 0 {
        format(body, "{\"error\":{\"message\":\"", message, "\"}}");
        return;
    }
    let name = if status == 401 { "UNAUTHENTICATED" } else if status == 403 { "FORBIDDEN" }
               else if status == 404 { "NOT_FOUND" } else if status == 409 { "CONFLICT" } else { "BAD_REQUEST" };
    format(body, "{\"error\":{\"code\":\"", name, "\",\"key\":\"", code, "\"}}");
}

fn invalid(cx) { rest::fail(cx, 400, "invalid_input"); }

// GET .../entries: the entries of userId, or of the caller, that overlap
// [from, to), newest first, as listEntries selects them.
fn list_entries(cx, p: Person, m: Member, buf: u8[>..]&) {
    let fs, has_from = rest::query(cx, "from");
    let from, from_ok = parse_iso(fs);
    let ts, has_to = rest::query(cx, "to");
    let to, to_ok = parse_iso(ts);
    guard has_from && from_ok && has_to && to_ok && to > from && to - from <= 93 * DAY else { invalid(cx); }
    var who = person_index(p.id);
    let uid, has_user = rest::query(cx, "userId");
    if has_user {
        guard is_uuid7(uid) else { invalid(cx); }
        if uid != p.id {
            guard is_admin(m) else { rest::fail(cx, 403, "entries_forbidden"); }
            who = person_index(uid);
        }
    }
    buf.push('[');
    if who >= 0 && people[who].active == m.org {
        let u = people[who];
        let mine = entries[u.first..u.first + u.count];
        var i = lower_bound(mine) { it.started < to } - 1;
        var n = 0;
        while i >= 0 && mine[i].started > from - DAY {
            if mine[i].stopped < 0 || mine[i].stopped > from {
                if n > 0 { buf.push(','); }
                snow_entry(buf, u.first + i);
                n++;
            }
            i--;
        }
    }
    buf.push(']');
    rest::json_bytes(cx, 200, buf);
}

fn list_projects(cx, p: Person, m: Member, buf: u8[>..]&) {
    let v, has = rest::query(cx, "includeArchived");
    guard !has || v == "true" || v == "false" else { invalid(cx); }
    let archived = has && v == "true";
    let o = orgs[m.org];
    buf.push('[');
    var n = 0;
    for i in o.first..o.first + o.count {
        let j = projects[i];
        if (archived || j.archived < 0) && sees(p, m, j) {
            if n > 0 { buf.push(','); }
            if template { buf.append(project_json[project_at[i]..project_at[i + 1]]); } else { project_full(buf, j); }
            n++;
        }
    }
    buf.push(']');
    rest::json_bytes(cx, 200, buf);
}

// Whether body is one JSON value.
fn is_json(body: const u8[:]) -> bool {
    var r = json::reader(body);
    json::skip(r);
    return json::finish(r);
}

// The trimmed string member, at most 500 bytes: false for another type or a
// longer one.
fn description_of(r: json::Reader&, scratch: u8[>..]&) -> const u8[:], bool {
    guard json::peek(r) == '"' else { json::skip(r); return "", false; }
    let s = trim(json::read_string(r, scratch));
    return s, s.len <= 500;
}

fn patch_entry(cx, id: const u8[:], p: Person, m: Member, buf: u8[>..]&) {
    guard is_uuid7(id) else { invalid(cx); }
    let body = rest::body(cx);
    guard is_json(body) else { rest::fail(cx, 400, "not_json"); }
    var scratch: u8[>..] = [];
    var r = json::reader(body);
    var description: u8[>..] = [];
    var has = false;
    var ok = json::peek(r) == '{';
    if ok {
        json::each_member(r) { key =>
            if key == "description" {
                let d, fits = description_of(r, scratch);
                description.append(d);
                ok = ok && fits;
                has = true;
            } else { json::skip(r); }
        };
    }
    guard ok && json::finish(r) else { invalid(cx); }
    let i = entry_index(id);
    guard i >= 0 && entries[i].org == m.org else { rest::fail(cx, 404, "entry_not_found"); }
    guard people[entries[i].user].id == p.id || is_admin(m) else { rest::fail(cx, 403, "entry_forbidden"); }
    if has { snow_entry_as(buf, i, description); } else { snow_entry(buf, i); }
    rest::json_bytes(cx, 200, buf);
}

// POST .../timer/start: the new entry, started now, and the timer it
// stopped, the caller's running one, or null.
fn start_timer(cx, u: i64, m: Member, buf: u8[>..]&) {
    let body = rest::body(cx);
    guard is_json(body) else { rest::fail(cx, 400, "not_json"); }
    var scratch: u8[>..] = [];
    var r = json::reader(body);
    var id: u8[..36] = "";
    var description: u8[>..] = [];
    var ticket: u8[..18] = "";
    var project: u8[..36] = "";
    var ok = json::peek(r) == '{';
    if ok {
        json::each_member(r) { key =>
            let c = json::peek(r);
            if key == "description" {
                let d, fits = description_of(r, scratch);
                description.append(d);
                ok = ok && fits;
            } else if c == 'n' && (key == "ticket" || key == "projectId") {
                json::skip(r);
            } else if key == "id" || key == "ticket" || key == "projectId" {
                let s = if c == '"' { json::read_string(r, scratch) } else { "" };
                if s.len == 0 { ok = false; json::skip(r); }
                else if key == "id" && s.len <= id.cap { id.append(s); }
                else if key == "ticket" && s.len <= ticket.cap && is_ticket(s) { ticket.append(s); }
                else if key == "projectId" && is_uuid7(s) { project.append(s); }
                else { ok = false; }
            } else { json::skip(r); }
        };
    }
    guard ok && json::finish(r) && is_uuid7(id) else { invalid(cx); }
    let p = people[u];
    if project.len > 0 {
        let j = project_index(project, m.org);
        guard j >= 0 && sees(p, m, projects[j]) else { rest::fail(cx, 404, "project_not_found"); }
        guard projects[j].archived < 0 else { rest::fail(cx, 409, "project_archived"); }
    }
    guard entry_index(id) < 0 else { rest::fail(cx, 409, "entry_id_taken"); }
    let now = now_ms();
    buf.append("{\"started\":{\"id\":");
    json::format_string(buf, id);
    buf.append(",\"organizationId\":");
    json::format_string(buf, orgs[m.org].id);
    buf.append(",\"userId\":");
    json::format_string(buf, p.id);
    buf.append(",\"projectId\":");
    string_or_null(buf, project);
    buf.append(",\"description\":");
    json::format_string(buf, description);
    buf.append(",\"ticket\":");
    string_or_null(buf, ticket);
    buf.append(",\"startedAt\":");
    iso_or_null(buf, now);
    buf.append(",\"stoppedAt\":null},\"stopped\":");
    if p.running >= 0 { snow_stopped(buf, p.running, now); } else { buf.append("null"); }
    buf.push('}');
    rest::json_bytes(cx, 200, buf);
}

// POST /timer/stop: the caller's running entry, stopped now. An id the
// dataset doesn't have is taken for a timer started with it, as timer start
// answered it: a uuidv7 made in the last day.
fn stop_timer(cx, u: i64, buf: u8[>..]&) {
    let body = rest::body(cx);
    guard is_json(body) else { rest::fail(cx, 400, "not_json"); }
    var scratch: u8[>..] = [];
    var r = json::reader(body);
    var id: u8[..36] = "";
    var ok = json::peek(r) == '{';
    if ok {
        json::each_member(r) { key =>
            if key == "id" && json::peek(r) == '"' {
                let s = json::read_string(r, scratch);
                if s.len <= id.cap { id.append(s); } else { ok = false; }
            } else { json::skip(r); }
        };
    }
    guard ok && json::finish(r) && is_uuid7(id) else { invalid(cx); }
    let p = people[u];
    let now = now_ms();
    if p.running >= 0 && entries[p.running].id == id {
        snow_stopped(buf, p.running, now);
    } else {
        let started = uuid_ms(id);
        guard started > now - DAY && started <= now + MINUTE && entry_index(id) < 0
            else { rest::fail(cx, 404, "timer_not_running"); }
        buf.append("{\"id\":");
        json::format_string(buf, id);
        buf.append(",\"organizationId\":");
        json::format_string(buf, orgs[p.active].id);
        buf.append(",\"userId\":");
        json::format_string(buf, p.id);
        buf.append(",\"projectId\":null,\"description\":\"\",\"ticket\":null,\"startedAt\":");
        iso_or_null(buf, started);
        buf.append(",\"stoppedAt\":");
        iso_or_null(buf, min(max(now, started + 1), started + DAY));
        buf.push('}');
    }
    rest::json_bytes(cx, 200, buf);
}

// The caller, whom the session cookie names, or 401.
fn signed_in(cx) -> i64 {
    let u = person_of(cx);
    guard u >= 0 else { rest::fail(cx, 401, "sign_in_required"); }
    return u;
}

// The caller's membership of the organization the path names, or 403.
fn member(cx, r: const http::Router&, p: Person) -> Member {
    let k = membership(p, rest::param(cx, r, "org"));
    guard k >= 0 else { rest::fail(cx, 403, "not_organization_member"); }
    return p.orgs[k];
}

// A write's guard: Origin must be the app's, as snowtime's CSRF check has it.
fn same_origin(cx) {
    let origin, has = rest::header(cx, "origin");
    guard has && origin == app_url() else { rest::fail(cx, 403, "cross_origin"); }
}

// Tier B's routes, each checking in snowtime's order: a write from another
// origin, the sign-in, and the organization's membership. GET /session
// answers null to no one. An unknown call is 404 whatever its method, as
// snowtime's Hono app answers it, not 405.
fn snow(cx, buf: u8[>..]&) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/api/v1/session") {
        let u = person_of(cx);
        if u < 0 { buf.append("null"); }
        else if template { buf.append(session_json[session_at[u]..session_at[u + 1]]); }
        else { session_open(buf, people[u]); }
        rest::json_bytes(cx, 200, buf);
    } else if http::on(r, "GET", "/api/v1/timer") {
        let u = signed_in(cx);
        let p = people[u];
        if template { buf.append(timer_json[timer_at[u]..timer_at[u + 1]]); }
        else if p.running >= 0 { timer_full(buf, entries[p.running]); }
        else { buf.append("null"); }
        rest::json_bytes(cx, 200, buf);
    } else if http::on(r, "POST", "/api/v1/timer/stop") {
        same_origin(cx);
        stop_timer(cx, signed_in(cx), buf);
    } else if http::on(r, "GET", "/api/v1/organizations/:org/entries") {
        let p = people[signed_in(cx)];
        list_entries(cx, p, member(cx, r, p), buf);
    } else if http::on(r, "GET", "/api/v1/organizations/:org/projects") {
        let p = people[signed_in(cx)];
        list_projects(cx, p, member(cx, r, p), buf);
    } else if http::on(r, "PATCH", "/api/v1/organizations/:org/entries/:id") {
        same_origin(cx);
        let p = people[signed_in(cx)];
        patch_entry(cx, rest::param(cx, r, "id"), p, member(cx, r, p), buf);
    } else if http::on(r, "POST", "/api/v1/organizations/:org/timer/start") {
        same_origin(cx);
        let u = signed_in(cx);
        start_timer(cx, u, member(cx, r, people[u]), buf);
    } else {
        rest::fail(cx, 404, "no_such_call");
    }
}

// Tier C, a clinic's schedule and records, under /api/v2. A request needs a
// bearer token shaped as a JWT, which isn't verified. Ids are 1, 2, ... in
// each file, and the schedule's days are UTC's.

struct Staffer { name: u8[..32], title: u8[..32] }

struct Service { code: u8[..8], name: u8[..32], minutes: i64, price: i64 }

struct Client {
    name: u8[..48],
    code: u8[..8],
    born: u8[..10],
    phone: u8[..16],
    email: u8[..40],
    street: u8[..32],
    city: u8[..16],
    postcode: u8[..8],
    channel: u8[..5],
    language: u8[..2],
    flags: u8[..12][..3],
    contact: u8[..48],
    contact_phone: u8[..16],
    relation: u8[..8],
    sms: bool,
    mail: bool,
    research: bool,
    created: i64,
    updated: i64,
    first: i64,             // the client's completed visits, newest first: past[first..first + count]
    count: i64,
}

struct Line { id: i64, service: i64 }

struct Note { id: i64, visit: i64, kind: i64, author: i64, at: i64, text_at: i64, text_len: i64 }

struct Visit {
    case_id: i64,
    client: i64,
    staff: i64,
    status: u8[..10],
    kind: u8[..12],
    priority: u8[..8],
    start: i64,
    end: i64,
    lines: Line[..3],
    codes: u8[..8][..3],
    first_note: i64,        // notes[first_note..first_note + notes], by kind
    notes: i64,
    case_first: i64,        // the case's visits, visits[case_first..case_first + case_count]
    case_count: i64,
}

struct Reminder { channel: u8[..5], kind: u8[..12], status: u8[..9], at: i64 }

struct Booking {
    start: i64,
    end: i64,
    client: i64,
    staff: i64,
    visit: i64,
    lines: Line[..3],
    reminders: Reminder[..3],
    status: u8[..10],
    source: u8[..8],
    note_at: i64,           // in text, or -1 for null
    note_len: i64,
    created: i64,
    updated: i64,
}

struct Shift { staff: i64, start: i64, end: i64, kind: u8[..8], room: i64, room_name: u8[..16], note: u8[..64] }

var staffers: Staffer[>..];
var services: Service[>..];
var clients: Client[>..];
var visits: Visit[>..];
var notes: Note[>..];
var text: u8[>..];              // the notes' text, and the bookings'
var bookings: Booking[>..];     // by start
var shifts: Shift[>..];         // by start
var past: i64[>..];             // completed visits, by client, newest first
var version_epoch: i64;
// JSON=template's: each booking, shift, and client whole; each visit without
// its closing brace; and each note as caseNotes lists it.
var booking_json: u8[>..];
var booking_at: i64[>..];
var shift_json: u8[>..];
var shift_at: i64[>..];
var client_json: u8[>..];
var client_at: i64[>..];
var visit_json: u8[>..];
var visit_at: i64[>..];
var note_json: u8[>..];
var note_at: i64[>..];

fn note_kind(k: i64) -> const u8[:] {
    return if k == 0 { "intake" } else if k == 1 { "findings" } else if k == 2 { "plan" } else { "internal" };
}

// An id field: n of 1..n as an index, or abort.
fn id_in(r: json::Reader&, n: i64, what: const u8[:]) -> i64 {
    let id = json::read_int(r);
    guard id >= 1 && id <= n else { abort(str("a ", what, " id that isn't one of 1..", n, ": ", id)); }
    return id - 1;
}

// The id of an object such as {"id":3,"name":...}, as an index.
fn ref_in(r: json::Reader&, n: i64, what: const u8[:]) -> i64 {
    var i = -1;
    json::each_member(r) { k => if k == "id" { i = id_in(r, n, what); } else { json::skip(r); } };
    return i;
}

fn service_of(code: const u8[:]) -> i64 {
    for s, i in services { if s.code == code { return i; } }
    abort(str("a service heavy-services.json lacks: ", code));
}

fn load_lines(r: json::Reader&, scratch: u8[>..]&, lines: Line[..3]&) {
    json::each_element(r) {
        guard lines.len < lines.cap else { abort("more than 3 items"); }
        let l .= lines.push(Line { .. });
        json::each_member(r) { k =>
            if k == "id" { l.id = json::read_int(r); }
            else if k == "code" { l.service = service_of(string_of(r, scratch, 8)); }
            else { json::skip(r); }
        };
    };
}

// The reader, for a block: its untyped parameter would be a copy.
struct Cursor { r: json::Reader& }

// A file's records, each read by F, which pushes it.
fn load_each<F>(dir: const u8[:], name: const u8[:]) {
    var text_in: u8[>..] = [];
    load(dir, name, text_in);
    var r = json::reader(text_in);
    json::each_element(r) { F(Cursor { r: r }); };
    guard json::finish(r) else { abort(str(name, ": ", json::message(r))); }
}

fn load_heavy(dir: const u8[:]) {
    var meta: u8[>..] = [];
    load(dir, "heavy-meta.json", meta);
    var m = json::reader(meta);
    json::each_member(m) { k => if k == "versionEpoch" { version_epoch = json::read_int(m); } else { json::skip(m); } };
    guard json::finish(m) && version_epoch > 0 else { abort("heavy-meta.json has no versionEpoch"); }
    var scratch: u8[>..] = [];
    load_each(dir, "heavy-staff.json") { c =>
        let r .= c.r;
        let s .= staffers.push(Staffer { .. });
        json::each_member(r) { k =>
            if k == "name" { s.name.append(string_of(r, scratch, s.name.cap)); }
            else if k == "title" { s.title.append(string_of(r, scratch, s.title.cap)); }
            else if k == "id" { guard json::read_int(r) == staffers.len else { abort("heavy-staff.json's ids aren't 1, 2, ..."); } }
            else { json::skip(r); }
        };
    };
    load_each(dir, "heavy-services.json") { c =>
        let r .= c.r;
        let s .= services.push(Service { .. });
        json::each_member(r) { k =>
            if k == "code" { s.code.append(string_of(r, scratch, s.code.cap)); }
            else if k == "name" { s.name.append(string_of(r, scratch, s.name.cap)); }
            else if k == "minutes" { s.minutes = json::read_int(r); }
            else if k == "price" { s.price = json::read_int(r); }
            else { json::skip(r); }
        };
    };
    load_each(dir, "heavy-clients.json") { c =>
        let r .= c.r;
        let c .= clients.push(Client { .. });
        json::each_member(r) { k =>
            if k == "id" { guard json::read_int(r) == clients.len else { abort("heavy-clients.json's ids aren't 1, 2, ..."); } }
            else if k == "name" { c.name.append(string_of(r, scratch, c.name.cap)); }
            else if k == "code" { c.code.append(string_of(r, scratch, c.code.cap)); }
            else if k == "born" { c.born.append(string_of(r, scratch, c.born.cap)); }
            else if k == "phone" { c.phone.append(string_of(r, scratch, c.phone.cap)); }
            else if k == "email" { c.email.append(string_of(r, scratch, c.email.cap)); }
            else if k == "address" {
                json::each_member(r) { kk =>
                    if kk == "street" { c.street.append(string_of(r, scratch, c.street.cap)); }
                    else if kk == "city" { c.city.append(string_of(r, scratch, c.city.cap)); }
                    else if kk == "postcode" { c.postcode.append(string_of(r, scratch, c.postcode.cap)); }
                    else { json::skip(r); }
                };
            } else if k == "preferences" {
                json::each_member(r) { kk =>
                    if kk == "channel" { c.channel.append(string_of(r, scratch, c.channel.cap)); }
                    else if kk == "language" { c.language.append(string_of(r, scratch, c.language.cap)); }
                    else { json::skip(r); }
                };
            } else if k == "flags" {
                json::each_element(r) {
                    guard c.flags.len < c.flags.cap else { abort("more than 3 flags"); }
                    let f .= c.flags.push("");
                    f.append(string_of(r, scratch, f.cap));
                };
            } else if k == "emergencyContact" {
                json::each_member(r) { kk =>
                    if kk == "name" { c.contact.append(string_of(r, scratch, c.contact.cap)); }
                    else if kk == "phone" { c.contact_phone.append(string_of(r, scratch, c.contact_phone.cap)); }
                    else if kk == "relation" { c.relation.append(string_of(r, scratch, c.relation.cap)); }
                    else { json::skip(r); }
                };
            } else if k == "consents" {
                json::each_member(r) { kk =>
                    if kk == "sms" { c.sms = json::read_bool(r); }
                    else if kk == "email" { c.mail = json::read_bool(r); }
                    else if kk == "research" { c.research = json::read_bool(r); }
                    else { json::skip(r); }
                };
            } else if k == "createdAt" { c.created = read_time(r, scratch); }
            else if k == "updatedAt" { c.updated = read_time(r, scratch); }
            else { json::skip(r); }
        };
    };
    load_each(dir, "heavy-encounters.json") { c =>
        let r .= c.r;
        let v .= visits.push(Visit { client: -1, staff: -1, first_note: notes.len, .. });
        json::each_member(r) { k =>
            if k == "id" { guard json::read_int(r) == visits.len else { abort("heavy-encounters.json's ids aren't 1, 2, ..."); } }
            else if k == "caseId" { v.case_id = json::read_int(r); }
            else if k == "client" { v.client = ref_in(r, clients.len, "client"); }
            else if k == "staff" { v.staff = ref_in(r, staffers.len, "staff"); }
            else if k == "status" { v.status.append(string_of(r, scratch, v.status.cap)); }
            else if k == "kind" { v.kind.append(string_of(r, scratch, v.kind.cap)); }
            else if k == "priority" { v.priority.append(string_of(r, scratch, v.priority.cap)); }
            else if k == "start" { v.start = read_time(r, scratch); }
            else if k == "end" { v.end = read_time(r, scratch); }
            else if k == "items" { load_lines(r, scratch, v.lines); }
            else if k == "codes" {
                json::each_element(r) {
                    guard v.codes.len < v.codes.cap else { abort("more than 3 codes"); }
                    let c .= v.codes.push("");
                    c.append(string_of(r, scratch, c.cap));
                };
            } else if k == "notes" {
                var kind = 0;
                json::each_member(r) { kk =>
                    guard kk == note_kind(kind) else { abort(str("notes out of order: ", kk)); }
                    json::each_element(r) {
                        let n .= notes.push(Note { visit: visits.len - 1, kind: kind, author: -1, .. });
                        json::each_member(r) { nk =>
                            if nk == "id" { n.id = json::read_int(r); }
                            else if nk == "author" { n.author = ref_in(r, staffers.len, "staff"); }
                            else if nk == "text" {
                                n.text_at = text.len;
                                scratch.clear();
                                text.append(json::read_string(r, scratch));
                                n.text_len = text.len - n.text_at;
                            } else if nk == "at" { n.at = read_time(r, scratch); }
                            else { json::skip(r); }
                        };
                    };
                    kind++;
                };
            } else { json::skip(r); }
        };
        v.notes = notes.len - v.first_note;
        guard v.client >= 0 && v.staff >= 0 else { abort("an encounter without a client or staff"); }
        // A case's visits are together in the file.
        if visits.len > 1 && visits[visits.len - 2].case_id == v.case_id {
            let first = visits[visits.len - 2].case_first;
            v.case_first = first;
            for i in first..visits.len { visits[i].case_count = visits.len - first; }
        } else {
            guard visits.len == 1 || visits[visits.len - 2].case_id < v.case_id else { abort("a case's encounters apart"); }
            v.case_first = visits.len - 1;
            v.case_count = 1;
        }
    };
    load_each(dir, "heavy-bookings.json") { c =>
        let r .= c.r;
        let b .= bookings.push(Booking { client: -1, staff: -1, visit: -1, note_at: -1, .. });
        json::each_member(r) { k =>
            if k == "id" { guard json::read_int(r) == bookings.len else { abort("heavy-bookings.json's ids aren't 1, 2, ..."); } }
            else if k == "slot" {
                json::each_member(r) { kk =>
                    if kk == "start" { b.start = read_time(r, scratch); }
                    else if kk == "end" { b.end = read_time(r, scratch); }
                    else { json::skip(r); }
                };
            } else if k == "client" { b.client = ref_in(r, clients.len, "client"); }
            else if k == "staff" { b.staff = ref_in(r, staffers.len, "staff"); }
            else if k == "encounter" { b.visit = ref_in(r, visits.len, "encounter"); }
            else if k == "items" { load_lines(r, scratch, b.lines); }
            else if k == "reminders" {
                json::each_element(r) {
                    guard b.reminders.len < b.reminders.cap else { abort("more than 3 reminders"); }
                    let m .= b.reminders.push(Reminder { .. });
                    json::each_member(r) { kk =>
                        if kk == "channel" { m.channel.append(string_of(r, scratch, m.channel.cap)); }
                        else if kk == "kind" { m.kind.append(string_of(r, scratch, m.kind.cap)); }
                        else if kk == "status" { m.status.append(string_of(r, scratch, m.status.cap)); }
                        else if kk == "at" { m.at = read_time(r, scratch); }
                        else { json::skip(r); }
                    };
                };
            } else if k == "status" { b.status.append(string_of(r, scratch, b.status.cap)); }
            else if k == "source" { b.source.append(string_of(r, scratch, b.source.cap)); }
            else if k == "note" {
                if json::peek(r) == 'n' { json::skip(r); }
                else {
                    b.note_at = text.len;
                    scratch.clear();
                    text.append(json::read_string(r, scratch));
                    b.note_len = text.len - b.note_at;
                }
            } else if k == "createdAt" { b.created = read_time(r, scratch); }
            else if k == "updatedAt" { b.updated = read_time(r, scratch); }
            else { json::skip(r); }
        };
        guard b.client >= 0 && b.staff >= 0 && b.visit >= 0 else { abort("a booking without a client, staff, or encounter"); }
        guard bookings.len == 1 || bookings[bookings.len - 2].start <= b.start else { abort("bookings out of order"); }
    };
    load_each(dir, "heavy-shifts.json") { c =>
        let r .= c.r;
        let s .= shifts.push(Shift { staff: -1, .. });
        json::each_member(r) { k =>
            if k == "id" { guard json::read_int(r) == shifts.len else { abort("heavy-shifts.json's ids aren't 1, 2, ..."); } }
            else if k == "staff" { s.staff = ref_in(r, staffers.len, "staff"); }
            else if k == "start" { s.start = read_time(r, scratch); }
            else if k == "end" { s.end = read_time(r, scratch); }
            else if k == "kind" { s.kind.append(string_of(r, scratch, s.kind.cap)); }
            else if k == "room" {
                json::each_member(r) { kk =>
                    if kk == "id" { s.room = json::read_int(r); }
                    else if kk == "name" { s.room_name.append(string_of(r, scratch, s.room_name.cap)); }
                    else { json::skip(r); }
                };
            } else if k == "note" { s.note.append(read_nullable(r, scratch, s.note.cap)); }
            else { json::skip(r); }
        };
        guard s.staff >= 0 else { abort("a shift without staff"); }
        guard shifts.len == 1 || shifts[shifts.len - 2].start <= s.start else { abort("shifts out of order"); }
    };
    for v, i in visits { if v.status == "completed" { past.push(i); } }
    // Newest first, and of two at once the later id first.
    sort(past) { a, b =>
        let va = visits[a];
        let vb = visits[b];
        va.client < vb.client || va.client == vb.client && (va.start > vb.start || va.start == vb.start && a > b)
    };
    for i, k in past {
        let c .= clients[visits[i].client];
        if c.count == 0 { c.first = k; }
        c.count++;
    }
}

fn staff_ref(out: u8[>..]&, s: i64, title: bool) {
    out.append("{\"id\":");
    format(out, s + 1);
    out.append(",\"name\":");
    json::format_string(out, staffers[s].name);
    if title {
        out.append(",\"title\":");
        json::format_string(out, staffers[s].title);
    }
    out.push('}');
}

fn client_ref(out: u8[>..]&, c: i64) {
    out.append("{\"id\":");
    format(out, c + 1);
    out.append(",\"name\":");
    json::format_string(out, clients[c].name);
    out.append(",\"code\":");
    json::format_string(out, clients[c].code);
    out.push('}');
}

fn lines_full(out: u8[>..]&, lines: Line[:]) {
    out.push('[');
    for l, k in lines {
        let s = services[l.service];
        if k > 0 { out.push(','); }
        out.append("{\"id\":");
        format(out, l.id);
        out.append(",\"code\":");
        json::format_string(out, s.code);
        out.append(",\"name\":");
        json::format_string(out, s.name);
        out.append(",\"minutes\":");
        format(out, s.minutes);
        out.append(",\"price\":");
        format(out, s.price);
        out.push('}');
    }
    out.push(']');
}

fn booking_full(out: u8[>..]&, i: i64) {
    let b = bookings[i];
    let v = visits[b.visit];
    out.append("{\"id\":");
    format(out, i + 1);
    out.append(",\"slot\":{\"start\":");
    iso_or_null(out, b.start);
    out.append(",\"end\":");
    iso_or_null(out, b.end);
    out.append("},\"client\":");
    client_ref(out, b.client);
    out.append(",\"staff\":");
    staff_ref(out, b.staff, false);
    out.append(",\"encounter\":{\"id\":");
    format(out, b.visit + 1);
    out.append(",\"status\":");
    json::format_string(out, v.status);
    out.append(",\"start\":");
    iso_or_null(out, v.start);
    out.append(",\"end\":");
    iso_or_null(out, v.end);
    out.append("},\"items\":");
    lines_full(out, b.lines);
    out.append(",\"reminders\":[");
    for m, k in b.reminders {
        if k > 0 { out.push(','); }
        out.append("{\"channel\":");
        json::format_string(out, m.channel);
        out.append(",\"kind\":");
        json::format_string(out, m.kind);
        out.append(",\"status\":");
        json::format_string(out, m.status);
        out.append(",\"at\":");
        iso_or_null(out, m.at);
        out.push('}');
    }
    out.append("],\"status\":");
    json::format_string(out, b.status);
    out.append(",\"source\":");
    json::format_string(out, b.source);
    out.append(",\"note\":");
    if b.note_at < 0 { out.append("null"); } else { json::format_string(out, text[b.note_at..b.note_at + b.note_len]); }
    out.append(",\"createdAt\":");
    iso_or_null(out, b.created);
    out.append(",\"updatedAt\":");
    iso_or_null(out, b.updated);
    out.push('}');
}

fn shift_full(out: u8[>..]&, i: i64) {
    let s = shifts[i];
    out.append("{\"id\":");
    format(out, i + 1);
    out.append(",\"staff\":");
    staff_ref(out, s.staff, false);
    out.append(",\"start\":");
    iso_or_null(out, s.start);
    out.append(",\"end\":");
    iso_or_null(out, s.end);
    out.append(",\"kind\":");
    json::format_string(out, s.kind);
    out.append(",\"room\":{\"id\":");
    format(out, s.room);
    out.append(",\"name\":");
    json::format_string(out, s.room_name);
    out.append("},\"note\":");
    string_or_null(out, s.note);
    out.push('}');
}

fn client_full(out: u8[>..]&, i: i64) {
    let c = clients[i];
    out.append("{\"id\":");
    format(out, i + 1);
    out.append(",\"name\":");
    json::format_string(out, c.name);
    out.append(",\"code\":");
    json::format_string(out, c.code);
    out.append(",\"born\":");
    json::format_string(out, c.born);
    out.append(",\"phone\":");
    json::format_string(out, c.phone);
    out.append(",\"email\":");
    json::format_string(out, c.email);
    out.append(",\"address\":{\"street\":");
    json::format_string(out, c.street);
    out.append(",\"city\":");
    json::format_string(out, c.city);
    out.append(",\"postcode\":");
    json::format_string(out, c.postcode);
    out.append("},\"preferences\":{\"channel\":");
    json::format_string(out, c.channel);
    out.append(",\"language\":");
    json::format_string(out, c.language);
    out.append("},\"flags\":[");
    for f, k in c.flags {
        if k > 0 { out.push(','); }
        json::format_string(out, f);
    }
    out.append("],\"emergencyContact\":{\"name\":");
    json::format_string(out, c.contact);
    out.append(",\"phone\":");
    json::format_string(out, c.contact_phone);
    out.append(",\"relation\":");
    json::format_string(out, c.relation);
    out.append("},\"consents\":{\"sms\":");
    json::format_bool(out, c.sms);
    out.append(",\"email\":");
    json::format_bool(out, c.mail);
    out.append(",\"research\":");
    json::format_bool(out, c.research);
    out.append("},\"createdAt\":");
    iso_or_null(out, c.created);
    out.append(",\"updatedAt\":");
    iso_or_null(out, c.updated);
    out.push('}');
}

// A note's members after its id: as a visit's notes list it, the author,
// text, and time; as caseNotes lists it, its encounter and kind before.
fn note_body(out: u8[>..]&, n: Note) {
    out.append(",\"author\":");
    staff_ref(out, n.author, true);
    out.append(",\"text\":");
    json::format_string(out, text[n.text_at..n.text_at + n.text_len]);
    out.append(",\"at\":");
    iso_or_null(out, n.at);
    out.push('}');
}

fn case_note_full(out: u8[>..]&, n: Note) {
    out.append("{\"id\":");
    format(out, n.id);
    out.append(",\"encounterId\":");
    format(out, n.visit + 1);
    out.append(",\"kind\":\"");
    out.append(note_kind(n.kind));
    out.push('"');
    note_body(out, n);
}

// A visit with its notes by kind, without the closing brace.
fn visit_open(out: u8[>..]&, i: i64) {
    let v = visits[i];
    out.append("{\"id\":");
    format(out, i + 1);
    out.append(",\"caseId\":");
    format(out, v.case_id);
    out.append(",\"client\":");
    client_ref(out, v.client);
    out.append(",\"staff\":");
    staff_ref(out, v.staff, true);
    out.append(",\"status\":");
    json::format_string(out, v.status);
    out.append(",\"kind\":");
    json::format_string(out, v.kind);
    out.append(",\"priority\":");
    json::format_string(out, v.priority);
    out.append(",\"start\":");
    iso_or_null(out, v.start);
    out.append(",\"end\":");
    iso_or_null(out, v.end);
    out.append(",\"items\":");
    lines_full(out, v.lines);
    out.append(",\"codes\":[");
    for c, k in v.codes {
        if k > 0 { out.push(','); }
        json::format_string(out, c);
    }
    out.append("],\"notes\":{");
    var j = v.first_note;
    for kind in 4 {
        if kind > 0 { out.push(','); }
        out.push('"');
        out.append(note_kind(kind));
        out.append("\":[");
        var n = 0;
        while j < v.first_note + v.notes && notes[j].kind == kind {
            if n > 0 { out.push(','); }
            out.append("{\"id\":");
            format(out, notes[j].id);
            note_body(out, notes[j]);
            n++;
            j++;
        }
        out.push(']');
    }
    out.push('}');
}

fn prebuild_heavy() {
    for i in bookings.len {
        booking_at.push(booking_json.len);
        booking_full(booking_json, i);
    }
    booking_at.push(booking_json.len);
    for i in shifts.len {
        shift_at.push(shift_json.len);
        shift_full(shift_json, i);
    }
    shift_at.push(shift_json.len);
    for i in clients.len {
        client_at.push(client_json.len);
        client_full(client_json, i);
    }
    client_at.push(client_json.len);
    for i in visits.len {
        visit_at.push(visit_json.len);
        visit_open(visit_json, i);
    }
    visit_at.push(visit_json.len);
    for n in notes {
        note_at.push(note_json.len);
        case_note_full(note_json, n);
    }
    note_at.push(note_json.len);
}

// Tiers C and D's per-request state. Its error_body writes {"error",
// "status"}, with the code each status has in the clinic's API, whatever
// code goose-rest or a route gave.
struct Heavy { unused: bool = false }

fn rest::error_body(body: u8[>..]&, st: const Heavy&, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
    let name = if status == 400 { "bad_request" } else if status == 401 { "unauthorized" }
               else if status == 404 { "not_found" } else if status == 405 { "method_not_allowed" }
               else if status == 413 { "payload_too_large" } else if status == 415 { "unsupported_media_type" }
               else { code };
    format(body, "{\"error\":\"", name, "\",\"status\":", status, "}");
}

fn bad_request(cx) { rest::fail(cx, 400, "bad_request"); }

fn is_base64url(s: const u8[:]) -> bool {
    guard s.len > 0 else { return false; }
    for c in s {
        if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_') { return false; }
    }
    return true;
}

// Whether t is a token of three base64url segments, as a JWT is.
fn jwt_shaped(t: const u8[:]) -> bool {
    let a = position(t, '.');
    guard a > 0 else { return false; }
    let rest = t[a + 1..];
    let b = position(rest, '.');
    return b > 0 && is_base64url(t[..a]) && is_base64url(rest[..b]) && is_base64url(rest[b + 1..]);
}

// rest::bearer, with a token shaped as a JWT, which isn't verified.
inline fn authed<F>(cx) {
    rest::bearer(cx) { token =>
        guard jwt_shaped(token) else { rest::invalid_token(cx); }
        F();
    };
}

// A start and an end day, end after start and at most 31 days on, and the
// staff of a list of their ids as bits, or 400.
fn range_of(cx) -> i64, i64, i64 {
    let s, has_start = rest::query(cx, "start");
    let e, has_end = rest::query(cx, "end");
    let list, has_staff = rest::query(cx, "staff");
    guard has_start && has_end && has_staff else { bad_request(cx); }
    let start, start_ok = parse_day(s);
    let end, end_ok = parse_day(e);
    guard start_ok && end_ok && end > start && end - start <= 31 * DAY else { bad_request(cx); }
    var mask = 0;
    var ok = list.len > 0;
    each_split(list, ',') {
        let n, num = parse_int(it);
        if num && n >= 1 && n <= staffers.len { mask |= 1 << (n - 1); } else { ok = false; }
    };
    guard ok else { bad_request(cx); }
    return start, end, mask;
}

fn list_bookings(cx, buf: u8[>..]&) {
    let start, end, mask = range_of(cx);
    buf.append("{\"bookings\":[");
    var n = 0;
    var i = lower_bound(bookings) { it.start < start };
    while i < bookings.len && bookings[i].start < end {
        if (mask >> bookings[i].staff) & 1 != 0 {
            if n > 0 { buf.push(','); }
            if template { buf.append(booking_json[booking_at[i]..booking_at[i + 1]]); } else { booking_full(buf, i); }
            n++;
        }
        i++;
    }
    buf.append("],\"count\":");
    format(buf, n);
    buf.push('}');
    rest::json_bytes(cx, 200, buf);
}

fn list_shifts(cx, buf: u8[>..]&) {
    let start, end, mask = range_of(cx);
    buf.append("{\"shifts\":[");
    var n = 0;
    var i = lower_bound(shifts) { it.start < start };
    while i < shifts.len && shifts[i].start < end {
        if (mask >> shifts[i].staff) & 1 != 0 {
            if n > 0 { buf.push(','); }
            if template { buf.append(shift_json[shift_at[i]..shift_at[i + 1]]); } else { shift_full(buf, i); }
            n++;
        }
        i++;
    }
    buf.append("],\"count\":");
    format(buf, n);
    buf.push('}');
    rest::json_bytes(cx, 200, buf);
}

fn visit_into(buf: u8[>..]&, i: i64) {
    if template { buf.append(visit_json[visit_at[i]..visit_at[i + 1]]); } else { visit_open(buf, i); }
}

// The encounter, and the notes of every visit of its case, oldest first.
fn show_encounter(cx, i: i64, buf: u8[>..]&) {
    let v = visits[i];
    visit_into(buf, i);
    buf.append(",\"caseNotes\":[");
    var n = 0;
    for c in v.case_first..v.case_first + v.case_count {
        let w = visits[c];
        for j in w.first_note..w.first_note + w.notes {
            if n > 0 { buf.push(','); }
            if template { buf.append(note_json[note_at[j]..note_at[j + 1]]); } else { case_note_full(buf, notes[j]); }
            n++;
        }
    }
    buf.append("]}");
    rest::json_bytes(cx, 200, buf);
}

// The client's completed visits, newest first, up to limit, and how many
// there are.
fn client_history(cx, c: i64, buf: u8[>..]&) {
    var limit = 20;
    let v, has = rest::query(cx, "limit");
    if has {
        let n, ok = parse_int(v);
        guard ok && n >= 1 && n <= 50 else { bad_request(cx); }
        limit = n;
    }
    let cl = clients[c];
    buf.append("{\"items\":[");
    for k in min(limit, cl.count) {
        if k > 0 { buf.push(','); }
        visit_into(buf, past[cl.first + k]);
        buf.push('}');
    }
    buf.append("],\"total\":");
    format(buf, cl.count);
    buf.push('}');
    rest::json_bytes(cx, 200, buf);
}

// GET /schedule/version: the schedule's version, the minutes since
// version_epoch, and when it changed to it.
fn schedule_version(cx, buf: u8[>..]&) {
    let since, has = rest::query(cx, "since");
    let n, ok = parse_int(since);
    guard has && ok && n >= 0 else { bad_request(cx); }
    let version = (now_ms() - version_epoch) / MINUTE;
    buf.append("{\"version\":");
    format(buf, version);
    buf.append(",\"changedAt\":");
    iso_or_null(buf, version_epoch + version * MINUTE);
    buf.push('}');
    rest::json_bytes(cx, 200, buf);
}

// The record of the path's id among n, or 404.
fn record_of(cx, r: const http::Router&, n: i64) -> i64 {
    let i = index_of(rest::param(cx, r, "id"), n);
    guard i >= 0 else { rest::fail(cx, 404, "not_found"); }
    return i;
}

// Tier C's routes, and with writes tier D's beside them, each behind the
// bearer token. An unknown path is 404 whatever its method, as the clinic's
// API answers it, not 405.
fn heavy(cx, buf: u8[>..]&, writes: bool) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/api/v2/schedule/version") {
        authed(cx) { schedule_version(cx, buf); };
    } else if http::on(r, "GET", "/api/v2/schedule/bookings") {
        authed(cx) { list_bookings(cx, buf); };
    } else if http::on(r, "GET", "/api/v2/schedule/shifts") {
        authed(cx) { list_shifts(cx, buf); };
    } else if http::on(r, "GET", "/api/v2/encounters/:id") {
        authed(cx) { show_encounter(cx, record_of(cx, r, visits.len), buf); };
    } else if http::on(r, "GET", "/api/v2/clients/:id/encounters") {
        authed(cx) { client_history(cx, record_of(cx, r, clients.len), buf); };
    } else if http::on(r, "GET", "/api/v2/clients/:id") {
        authed(cx) {
            let c = record_of(cx, r, clients.len);
            if template { buf.append(client_json[client_at[c]..client_at[c + 1]]); } else { client_full(buf, c); }
            rest::json_bytes(cx, 200, buf);
        };
    } else if writes && http::on(r, "POST", "/api/v3/imports") {
        authed(cx) { import_csv(cx, buf); };
    } else if writes && http::on(r, "POST", "/api/v3/attachments") {
        authed(cx) { attach(cx, buf); };
    } else if writes && http::on(r, "POST", "/api/v3/bookings/batch") {
        authed(cx) { batch(cx, buf); };
    } else if writes && http::on(r, "POST", "/api/v3/forms") {
        authed(cx) { form(cx, buf); };
    } else {
        rest::fail(cx, 404, "not_found");
    }
}

// Tier D, writes with large bodies, under /api/v3, served beside tier C's
// reads for the mixed run. Each answer is computed from the body alone, and
// the data doesn't change. The CSV and the multipart body are read in pieces
// as they arrive; the batch and the form are joined first, as the JSON reader
// takes only a whole text.

let IMPORT_LIMIT: i64 = 16 * 1024 * 1024;
let BATCH_LIMIT: i64 = 1024 * 1024;
let FORM_LIMIT: i64 = 64 * 1024;
let MAX_TEXT = 1024;    // a multipart text field's value
let MAX_TEXTS = 8;

// Leaves the route with 415 unless the request's body is of type t.
fn typed(cx, t: const u8[:]) {
    guard http::has_type(cx.req, t) else { rest::fail(cx, 415, "unsupported_media_type"); }
}

// An import's columns, of three kinds.
let COLUMNS = 6;
let TEXT: u8 = 0;
let INT: u8 = 1;
let DEC: u8 = 2;    // two decimal places

fn column_name(k: i64) -> const u8[:] { ["id", "date", "account", "description", "quantity", "amount"][k] }

fn column_kind(k: i64) -> u8 { if k == 0 || k == 4 { INT } else if k == 5 { DEC } else { TEXT } }

// Where a CSV reader is in a field (Csv.quote).
let OUTSIDE: u8 = 0;
let INSIDE: u8 = 1;     // in a quoted field
let AFTER: u8 = 2;      // past a quote in a quoted field: its end, or the first of two

// A CSV body (RFC 4180, with LF or CRLF line ends) read in pieces: where the
// reader is, the field it's in, and each column's count of non-empty cells
// and its sum, or its bytes for text.
struct Csv {
    record: i64 = 1,            // the header is the first
    column: i64 = 0,
    quote: u8 = OUTSIDE,
    closed: bool = false,       // the field's closing quote has passed
    cr: bool = false,           // a CR outside quotes, which only a LF may follow
    len: i64 = 0,               // the field's bytes
    value: i64 = 0,
    neg: bool = false,
    digits: i64 = 0,
    point: i64 = -1,            // the digits after a decimal point, or -1
    number: bool = true,        // the field is still a number of its column's kind
    header: u8[..16] = [],
    counts: i64[6] = [0; 6],
    sums: i64[6] = [0; 6],
    bad: i64 = 0,               // the first record that isn't one, or 0
}

fn csv_bad(c: Csv&) { if c.bad == 0 { c.bad = c.record; } }

fn csv_text(c: Csv&, s: const u8[:]) {
    c.len += s.len;
    if c.record == 1 {
        if c.header.len + s.len <= 16 { c.header.append(s); }
        return;
    }
    guard c.column < COLUMNS else { return; }
    let kind = column_kind(c.column);
    guard kind != TEXT else { return; }
    let before = c.len - s.len;
    for ch, i in s {
        if ch >= '0' && ch <= '9' {
            if c.digits < 18 { c.value = c.value * 10 + (ch - '0'); } else { c.number = false; }
            c.digits++;
            if c.point >= 0 { c.point++; }
        } else if ch == '-' && before + i == 0 {
            c.neg = true;
        } else if ch == '.' && kind == DEC && c.point < 0 && c.digits > 0 {
            c.point = 0;
        } else {
            c.number = false;
        }
    }
}

fn csv_field_end(c: Csv&) {
    let k = c.column;
    if k >= COLUMNS {
        csv_bad(c);
    } else if c.record == 1 {
        if c.len > 16 || c.header != column_name(k) { csv_bad(c); }
    } else if c.len > 0 {
        let kind = column_kind(k);
        if kind == TEXT {
            c.counts[k]++;
            c.sums[k] += c.len;
        } else if c.number && c.digits > 0 && (if kind == DEC { c.point == 2 } else { c.point < 0 }) {
            c.counts[k]++;
            c.sums[k] += if c.neg { -c.value } else { c.value };
        } else {
            csv_bad(c);
        }
    }
    c.column++;
    c.len = 0;
    c.value = 0;
    c.neg = false;
    c.digits = 0;
    c.point = -1;
    c.number = true;
    c.closed = false;
    c.header.clear();
}

fn csv_record_end(c: Csv&) {
    csv_field_end(c);
    if c.column != COLUMNS { csv_bad(c); }
    c.record++;
    c.column = 0;
}

// Reads the next piece of a CSV body into c.
fn csv_piece(c: Csv&, p: const u8[:]) {
    var i = 0;
    while i < p.len && c.bad == 0 {
        let ch = p[i];
        if c.quote == INSIDE {
            let q = position(p[i..], '"');
            if q < 0 {
                csv_text(c, p[i..]);
                return;
            }
            csv_text(c, p[i..i + q]);
            c.quote = AFTER;
            i += q + 1;
            continue;
        }
        if c.quote == AFTER {
            c.quote = OUTSIDE;
            if ch == '"' {
                csv_text(c, p[i..i + 1]);
                c.quote = INSIDE;
                i++;
                continue;
            }
            c.closed = true;
        }
        if c.cr {
            c.cr = false;
            if ch != '\n' {
                csv_bad(c);
                return;
            }
        }
        if ch == ',' {
            csv_field_end(c);
            i++;
        } else if ch == '\n' {
            csv_record_end(c);
            i++;
        } else if ch == '\r' {
            c.cr = true;
            i++;
        } else if c.closed || ch == '"' && c.len > 0 {
            csv_bad(c);
        } else if ch == '"' {
            c.quote = INSIDE;
            i++;
        } else {
            var j = i + 1;
            while j < p.len && p[j] != ',' && p[j] != '\n' && p[j] != '\r' && p[j] != '"' { j++; }
            csv_text(c, p[i..j]);
            i = j;
        }
    }
}

// Ends a CSV body: a last record without a line end ends with it.
fn csv_end(c: Csv&) {
    guard c.bad == 0 else { return; }
    if c.quote == INSIDE || c.cr {
        csv_bad(c);
        return;
    }
    if c.quote == AFTER || c.closed || c.column > 0 || c.len > 0 { csv_record_end(c); }
    if c.record == 1 { csv_bad(c); }
}

// Cents as a JSON number with two decimal places.
fn format_cents(out: u8[>..]&, v: i64) {
    if v < 0 { out.push('-'); }
    let a = if v < 0 { -v } else { v };
    format(out, a / 100, ".");
    digits(out, a % 100, 2);
}

// POST /imports: the CSV's rows, and each column's count and sum.
fn import_csv(cx, buf: u8[>..]&) {
    typed(cx, "text/csv");
    var c = Csv { .. };
    csv_piece(c, rest::body(cx, IMPORT_LIMIT));
    csv_end(c);
    guard c.bad == 0 else {
        format(buf, "{\"error\":\"bad_csv\",\"record\":", c.bad, "}");
        rest::json_bytes(cx, 400, buf);
        return;
    }
    format(buf, "{\"rows\":", c.record - 2, ",\"columns\":[");
    for k in COLUMNS {
        if k > 0 { buf.push(','); }
        format(buf, "{\"name\":\"", column_name(k), "\",\"count\":", c.counts[k]);
        let kind = column_kind(k);
        if kind == TEXT {
            format(buf, ",\"bytes\":", c.sums[k]);
        } else if kind == INT {
            format(buf, ",\"sum\":", c.sums[k]);
        } else {
            buf.append(",\"sum\":");
            format_cents(buf, c.sums[k]);
        }
        buf.push('}');
    }
    buf.append("]}");
    rest::json_bytes(cx, 201, buf);
}

// The part of a multipart body being read (Spool.part).
let NO_PART: u8 = 0;
let TEXT_PART: u8 = 1;
let FILE_PART: u8 = 2;

// What a write that comes in pieces keeps until its end: the CSV's reader,
// the multipart body's, with its text fields as JSON members and its file's
// size and Adler-32, and a run of the worker's spill (at, len, cap) for what
// it joins, the body or a text field's value.
struct Spool {
    parts: http::Multipart = http::Multipart { .. },
    csv: Csv = Csv { .. },
    at: i64 = 0,
    len: i64 = 0,
    cap: i64 = 0,
    failed: bool = false,
    part: u8 = NO_PART,
    name: u8[..64] = [],
    fields: u8[..8192] = [],
    texts: i64 = 0,
    files: i64 = 0,
    file_field: u8[..64] = [],
    filename: u8[..256] = [],
    file_type: u8[..128] = [],
    size: i64 = 0,
    adler_a: u64 = 1,
    adler_b: u64 = 0,
}

// Each worker's spools, and the runs they join into.
reusable var spools: Spool[>..] = [];
reusable[] var spill: u8[>..] = [];

fn joined(sp: const Spool&) -> const u8[:] { spill[sp.at..sp.at + sp.len] }

fn join(sp: Spool&, data: const u8[:]) {
    let n = sp.len + data.len;
    if n > sp.cap {
        let cap = max(max(n, sp.cap * 2), 16384);
        let run = spill.realloc_slice(spill[sp.at..sp.at + sp.cap], cap);
        sp.at = spill.index_of(run[0]);
        sp.cap = cap;
    }
    copy_into(spill[sp.at + sp.len..sp.at + n], data);
    sp.len = n;
}

fn release(k: i64) {
    let sp .= spools[k];
    if sp.cap > 0 { spill.free_slice(spill[sp.at..sp.at + sp.cap]); }
    spools.free(k);
}

fn part_head(sp: Spool&, fields: const u8[:]) {
    let name, filename, ok = http::disposition(fields);
    guard ok && name.len > 0 && name.len <= 64 else {
        sp.failed = true;
        return;
    }
    if filename.len > 0 {
        let t, typed = http::field_in(fields, "content-type");
        guard sp.files == 0 && filename.len <= 256 && t.len <= 128 else {
            sp.failed = true;
            return;
        }
        sp.files = 1;
        sp.part = FILE_PART;
        sp.file_field.append(name);
        sp.filename.append(filename);
        sp.file_type.append(if typed { t } else { "application/octet-stream" });
    } else {
        guard sp.texts < MAX_TEXTS else {
            sp.failed = true;
            return;
        }
        sp.part = TEXT_PART;
        sp.name.clear();
        sp.name.append(name);
        sp.len = 0;
    }
}

// Adler-32 (RFC 1950) over data, from where a and b are, deferring the modulo
// as zlib does: 5,552 bytes keep b within 32 bits.
fn adler(sp: Spool&, data: const u8[:]) {
    var a = sp.adler_a;
    var b = sp.adler_b;
    var i = 0;
    while i < data.len {
        let n = min(data.len - i, 5552);
        for c in data[i..i + n] {
            a += c;
            b += a;
        }
        a %= 65521;
        b %= 65521;
        i += n;
    }
    sp.adler_a = a;
    sp.adler_b = b;
}

fn part_data(sp: Spool&, data: const u8[:]) {
    if sp.part == FILE_PART {
        sp.size += data.len;
        adler(sp, data);
    } else if sp.len + data.len <= MAX_TEXT {
        join(sp, data);
    } else {
        sp.failed = true;
    }
}

fn part_end(sp: Spool&) {
    if sp.part == TEXT_PART {
        // Escaped, a byte takes at most 6.
        guard sp.fields.len + 6 * (sp.name.len + sp.len) + 8 <= 8192 else {
            sp.failed = true;
            return;
        }
        if sp.texts > 0 { sp.fields.push(','); }
        http::json_string(sp.fields, sp.name);
        sp.fields.push(':');
        http::json_string(sp.fields, joined(sp));
        sp.texts++;
    }
    sp.part = NO_PART;
}

fn attach_piece(sp: Spool&, data: const u8[:]) {
    guard !sp.failed else { return; }
    let ok = http::each_part(sp.parts, data) { part =>
        if !sp.failed {
            match part {
                Head h => part_head(sp, h.fields),
                Data d => part_data(sp, d.bytes),
                End => part_end(sp),
            }
        }
    };
    if !ok { sp.failed = true; }
}

// POST /attachments: the text fields, and the file's size and Adler-32. The
// spool is released before the route answers, as rest::fail leaves at once.
fn attach(cx, buf: u8[>..]&) {
    typed(cx, "multipart/form-data");
    let body = rest::body(cx, IMPORT_LIMIT);
    let k = spools.alloc_index(Spool { .. });
    let status = attach_answer(spools[k], cx.req, body, buf);
    release(k);
    guard status != 400 else { bad_request(cx); }
    rest::json_bytes(cx, status, buf);
}

// The multipart body's answer into buf, and its status.
fn attach_answer(sp: Spool&, req: const http::Request&, body: const u8[:], buf: u8[>..]&) -> i32 {
    guard http::start_multipart(req, sp.parts) else { return 400; }
    attach_piece(sp, body);
    guard !sp.failed && http::multipart_done(sp.parts) else { return 400; }
    guard sp.files > 0 else {
        buf.append("{\"error\":\"invalid\",\"errors\":[{\"field\":\"file\",\"message\":\"is required\"}]}");
        return 422;
    }
    buf.append("{\"fields\":{");
    buf.append(sp.fields);
    buf.append("},\"file\":{\"field\":");
    http::json_string(buf, sp.file_field);
    buf.append(",\"filename\":");
    http::json_string(buf, sp.filename);
    buf.append(",\"contentType\":");
    http::json_string(buf, sp.file_type);
    format(buf, ",\"size\":", sp.size, ",\"adler32\":", (sp.adler_b << 16) | sp.adler_a, "}}");
    return 201;
}

// How a batch's booking's field read (BookingIn).
let ABSENT: u8 = 0;
let WRONG: u8 = 1;
let FINE: u8 = 2;

struct BookingIn {
    client: u8 = ABSENT,
    staff: u8 = ABSENT,
    service: u8 = ABSENT,
    start: u8 = ABSENT,
    end: u8 = ABSENT,
    room: u8 = ABSENT,
    note: u8 = FINE,
    from: i64 = 0,
    to: i64 = 0,
}

// Whether the member at r's cursor is an integer from lo to hi: a JSON
// number with no fraction.
fn int_member(r: json::Reader&, lo: i64, hi: i64) -> u8 {
    let c = json::peek(r);
    guard c == '-' || c >= '0' && c <= '9' else {
        json::skip(r);
        return WRONG;
    }
    let v = json::read_number(r);
    guard v >= lo && v <= hi && v == v as i64 else { return WRONG; }
    return FINE;
}

fn string_member(r: json::Reader&, scratch: u8[>..]&) -> const u8[:], bool {
    guard json::peek(r) == '"' else {
        json::skip(r);
        return "", false;
    }
    return json::read_string(r, scratch), true;
}

// Two to four capital letters, '-', and two digits.
fn is_service(s: const u8[:]) -> bool {
    let d = position(s, '-');
    guard d >= 2 && d <= 4 && s.len == d + 3 else { return false; }
    for c in s[..d] { if c < 'A' || c > 'Z' { return false; } }
    return s[d + 1] >= '0' && s[d + 1] <= '9' && s[d + 2] >= '0' && s[d + 2] <= '9';
}

fn booking_error(errors: u8[>..]&, k: i64, field: const u8[:], message: const u8[:]) {
    if errors.len > 0 { errors.push(','); }
    format(errors, "{\"index\":", k, ",\"field\":\"", field, "\",\"message\":\"", message, "\"}");
}

fn check_field(errors: u8[>..]&, k: i64, how: u8, field: const u8[:], message: const u8[:]) {
    if how == ABSENT { booking_error(errors, k, field, "is required"); }
    else if how == WRONG { booking_error(errors, k, field, message); }
}

// POST /bookings/batch: each booking's id, the batch's id and its number,
// and their minutes, or 422 with each field that doesn't validate.
// POST /bookings/batch: each booking's new id, or 422 with the field errors.
fn batch(cx, buf: u8[>..]&) {
    typed(cx, "application/json");
    bookings_batch(cx, rest::body(cx, BATCH_LIMIT), buf);
}

fn bookings_batch(cx, body: const u8[:], buf: u8[>..]&) {
    var r = json::reader(body);
    var scratch: u8[>..] = [];
    var errors: u8[>..] = [];
    var batch_id: u8[..64] = [];
    var named = false;
    var listed = false;
    var count = 0;
    var minutes = 0;
    guard json::peek(r) == '{' else { bad_request(cx); }
    json::each_member(r) { key =>
        if key == "batchId" {
            let s, ok = string_member(r, scratch);
            if ok && s.len >= 1 && s.len <= 64 {
                batch_id.clear();
                batch_id.append(s);
                named = true;
            }
        } else if key == "bookings" && json::peek(r) == '[' {
            listed = true;
            count = 0;
            json::each_element(r) {
                if json::peek(r) != '{' {
                    json::skip(r);
                    booking_error(errors, count, "booking", "must be an object");
                } else {
                    var b = BookingIn { .. };
                    json::each_member(r) { name =>
                        if name == "clientId" {
                            b.client = int_member(r, 1, 1000000);
                        } else if name == "staffId" {
                            b.staff = int_member(r, 1, 10);
                        } else if name == "room" {
                            b.room = int_member(r, 1, 6);
                        } else if name == "service" {
                            let s, ok = string_member(r, scratch);
                            b.service = if ok && is_service(s) { FINE } else { WRONG };
                        } else if name == "start" || name == "end" {
                            let s, ok = string_member(r, scratch);
                            let t, valid = parse_iso(s);
                            let how = if ok && valid { FINE } else { WRONG };
                            if name == "start" {
                                b.start = how;
                                b.from = t;
                            } else {
                                b.end = how;
                                b.to = t;
                            }
                        } else if name == "note" {
                            if json::peek(r) == 'n' {
                                json::skip(r);
                                b.note = FINE;
                            } else {
                                let s, ok = string_member(r, scratch);
                                b.note = if ok && s.len <= 500 { FINE } else { WRONG };
                            }
                        } else {
                            json::skip(r);
                        }
                    };
                    check_field(errors, count, b.client, "clientId", "must be an integer from 1 to 1000000");
                    check_field(errors, count, b.staff, "staffId", "must be an integer from 1 to 10");
                    check_field(errors, count, b.service, "service", "must be a service code");
                    check_field(errors, count, b.start, "start", "must be an ISO 8601 time");
                    check_field(errors, count, b.end, "end", "must be an ISO 8601 time");
                    if b.start == FINE && b.end == FINE && (b.to <= b.from || b.to - b.from > 8 * 3600000) {
                        booking_error(errors, count, "end", "must be after start, by at most 8 hours");
                    }
                    check_field(errors, count, b.room, "room", "must be an integer from 1 to 6");
                    check_field(errors, count, b.note, "note", "must be a string of at most 500 bytes");
                    minutes += (b.to - b.from) / MINUTE;
                }
                count++;
            };
        } else {
            json::skip(r);
        }
    };
    guard json::finish(r) && named && listed else { bad_request(cx); }
    if errors.len > 0 {
        buf.append("{\"error\":\"invalid\",\"errors\":[");
        buf.append(errors);
        buf.append("]}");
        rest::json_bytes(cx, 422, buf);
        return;
    }
    buf.append("{\"batchId\":");
    http::json_string(buf, batch_id);
    format(buf, ",\"count\":", count, ",\"minutes\":", minutes, ",\"ids\":[");
    for k in count {
        if k > 0 { buf.push(','); }
        buf.push('"');
        buf.append(batch_id);
        format(buf, "-", k + 1, "\"");
    }
    buf.append("]}");
    rest::json_bytes(cx, 201, buf);
}

// POST /forms: the form's fields, decoded, in order.
fn form(cx, buf: u8[>..]&) {
    typed(cx, "application/x-www-form-urlencoded");
    form_answer(cx, rest::body(cx, FORM_LIMIT), buf);
}

fn form_answer(cx, body: const u8[:], buf: u8[>..]&) {
    var ok = true;
    var n = 0;
    var k: u8[>..] = [];
    var v: u8[>..] = [];
    buf.append("{\"fields\":{");
    http::each_form(body) { kraw, vraw =>
        k.clear();
        v.clear();
        if http::decode(kraw, k, true) && http::decode(vraw, v, true) {
            if n > 0 { buf.push(','); }
            http::json_string(buf, k);
            buf.push(':');
            http::json_string(buf, v);
            n++;
        } else {
            ok = false;
        }
    };
    guard ok else { bad_request(cx); }
    format(buf, "},\"count\":", n, "}");
    rest::json_bytes(cx, 200, buf);
}

// Tier A's routes, in goose-rest's own error shape.
fn arena(cx, buf: u8[>..]&) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/api/items/:id") {
        let i = index_of(rest::param(cx, r, "id"), items.len);
        guard i >= 0 else { rest::fail(cx, 404, "item_not_found"); }
        if template { buf.append(item_json[item_at[i]..item_at[i + 1]]); } else { item_open(buf, items[i]); }
        served(buf);
        rest::json_bytes(cx, 200, buf);
    } else if http::on(r, "GET", "/api/me") {
        let id, has = rest::header(cx, "x-user-id");
        let i = if has { index_of(id, users.len) } else { -1 };
        guard i >= 0 else { rest::fail(cx, 401, "unknown_user"); }
        if template { buf.append(user_json[user_at[i]..user_at[i + 1]]); } else { user_open(buf, users[i]); }
        served(buf);
        rest::json_bytes(cx, 200, buf);
    } else if http::on(r, "POST", "/api/items/:id") {
        let i = index_of(rest::param(cx, r, "id"), items.len);
        guard i >= 0 else { rest::fail(cx, 404, "item_not_found"); }
        guard valid_write(rest::body(cx)) else { rest::fail(cx, 422, "invalid_item"); }
        http::start(cx.out, 204);
        http::finish(cx.out, "", "");
    } else {
        rest::otherwise(cx, r);
    }
}

// Tier F, the bun-http-framework-benchmark's three routes (bench/rest/tiers).
fn micro(cx) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/") {
        rest::text(cx, 200, "Hi");
    } else if http::on(r, "GET", "/id/:id") {
        var b: u8[>..] = [];
        b.append(rest::param(cx, r, "id"));
        b.push(' ');
        let name, has = rest::query(cx, "name");
        b.append(name);
        http::start(cx.out, 200);
        http::field(cx.out, "x-powered-by", "benchmark");
        http::finish(cx.out, "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", b);
    } else if http::on(r, "POST", "/json") {
        var out: u8[>..] = [];
        guard echo(rest::body(cx), out) else { rest::fail(cx, 400, "invalid_body"); }
        rest::json_bytes(cx, 200, out);
    } else {
        rest::otherwise(cx, r);
    }
}

// Tier F on goose-http alone, the baseline: http::serve's handler, its
// router and query, and http::respond.
fn micro_bare(req: http::Request, body: const u8[:], out: http::Reply) {
    var r = http::router(req);
    if http::on(r, "GET", "/") {
        http::respond(out, 200, "text/plain; charset=utf-8", "Hi");
    } else if http::on(r, "GET", "/id/:id") {
        var b: u8[>..] = [];
        b.append(http::param(r, "id"));
        b.push(' ');
        let v, has = http::query_of(req.target, "name");
        http::decode(v, b, true);
        http::start(out, 200);
        http::field(out, "x-powered-by", "benchmark");
        http::finish(out, "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", b);
    } else if http::on(r, "POST", "/json") {
        var j: u8[>..] = [];
        if echo(body, j) { http::respond(out, 200, "application/json", j); }
        else { http::respond(out, 400, "application/json", "{\"error\":\"invalid_body\"}"); }
    } else {
        http::otherwise(r, out);
    }
}

// POST /json: the body read into json's nodes and written back from them
// into out; false for a body that isn't JSON.
fn echo(body: const u8[:], out: u8[>..]&) -> bool {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, err = json::parse(body, doc, decoded);
    guard root else { return false; }
    write_node(out, root);
    return true;
}

recursive fn write_node(out: u8[>..]&, n: json::Node&) {
    match n.val {
        Null => out.append("null"),
        Bool b => json::format_bool(out, b.v),
        Int i => json::format_int(out, i.v),
        Num x => json::format_number(out, x.v),
        Str s => json::format_string(out, s.s),
        Arr a => {
            out.push('[');
            var first = true;
            json::each(n) { c =>
                if !first { out.push(','); }
                first = false;
                write_node(out, c);
            };
            out.push(']');
        },
        Obj o => {
            out.push('{');
            var first = true;
            json::each(n) { c =>
                if !first { out.push(','); }
                first = false;
                json::format_string(out, c.key);
                out.push(':');
                write_node(out, c);
            };
            out.push('}');
        },
    }
}

// Tier M's origin: the load sends it with every request.
fn mw_origin() -> const u8[:] { "https://app.example" }

// Each tier's handler. A response's JSON is built in a buffer of the
// request's own, which the data stack frees at the end of the request with
// one store: one kept in the worker and cleared per request is refused, the
// checker taking the loop's events for slices that may point into it.
// Tier M is tier A's routes behind a stack: Server-Timing without the access
// log, CORS, and a bearer token, which isn't checked further.
fn tier_a(cx, stack: bool) {
    var buf: u8[>..] = [];
    if stack {
        rest::timed(cx, false) {
            rest::cors(cx, rest::Cors { origins: mw_origin(), .. }) {
                rest::route(cx) { rest::bearer(cx) { token => arena(cx, buf); }; };
            };
        };
    } else {
        rest::route(cx) { arena(cx, buf); };
    }
}

fn tier_b(cx) {
    var buf: u8[>..] = [];
    rest::route(cx) { snow(cx, buf); };
}

fn tier_c(cx, writes: bool) {
    var buf: u8[>..] = [];
    rest::route(cx) { heavy(cx, buf, writes); };
}

fn tier_f(cx) { rest::route(cx) { micro(cx); }; }

// Tier R through the if chain, in one route, or the generator's router,
// which opens a route for each.
fn tier_r(cx, generated: bool) {
    if generated { api::dispatch(cx, cx.state); } else { rest::route(cx) { app::chain(cx, cx.state); }; }
}

thread_fn worker_f(cfg: http::Config, epoll: bool, bare: bool) {
    if bare && epoll { stopped(http::serve_epoll(cfg) { req, body, out => micro_bare(req, body, out) }); }
    else if bare { stopped(http::serve(cfg) { req, body, out => micro_bare(req, body, out) }); }
    else if epoll { stopped(rest::serve_epoll(cfg) { cx => tier_f(cx) }); }
    else { stopped(rest::serve(cfg) { cx => tier_f(cx) }); }
}

thread_fn worker_r(cfg: http::Config, epoll: bool, generated: bool) {
    if epoll { stopped(rest::serve_epoll(cfg) { cx => tier_r(cx, generated) }); }
    else { stopped(rest::serve(cfg) { cx => tier_r(cx, generated) }); }
}

thread_fn worker_a(cfg: http::Config, epoll: bool, stack: bool) {
    if epoll { stopped(rest::serve_epoll(cfg) { cx => tier_a(cx, stack) }); }
    else { stopped(rest::serve(cfg) { cx => tier_a(cx, stack) }); }
}

thread_fn worker_b(cfg: http::Config, epoll: bool) {
    if epoll { stopped(rest::serve_epoll(cfg, Snow { .. }) { cx => tier_b(cx) }); }
    else { stopped(rest::serve(cfg, Snow { .. }) { cx => tier_b(cx) }); }
}

thread_fn worker_c(cfg: http::Config, epoll: bool, writes: bool) {
    if epoll { stopped(rest::serve_epoll(cfg, Heavy { .. }) { cx => tier_c(cx, writes) }); }
    else { stopped(rest::serve(cfg, Heavy { .. }) { cx => tier_c(cx, writes) }); }
}

fn stopped(e: http::Error) {
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

fn main() {
    let argv = args();
    var port: i32 = 8080;
    if argv.len > 1 {
        let p, ok = parse_int(argv[1]);
        guard ok && p > 0 && p < 65536 else { abort("usage: rest [port]"); }
        port = p as i32;
    }
    var dir: u8[>..] = [];
    if !env("REST_DATA", dir) { dir.append("build/rest"); }
    var tier: u8[>..] = [];
    if !env("TIER", tier) { tier.append("a"); }
    var mode: u8[>..] = [];
    template = env("JSON", mode) && mode == "template";
    if tier == "a" || tier == "m" {
        load_items(dir);
        load_users(dir);
        if template { prebuild(); }
    } else if tier == "b" {
        load_orgs(dir);
        load_people(dir);
        load_entries(dir);
        if template { prebuild_snow(); }
    } else if tier == "c" || tier == "d" {
        load_heavy(dir);
        if template { prebuild_heavy(); }
    } else if tier != "f" && tier != "r" {
        abort("TIER is a, b, c, d, f, m, or r");
    }
    // Tier F on goose-http alone, and tier R through the generated router.
    var choice: u8[>..] = [];
    let bare = env("BARE", choice) && choice == "1";
    choice.clear();
    let generated = env("ROUTER", choice) && choice == "gen";
    let writes = tier == "d";
    var workers: u8[>..] = [];
    var n: i64 = 0;
    if env("WORKERS", workers) {
        let w, ok = parse_int(workers);
        if ok && w > 0 { n = w; }
    }
    var loop_name: u8[>..] = [];
    let epoll = env("LOOP", loop_name) && loop_name == "epoll";
    let cfg = http::Config { port: port, workers: n, max_body: if writes { IMPORT_LIMIT } else { http::MAX_BODY }, .. };
    let s = http::stop_on_signals();
    guard s == 0 else { stopped(http::Error { call: "sigaction", code: -s }); }
    let count = http::worker_count(cfg);
    print("rest: tier ", tier, ", ", items.len + entries.len + bookings.len + visits.len, " records, ", count, " workers on port ", port,
          if epoll { ", epoll" } else { ", uring" }, if template { ", template" } else { ", serialize" });
    var ids: i64[>..] = [];
    for i in count {
        ids.push(if tier == "f" { thread_spawn(worker_f, cfg, epoll, bare) }
                 else if tier == "r" { thread_spawn(worker_r, cfg, epoll, generated) }
                 else if tier == "b" { thread_spawn(worker_b, cfg, epoll) }
                 else if tier == "c" || writes { thread_spawn(worker_c, cfg, epoll, writes) }
                 else { thread_spawn(worker_a, cfg, epoll, tier == "m") });
    }
    for id in ids { thread_wait(id); }
}
