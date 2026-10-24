// goose-http's REST benchmark server on Plod: the same routes,
// records, and JSON as goose-http's bench/rest/goose at the pin, served through
// plod::serve, plod::routes for tiers A, F, and M and an http::router chain for
// the others, plod's extractors, its bearer
// middleware, and plod::fail with each tier's error shape (error_body below).
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
//   REST_DATA=DIR TIER=a|b|c|d WORKERS=n [LOOP=epoll] [JSON=template] [SECURITY=1] rest [port]
//
// TIER picks the dataset to load, tier A's by default. JSON=template answers
// from each record's JSON, written once at startup, with the per-request
// values added, where the default writes each response's JSON from the
// records. Tier D's answers are written the one way, as each is new.
// SECURITY=1 wraps tier A's routes in security_headers with the API preset,
// prepared once per worker at startup.
//
// The records, their JSON, and tier D's work on a body are goose-http's
// bench/rest/goose/app.goose, which goose-http's own server serves too; this
// file is what the benchmark compares: the routes, the extractors, the
// middleware, the error shapes, the loader, the workers, and main.
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../../";
import http.bench.rest.goose.app;
// app.goose's templates use the store, which app.goose can't import itself
// when a package imports it (docs/goose-findings.md).
import http.store;
import .github_app;
import .github_gen;

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

let SESSION_COOKIE = "__Secure-better-auth.session_token";

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

// The person the session cookie names, or -1.
fn person_of(cx) -> i64 {
    let v, has = plod::cookie(cx, SESSION_COOKIE);
    guard has && v.len > 65 && v[64] == '.' else { return -1; }
    let token = v[..64];
    let k = lower_bound(by_token) { compare(people[it].token, token) < 0 };
    return if k < by_token.len && people[by_token[k]].token == token { by_token[k] } else { -1 };
}

// Tier B's per-request state. Its error_body writes snowtime's two shapes:
// {"error":{"message"}} for the codes below, and {"error":{"code","key"}},
// the code named by the status, for the rest.
struct Snow { unused: bool = false }

fn plod::error_body(body: u8[>..]&, st: const Snow&, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
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

fn invalid(cx) { plod::fail(cx, 400, "invalid_input"); }

// GET .../entries: the entries of userId, or of the caller, that overlap
// [from, to), newest first, as listEntries selects them.
fn list_entries(cx, p: Person, m: Member, buf: u8[>..]&) {
    let fs, has_from = plod::query(cx, "from");
    let from, from_ok = parse_iso(fs);
    let ts, has_to = plod::query(cx, "to");
    let to, to_ok = parse_iso(ts);
    guard has_from && from_ok && has_to && to_ok && to > from && to - from <= 93 * DAY else { invalid(cx); }
    var who = person_index(p.id);
    let uid, has_user = plod::query(cx, "userId");
    if has_user {
        guard is_uuid7(uid) else { invalid(cx); }
        if uid != p.id {
            guard is_admin(m) else { plod::fail(cx, 403, "entries_forbidden"); }
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
    plod::json_bytes(cx, 200, buf);
}

fn list_projects(cx, p: Person, m: Member, buf: u8[>..]&) {
    let v, has = plod::query(cx, "includeArchived");
    guard !has || v == "true" || v == "false" else { invalid(cx); }
    let archived = has && v == "true";
    let o = orgs[m.org];
    buf.push('[');
    var n = 0;
    for i in o.first..o.first + o.count {
        let j = projects[i];
        if (archived || j.archived < 0) && sees(p, m, j) {
            if n > 0 { buf.push(','); }
            if template { http::store_append(tpl.project, project_at[i], project_at[i + 1], buf); } else { project_full(buf, j); }
            n++;
        }
    }
    buf.push(']');
    plod::json_bytes(cx, 200, buf);
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
    let body = plod::body(cx);
    guard is_json(body) else { plod::fail(cx, 400, "not_json"); }
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
    guard i >= 0 && entries[i].org == m.org else { plod::fail(cx, 404, "entry_not_found"); }
    guard people[entries[i].user].id == p.id || is_admin(m) else { plod::fail(cx, 403, "entry_forbidden"); }
    if has { snow_entry_as(buf, i, description); } else { snow_entry(buf, i); }
    plod::json_bytes(cx, 200, buf);
}

// POST .../timer/start: the new entry, started now, and the timer it
// stopped, the caller's running one, or null.
fn start_timer(cx, u: i64, m: Member, buf: u8[>..]&) {
    let body = plod::body(cx);
    guard is_json(body) else { plod::fail(cx, 400, "not_json"); }
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
        guard j >= 0 && sees(p, m, projects[j]) else { plod::fail(cx, 404, "project_not_found"); }
        guard projects[j].archived < 0 else { plod::fail(cx, 409, "project_archived"); }
    }
    guard entry_index(id) < 0 else { plod::fail(cx, 409, "entry_id_taken"); }
    let now = now_ms();
    buf.append("{\"started\":{\"id\":");
    http::json_string(buf, id);
    buf.append(",\"organizationId\":");
    http::json_string(buf, orgs[m.org].id);
    buf.append(",\"userId\":");
    http::json_string(buf, p.id);
    buf.append(",\"projectId\":");
    string_or_null(buf, project);
    buf.append(",\"description\":");
    http::json_string(buf, description);
    buf.append(",\"ticket\":");
    string_or_null(buf, ticket);
    buf.append(",\"startedAt\":");
    iso_or_null(buf, now);
    buf.append(",\"stoppedAt\":null},\"stopped\":");
    if p.running >= 0 { snow_stopped(buf, p.running, now); } else { buf.append("null"); }
    buf.push('}');
    plod::json_bytes(cx, 200, buf);
}

// POST /timer/stop: the caller's running entry, stopped now. An id the
// dataset doesn't have is taken for a timer started with it, as timer start
// answered it: a uuidv7 made in the last day.
fn stop_timer(cx, u: i64, buf: u8[>..]&) {
    let body = plod::body(cx);
    guard is_json(body) else { plod::fail(cx, 400, "not_json"); }
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
            else { plod::fail(cx, 404, "timer_not_running"); }
        buf.append("{\"id\":");
        http::json_string(buf, id);
        buf.append(",\"organizationId\":");
        http::json_string(buf, orgs[p.active].id);
        buf.append(",\"userId\":");
        http::json_string(buf, p.id);
        buf.append(",\"projectId\":null,\"description\":\"\",\"ticket\":null,\"startedAt\":");
        iso_or_null(buf, started);
        buf.append(",\"stoppedAt\":");
        iso_or_null(buf, min(max(now, started + 1), started + DAY));
        buf.push('}');
    }
    plod::json_bytes(cx, 200, buf);
}

// The caller, whom the session cookie names, or 401.
fn signed_in(cx) -> i64 {
    let u = person_of(cx);
    guard u >= 0 else { plod::fail(cx, 401, "sign_in_required"); }
    return u;
}

// The caller's membership of the organization the path names, or 403.
fn member(cx, r: const http::Router&, p: Person) -> Member {
    let k = membership(p, plod::param(cx, r, "org"));
    guard k >= 0 else { plod::fail(cx, 403, "not_organization_member"); }
    return p.orgs[k];
}

// A write's guard: Origin must be the app's, as snowtime's CSRF check has it.
fn same_origin(cx) {
    let origin, has = plod::header(cx, "origin");
    guard has && origin == APP_URL else { plod::fail(cx, 403, "cross_origin"); }
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
        else if template { http::store_append(tpl.session, session_at[u], session_at[u + 1], buf); }
        else { session_open(buf, people[u]); }
        plod::json_bytes(cx, 200, buf);
    } else if http::on(r, "GET", "/api/v1/timer") {
        let u = signed_in(cx);
        let p = people[u];
        if template { http::store_append(tpl.timer, timer_at[u], timer_at[u + 1], buf); }
        else if p.running >= 0 { timer_full(buf, entries[p.running]); }
        else { buf.append("null"); }
        plod::json_bytes(cx, 200, buf);
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
        patch_entry(cx, plod::param(cx, r, "id"), p, member(cx, r, p), buf);
    } else if http::on(r, "POST", "/api/v1/organizations/:org/timer/start") {
        same_origin(cx);
        let u = signed_in(cx);
        start_timer(cx, u, member(cx, r, people[u]), buf);
    } else {
        plod::fail(cx, 404, "no_such_call");
    }
}

// Tier C, a clinic's schedule and records, under /api/v2. A request needs a
// bearer token shaped as a JWT, which isn't verified. Ids are 1, 2, ... in
// each file, and the schedule's days are UTC's.

// Tier D's routes that read their body in pieces (Heavy.use).
enum Use {
    None,
    Import,
    Attachment,
}

// Tiers C and D's per-request state: what a tier D route waits on, and the
// spool it reads into (app.goose's spools), or -1. Its error_body writes
// {"error", "status"}, with the code each status has in the clinic's API,
// whatever code Plod or a route gave.
struct Heavy {
    use: Use = Use.None,
    spool: i64 = -1,
}

fn plod::error_body(body: u8[>..]&, st: const Heavy&, status: i32, code: const u8[:], detail: const u8[:], at: i64) {
    let name = if status == 400 { "bad_request" } else if status == 401 { "unauthorized" }
               else if status == 404 { "not_found" } else if status == 405 { "method_not_allowed" }
               else if status == 413 { "payload_too_large" } else if status == 415 { "unsupported_media_type" }
               else { code };
    format(body, "{\"error\":\"", name, "\",\"status\":", status, "}");
}

fn bad_request(cx) { plod::fail(cx, 400, "bad_request"); }

// A byte that is neither base64url nor '.', and '.', for find_any, which
// scans 16 bytes at a time: a byte loop over tier C's 560-byte tokens took
// over a quarter of a request's cycles.
let NOT_JWT = not_jwt_set();
let DOT = byte_set(".");

fn not_jwt_set() -> ByteSet {
    var m = [true; 256];
    for c in 256 {
        if c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_' ||
           c == '.' {
            m[c] = false;
        }
    }
    return byte_set(m);
}

// Whether t is a token of three base64url segments, as a JWT is.
fn jwt_shaped(t: const u8[:]) -> bool {
    guard find_any(t, NOT_JWT) < 0 else { return false; }
    let a = find_any(t, DOT);
    guard a > 0 else { return false; }
    let rest = t[a + 1..];
    let b = find_any(rest, DOT);
    return b > 0 && b + 1 < rest.len && find_any(rest[b + 1..], DOT) < 0;
}

// plod::bearer, with a token shaped as a JWT, which isn't verified.
inline fn authed<F>(cx) {
    plod::bearer(cx) { token =>
        guard jwt_shaped(token) else { plod::invalid_token(cx); }
        F();
    };
}

// A start and an end day, end after start and at most 31 days on, and the
// staff of a list of their ids as bits, or 400.
fn range_of(cx) -> i64, i64, i64 {
    let s, has_start = plod::query(cx, "start");
    let e, has_end = plod::query(cx, "end");
    let list, has_staff = plod::query(cx, "staff");
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
            if template { http::store_append(tpl.booking, booking_at[i], booking_at[i + 1], buf); } else { booking_full(buf, i); }
            n++;
        }
        i++;
    }
    buf.append("],\"count\":");
    format(buf, n);
    buf.push('}');
    plod::json_bytes(cx, 200, buf);
}

fn list_shifts(cx, buf: u8[>..]&) {
    let start, end, mask = range_of(cx);
    buf.append("{\"shifts\":[");
    var n = 0;
    var i = lower_bound(shifts) { it.start < start };
    while i < shifts.len && shifts[i].start < end {
        if (mask >> shifts[i].staff) & 1 != 0 {
            if n > 0 { buf.push(','); }
            if template { http::store_append(tpl.shift, shift_at[i], shift_at[i + 1], buf); } else { shift_full(buf, i); }
            n++;
        }
        i++;
    }
    buf.append("],\"count\":");
    format(buf, n);
    buf.push('}');
    plod::json_bytes(cx, 200, buf);
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
            if template { http::store_append(tpl.note, note_at[j], note_at[j + 1], buf); } else { case_note_full(buf, notes[j]); }
            n++;
        }
    }
    buf.append("]}");
    plod::json_bytes(cx, 200, buf);
}

// The client's completed visits, newest first, up to limit, and how many
// there are.
fn client_history(cx, c: i64, buf: u8[>..]&) {
    var limit = 20;
    let v, has = plod::query(cx, "limit");
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
    plod::json_bytes(cx, 200, buf);
}

// GET /schedule/version: the schedule's version, the minutes since
// version_epoch, and when it changed to it.
fn schedule_version(cx, buf: u8[>..]&) {
    let since, has = plod::query(cx, "since");
    let n, ok = parse_int(since);
    guard has && ok && n >= 0 else { bad_request(cx); }
    let version = (now_ms() - version_epoch) / MINUTE;
    buf.append("{\"version\":");
    format(buf, version);
    buf.append(",\"changedAt\":");
    iso_or_null(buf, version_epoch + version * MINUTE);
    buf.push('}');
    plod::json_bytes(cx, 200, buf);
}

// The record of the path's id among n, or 404.
fn record_of(cx, r: const http::Router&, n: i64) -> i64 {
    let i = index_of(plod::param(cx, r, "id"), n);
    guard i >= 0 else { plod::fail(cx, 404, "not_found"); }
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
            if template { http::store_append(tpl.client, client_at[c], client_at[c + 1], buf); } else { client_full(buf, c); }
            plod::json_bytes(cx, 200, buf);
        };
    } else if writes && http::on(r, "POST", "/api/v3/imports") {
        authed(cx) { import_csv(cx); };
    } else if writes && http::on(r, "POST", "/api/v3/attachments") {
        authed(cx) { attach(cx); };
    } else if writes && http::on(r, "POST", "/api/v3/bookings/batch") {
        authed(cx) { batch(cx, buf); };
    } else if writes && http::on(r, "POST", "/api/v3/forms") {
        authed(cx) { form(cx, buf); };
    } else {
        plod::fail(cx, 404, "not_found");
    }
}

// Tier D, writes with large bodies, under /api/v3, served beside tier C's
// reads for the mixed run. Each answer is computed from the body alone
// (app.goose), and the data doesn't change. The CSV and the multipart body
// are read in pieces as they arrive, through plod::body_in_pieces, as
// goose-http's server reads them; the batch and the form, of at most 1 MB
// and 64 KB, are gathered whole by plod::body.

let IMPORT_LIMIT: i64 = 16 * 1024 * 1024;
let BATCH_LIMIT: i64 = 1024 * 1024;
let FORM_LIMIT: i64 = 64 * 1024;

// Leaves the route with 415 unless the request's body is of type t.
fn typed(cx, t: const u8[:]) {
    guard http::has_type(cx.req, t) else { plod::fail(cx, 415, "unsupported_media_type"); }
}

// A write's answer, from the status and JSON app.goose's answers give: 0 for
// a body that isn't one.
fn answer(cx, status: i32, buf: const u8[:]) {
    guard status != 0 else { bad_request(cx); }
    plod::json_bytes(cx, status, buf);
}

fn release(cx) {
    let k = cx.state.spool;
    guard k >= 0 else { return; }
    let sp .= spools[k];
    if sp.cap > 0 { spill.free_slice(spill[sp.at..sp.at + sp.cap]); }
    spools.free(k);
    cx.state.spool = -1;
}

// POST /imports: the CSV's rows, and each column's count and sum. Its
// pieces go to resume(Use.Import).
fn import_csv(cx) {
    typed(cx, "text/csv");
    plod::body_in_pieces(cx, IMPORT_LIMIT, Use.Import);
    cx.state.spool = spools.alloc_index(Spool { .. });
}

// The spool is released before the route answers, as plod::fail leaves at
// once.
fn resume(u: Use.Import, cx) {
    if cx.kind == http::BODY {
        csv_piece(spools[cx.state.spool].csv, cx.body);
    } else if cx.kind == http::END {
        var buf: u8[>..] = [];
        let status = import_answer(spools[cx.state.spool].csv, buf);
        release(cx);
        answer(cx, status, buf);
    } else if cx.kind == http::CLOSED {
        release(cx);
    }
}

// POST /attachments: the text fields, and the file's size and Adler-32. Its
// pieces go to resume(Use.Attachment). A route that fails after
// plod::body_in_pieces gets CLOSED, which releases the spool.
fn attach(cx) {
    typed(cx, "multipart/form-data");
    plod::body_in_pieces(cx, IMPORT_LIMIT, Use.Attachment);
    cx.state.spool = spools.alloc_index(Spool { .. });
    guard http::start_multipart(cx.req, spools[cx.state.spool].parts) else { bad_request(cx); }
}

// A malformed body is answered at its END, as goose-http's server answers
// it.
fn resume(u: Use.Attachment, cx) {
    if cx.kind == http::BODY {
        attach_piece(spools[cx.state.spool], cx.body);
    } else if cx.kind == http::END {
        var buf: u8[>..] = [];
        let status = attach_answer(spools[cx.state.spool], buf);
        release(cx);
        answer(cx, status, buf);
    } else if cx.kind == http::CLOSED {
        release(cx);
    }
}

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

// POST /bookings/batch: each booking's new id, or 422 with the field errors.
fn batch(cx, buf: u8[>..]&) {
    typed(cx, "application/json");
    let status = bookings_batch(plod::body(cx, BATCH_LIMIT), buf);
    answer(cx, status, buf);
}

// POST /forms: the form's fields, decoded, in order.
fn form(cx, buf: u8[>..]&) {
    typed(cx, "application/x-www-form-urlencoded");
    let status = form_answer(plod::body(cx, FORM_LIMIT), buf);
    answer(cx, status, buf);
}

// Tier A's routes, in Plod's own error shape, inside plod::routes.
fn arena(cx, buf: u8[>..]&) {
    plod::get(cx, "/api/items/:id") {
        let i = index_of(plod::param(cx, "id"), item_count());
        guard i >= 0 else { plod::fail(cx, 404, "item_not_found"); }
        if template { http::store_append(tpl.item, item_at[i], item_at[i + 1], buf); } else { item_open(buf, items[i]); }
        served(buf);
        plod::json_bytes(cx, 200, buf);
    };
    plod::get(cx, "/api/me") {
        let id, has = plod::header(cx, "x-user-id");
        let i = if has { index_of(id, user_count()) } else { -1 };
        guard i >= 0 else { plod::fail(cx, 401, "unknown_user"); }
        if template { http::store_append(tpl.user, user_at[i], user_at[i + 1], buf); } else { user_open(buf, users[i]); }
        served(buf);
        plod::json_bytes(cx, 200, buf);
    };
    plod::post(cx, "/api/items/:id") {
        let i = index_of(plod::param(cx, "id"), item_count());
        guard i >= 0 else { plod::fail(cx, 404, "item_not_found"); }
        guard valid_write(plod::body(cx)) else { plod::fail(cx, 422, "invalid_item"); }
        plod::empty(cx, 204);
    };
}

// Tier F, the bun-http-framework-benchmark's three routes (bench/rest/tiers).
fn micro(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/") { plod::text(cx, 200, "Hi"); };
        plod::get(cx, "/id/:id") {
            var b: u8[>..] = [];
            b.append(plod::param(cx, "id"));
            b.push(' ');
            let name, has = plod::query(cx, "name");
            b.append(name);
            http::start(cx.out, 200);
            http::field(cx.out, "x-powered-by", "benchmark");
            http::finish(cx.out, "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ", b);
        };
        plod::post(cx, "/json") {
            var out: u8[>..] = [];
            guard echo(plod::body(cx), out) else { plod::fail(cx, 400, "invalid_body"); }
            plod::json_bytes(cx, 200, out);
        };
    };
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
        Str s => http::json_string(out, s.s),
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
                http::json_string(out, c.key);
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
        plod::timed(cx, false) {
            plod::cors(cx, plod::Cors { origins: mw_origin(), .. }) {
                plod::routes(cx) { cx => plod::bearer(cx) { token => arena(cx, buf); }; };
            };
        };
    } else {
        plod::routes(cx) { cx => arena(cx, buf); };
    }
}

fn tier_b(cx) {
    var buf: u8[>..] = [];
    plod::route(cx) { snow(cx, buf); };
}

fn tier_c(cx, writes: bool) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
        return;
    }
    var buf: u8[>..] = [];
    plod::route(cx) { heavy(cx, buf, writes); };
}

fn tier_f(cx) { micro(cx); }

// Tier R through the if chain, in one route, or the generator's router,
// which opens a route for each.
fn tier_r(cx, generated: bool) {
    if generated { api::dispatch(cx); } else { plod::route(cx) { app::chain(cx); }; }
}

thread_fn worker_f(cfg: http::Config, epoll: bool, bare: bool) {
    take_set();
    if bare && epoll { stopped(http::serve_epoll(cfg) { req, body, out => micro_bare(req, body, out) }); }
    else if bare { stopped(http::serve(cfg) { req, body, out => micro_bare(req, body, out) }); }
    else if epoll { stopped(plod::serve_epoll(cfg) { cx => tier_f(cx) }); }
    else { stopped(plod::serve(cfg) { cx => tier_f(cx) }); }
}

thread_fn worker_r(cfg: http::Config, epoll: bool, generated: bool) {
    take_set();
    if epoll { stopped(plod::serve_epoll(cfg) { cx => tier_r(cx, generated) }); }
    else { stopped(plod::serve(cfg) { cx => tier_r(cx, generated) }); }
}

thread_fn worker_a(cfg: http::Config, epoll: bool, stack: bool, security: bool) {
    take_set();
    if security && !stack {
        let prepared = plod::prepare_security_headers(plod::security_api());
        if epoll {
            stopped(plod::serve_epoll(cfg) { cx =>
                plod::security_headers(cx, prepared) { tier_a(cx, false); };
            });
        } else {
            stopped(plod::serve(cfg) { cx =>
                plod::security_headers(cx, prepared) { tier_a(cx, false); };
            });
        }
    } else if epoll { stopped(plod::serve_epoll(cfg) { cx => tier_a(cx, stack) }); }
    else { stopped(plod::serve(cfg) { cx => tier_a(cx, stack) }); }
}

thread_fn worker_b(cfg: http::Config, epoll: bool) {
    take_set();
    var none = plod::NoState { .. };
    if epoll { stopped(plod::serve_epoll(cfg, none, Snow { .. }) { cx => tier_b(cx) }); }
    else { stopped(plod::serve(cfg, none, Snow { .. }) { cx => tier_b(cx) }); }
}

thread_fn worker_c(cfg: http::Config, epoll: bool, writes: bool) {
    take_set();
    var none = plod::NoState { .. };
    if epoll { stopped(plod::serve_epoll(cfg, none, Heavy { .. }) { cx => tier_c(cx, writes) }); }
    else { stopped(plod::serve(cfg, none, Heavy { .. }) { cx => tier_c(cx, writes) }); }
}

fn stopped(e: http::Error) {
    guard e.code != 0 else { return; }
    http::report(e);
    exit(1);
}

// A worker takes its records over the typed queues, not through
// thread_spawn, which would hold them twice for the worker's life: in the
// packet it copies the globals through, and on the worker's stacks
// (goose-http's docs/goose-findings.md). main spawns the workers, so the
// globals a spawn copies are main's, which are empty. The loader puts one
// set of the arrays and returns; the distributor takes it and puts one set
// per worker, which the worker takes into its globals: the runtime copies
// each straight onto its stack and frees the queue's copy. Arrays of one
// element type share a queue, so one thread takes at a time, a whole set:
// the distributor puts the next set only after a Taken. Ready tells main a
// set is on the queues. app.goose's hand_over and take_all put and take a
// set; the templates themselves are in the store, never on the queues
// (app.goose's share_templates).

// glibc's, as goose-http's server sets it: with M_MMAP_THRESHOLD set, malloc
// keeps serving each queue copy with its own mapping, which free unmaps.
// Left to adjust itself, glibc raises the threshold to the first such block
// freed, so the next sets come from an arena that keeps their pages.
extern fn mallopt(param: i32, value: i32) -> i32;
let M_MMAP_THRESHOLD: i32 = -3;
struct Ready { set: i64 }
struct Taken { set: i64 }

// A worker's: takes its set, and tells the distributor it may put the next.
fn take_set() {
    take_all();
    qput(Taken { set: 0 });
}

// Takes the set the loader put, and puts one copy of it for each worker main
// spawns, the next only once the last is taken. The loader has returned by
// then, so the files it read and parsed are unmapped, and startup's peak
// holds this set, one copy on the queues, and the workers'.
thread_fn distributor(count: i64) {
    take_all();
    for i in count {
        hand_over();
        qput(Ready { set: i });
        qget<Taken>();
    }
}

// Loads the records into this thread's globals and puts one set of them on
// the queues for the distributor (hand_over). The runtime never gives a data
// stack's pages back while its thread runs, so main would hold the records
// and the files they were read from for the program's life; a thread's
// return unmaps both. Tiers F and R load nothing, and hand over the empty
// set.
thread_fn loader(port: i32, tier: u8[..1], count: i64, epoll: bool) {
    var dir: u8[>..] = [];
    if !env("REST_DATA", dir) { dir.append("build/rest"); }
    var mode: u8[>..] = [];
    template = env("JSON", mode) && mode == "template";
    intern("");
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
    }
    print("rest: tier ", tier, ", ", items.len + entries.len + bookings.len + visits.len, " records, ", count, " workers on port ", port,
          if epoll { ", epoll" } else { ", uring" }, if template { ", template" } else { ", serialize" });
    // Each worker copies only what's left. Once the JSON is built, tiers A
    // and C read none of the strings, and tier A none of its records, whose
    // counts item_at and user_at keep; tier B's routes still compare ids.
    if template && tier != "b" {
        items.clear();
        users.clear();
        text.clear();
        words.clear();
    }
    share_templates();
    var lens: u8[>..] = [];
    if env("REST_LENS", lens) { print_lens(); }
    hand_over();
}

fn main() {
    let argv = args();
    var port: i32 = 8080;
    if argv.len > 1 {
        let p, ok = parse_int(argv[1]);
        guard ok && p > 0 && p < 65536 else { abort("usage: rest [port]"); }
        port = p as i32;
    }
    var name: u8[>..] = [];
    if !env("TIER", name) { name.append("a"); }
    guard name.len == 1 && position("abcdfmr", name[0]) >= 0 else { abort("TIER is a, b, c, d, f, m, or r"); }
    var tier: u8[..1] = "";
    tier.append(name);
    // Tier F on goose-http alone, and tier R through the generated router.
    var choice: u8[>..] = [];
    let bare = env("BARE", choice) && choice == "1";
    choice.clear();
    let generated = env("ROUTER", choice) && choice == "gen";
    choice.clear();
    let security = env("SECURITY", choice) && choice == "1";
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
    stopped(http::stop_on_signals());
    let count = http::worker_count(cfg);
    mallopt(M_MMAP_THRESHOLD, 131072);
    // main's record globals stay empty, so each spawn copies nothing of them.
    thread_wait(thread_spawn(loader, port, tier, count, epoll));
    let giving = thread_spawn(distributor, count);
    var ids: i64[>..] = [];
    for i in count {
        qget<Ready>();
        ids.push(if tier == "f" { thread_spawn(worker_f, cfg, epoll, bare) }
                 else if tier == "r" { thread_spawn(worker_r, cfg, epoll, generated) }
                 else if tier == "b" { thread_spawn(worker_b, cfg, epoll) }
                 else if tier == "c" || writes { thread_spawn(worker_c, cfg, epoll, writes) }
                 else { thread_spawn(worker_a, cfg, epoll, tier == "m", security) });
    }
    thread_wait(giving);
    for id in ids { thread_wait(id); }
}
