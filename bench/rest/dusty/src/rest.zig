// goose-http's REST tiers on dusty's router: what
// the tiers share, and tier A's routes.
//
// Each tier's module lists its routes as a table of method, path, and
// handler, the path in dusty's syntax with ":name" segments; main.zig mounts
// the tables of the tier it serves on dusty's router, under a group with the
// tier's middleware. A handler takes the request, reads what it needs
// through dusty (params, query, headers, cookies, body readers), and returns
// a Resp, which `action` turns into dusty's response.
//
// Tier A is HttpArena's production-stack application layer, tier B snowtime's
// k6 hot path (snow.zig), tier C a clinic's schedule and records (heavy.zig),
// and tier D writes with large bodies, served beside tier C (writes.zig).
//
//   REST_DATA=DIR TIER=a|b|c|d WORKERS=n [JSON=template] rest-dusty [port]
//
// Records are read from the dataset files with std.json into structs of the
// answers' shapes, times kept as the files write them, and serialized per
// request with std.json.Stringify, Zig's JSON library. JSON=template answers
// from each record's JSON, written once at startup, with the per-request
// values added. Tier D's answers are written the one way. A response's body
// is allocated from the request's arena, which dusty resets after the
// response.
const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("dusty");

pub const snow = @import("snow.zig");
pub const heavy = @import("heavy.zig");
pub const writes = @import("writes.zig");

// The server's context: dusty calls its notFound for a request no route
// takes, whatever its method.
pub const App = struct {
    pub fn notFound(_: *App, req: *http.Request, res: *http.Response) !void {
        try send(res, notFoundOf(req.url));
    }
};

pub const Router = http.Router(App);
pub const Middleware = http.Middleware(App);

// A route of a tier's table, with dusty's handler.
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: Router.Handler,
};

// A route whose handler returns a Resp.
pub fn route(method: http.Method, path: []const u8, comptime handler: fn (*http.Request) anyerror!Resp) Route {
    return .{ .method = method, .path = path, .handler = action(handler) };
}

// handler as dusty's action.
fn action(comptime handler: fn (*http.Request) anyerror!Resp) Router.Handler {
    return struct {
        fn run(_: *App, req: *http.Request, res: *http.Response) anyerror!void {
            try send(res, try handler(req));
        }
    }.run;
}

// A response: its status, whether its body is JSON, and whether the server
// closes the connection after it, rather than read the rest of a body.
pub const Resp = struct {
    status: u16,
    json: bool = false,
    close: bool = false,
    body: []const u8 = "",
};

pub fn empty(status: u16) Resp {
    return .{ .status = status };
}

pub fn jsonStatus(status: u16, body: []const u8) Resp {
    return .{ .status = status, .json = true, .body = body };
}

// 413, closing the connection rather than reading the rest.
pub const too_large: Resp = .{ .status = 413, .close = true };

pub fn send(res: *http.Response, r: Resp) !void {
    res.status = try http.Status.fromCode(r.status);
    if (r.json) try res.header("Content-Type", "application/json");
    res.body = r.body;
    if (r.close) {
        // dusty drains a body of a known length after the handler before it
        // sends the response, and the peer may never send the rest of one
        // refused for its length, so the response goes now.
        res.keepalive = false;
        try res.write();
    }
}

// The 404 of a path no route takes, in the shape of its tier's errors.
fn notFoundOf(target: []const u8) Resp {
    if (std.mem.startsWith(u8, target, "/api/v1/")) return snow.no_such_call;
    if (std.mem.startsWith(u8, target, "/api/v2/") or std.mem.startsWith(u8, target, "/api/v3/")) {
        return writes.err(404);
    }
    return empty(404);
}

// The request's body whole, read by dusty up to its max_body_size; null for
// one over it. A declared length over it is refused before the read, which
// would otherwise wait for bytes the peer may never send.
pub fn bodyOf(req: *http.Request) !?[]const u8 {
    if (req.content_length) |n| if (n > req.config.max_body_size) return null;
    const b = req.body() catch |e| switch (e) {
        error.BodyTooBig => return null,
        else => return e,
    };
    return b orelse "";
}

// A request's arena, which its response's body comes from, and the clock.
pub const Ctx = struct {
    arena: Allocator,
    io: std.Io,
};

pub fn ctxOf(req: *const http.Request) Ctx {
    return .{ .arena = req.arena, .io = req.io };
}

// What a response's body is written into.
pub const Out = std.Io.Writer.Allocating;

pub fn out(ctx: Ctx, capacity: usize) !Out {
    return Out.initCapacity(ctx.arena, capacity);
}

// The JSON writer over w, as the routes serialize with it.
pub fn stringify(w: *std.Io.Writer) std.json.Stringify {
    return .{ .writer = w };
}

// Appends s as a JSON string.
pub fn writeString(w: *std.Io.Writer, s: []const u8) !void {
    try std.json.Stringify.encodeJsonString(s, .{}, w);
}

// Appends s as a JSON string, each byte of it that isn't UTF-8 as U+FFFD, as
// Rust's from_utf8_lossy reads it.
pub fn writeLossy(w: *std.Io.Writer, s: []const u8) !void {
    if (std.unicode.utf8ValidateSlice(s)) return writeString(w, s);
    try w.writeByte('"');
    var i: usize = 0;
    while (i < s.len) {
        const n = std.unicode.utf8ByteSequenceLength(s[i]) catch 0;
        if (n == 0 or i + n > s.len or !std.unicode.utf8ValidateSlice(s[i .. i + n])) {
            try w.writeAll("\u{FFFD}");
            i += 1;
            continue;
        }
        try std.json.Stringify.encodeJsonStringChars(s[i .. i + n], .{}, w);
        i += n;
    }
    try w.writeByte('"');
}

// Writes each of v's fields as members of an open object, as serde's
// flatten does.
pub fn writeFields(jw: *std.json.Stringify, v: anytype) !void {
    inline for (std.meta.fields(@TypeOf(v))) |f| {
        try jw.objectField(f.name);
        try jw.write(@field(v, f.name));
    }
}

// v's JSON, allocated with a for a template.
pub fn marshal(a: Allocator, v: anytype) []u8 {
    return std.json.Stringify.valueAlloc(a, v, .{}) catch oom();
}

pub fn withoutBrace(v: []u8) []u8 {
    return v[0 .. v.len - 1];
}

pub fn oom() noreturn {
    fatal("out of memory", .{});
}

pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(1);
}

pub fn check(ok: bool, what: []const u8) void {
    if (!ok) fatal("{s}", .{what});
}

// The time in seconds and in ms since the epoch.
pub fn nowS(io: std.Io) i64 {
    return @divFloor(nowMs(io), 1000);
}

pub fn nowMs(io: std.Io) i64 {
    const now = std.Io.Timestamp.now(io, .real);
    return @intCast(@divFloor(now.nanoseconds, std.time.ns_per_ms));
}

pub const day: i64 = 86_400_000;
pub const minute: i64 = 60_000;

const Rating = struct {
    score: i64,
    count: i64,
};

const Item = struct {
    id: i64,
    name: []const u8,
    category: []const u8,
    price: i64,
    quantity: i64,
    active: bool,
    tags: []const []const u8,
    rating: Rating,
};

const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
    plan: []const u8,
};

// A record with servedAt after its fields, as one JSON object.
fn Served(comptime T: type) type {
    return struct {
        record: *const T,
        served_at: i64,

        pub fn jsonStringify(self: @This(), jw: *std.json.Stringify) !void {
            try jw.beginObject();
            try writeFields(jw, self.record.*);
            try jw.objectField("servedAt");
            try jw.write(self.served_at);
            try jw.endObject();
        }
    };
}

const Data = struct {
    items: []Item = &.{},
    users: []User = &.{},
    // JSON=template's records, each without its closing brace.
    item_json: [][]u8 = &.{},
    user_json: [][]u8 = &.{},
    template: bool = false,
};

pub var data: Data = .{};

// goose-http's tiers A to D, and goose-rest's F, R, and M (micro.zig).
pub const Tier = enum { a, b, c, d, f, r, m };

// The tier, the worker count, and the port, from TIER, WORKERS, and the
// first argument.
pub const Config = struct {
    tier: Tier,
    workers: u8,
    port: u16,
};

// Loads TIER's dataset from REST_DATA, and says so as server. a is the
// process's, and keeps the records.
pub fn init(a: Allocator, io: std.Io, env: *const std.process.Environ.Map, args: []const [:0]const u8, server: []const u8) Config {
    const dir = env.get("REST_DATA") orelse "build/rest";
    const name = env.get("TIER") orelse "a";
    const tier = std.meta.stringToEnum(Tier, name) orelse fatal("TIER is a, b, c, d, f, r, or m", .{});
    data.template = std.mem.eql(u8, env.get("JSON") orelse "", "template");
    const records = switch (tier) {
        .f, .r => 0,
        .a, .m => blk: {
            data.items = readJson([]Item, a, io, dir, "arena-items.json");
            data.users = readJson([]User, a, io, dir, "arena-users.json");
            if (data.template) {
                data.item_json = a.alloc([]u8, data.items.len) catch oom();
                for (data.items, data.item_json) |it, *j| j.* = withoutBrace(marshal(a, it));
                data.user_json = a.alloc([]u8, data.users.len) catch oom();
                for (data.users, data.user_json) |u, *j| j.* = withoutBrace(marshal(a, u));
            }
            break :blk data.items.len;
        },
        .b => snow.load(a, io, dir, data.template),
        .c, .d => heavy.load(a, io, dir, data.template),
    };
    var c: Config = .{ .tier = tier, .workers = @intCast(@min(std.Thread.getCpuCount() catch 1, 255)), .port = 8080 };
    if (env.get("WORKERS")) |v| c.workers = std.fmt.parseInt(u8, v, 10) catch fatal("WORKERS: {s}", .{v});
    if (args.len > 1) c.port = std.fmt.parseInt(u16, args[1], 10) catch fatal("port: {s}", .{args[1]});
    std.debug.print("{s}: tier {s}, {d} records, {d} workers on port {d}, {s}\n", .{
        server, name, records, c.workers, c.port, if (data.template) "template" else "serialize",
    });
    return c;
}

// The records of dataset file name, read with std.json.
pub fn readJson(comptime T: type, a: Allocator, io: std.Io, dir: []const u8, name: []const u8) T {
    const path = std.fmt.allocPrint(a, "{s}/{s}", .{ dir, name }) catch oom();
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited) catch |e|
        fatal("{s}: {t}; run goose-http's bench/rest/gen.goose", .{ path, e });
    return std.json.parseFromSliceLeaky(T, a, bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_if_needed,
    }) catch |e| fatal("{s}: {t}", .{ name, e });
}

// s as a number of decimal digits only, as Rust's parse takes one, but for a
// sign; null for an empty s, another byte, or an overflow.
pub fn parseDigits(s: []const u8) ?i64 {
    if (s.len == 0 or s.len > 18) return null;
    var v: i64 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + (c - '0');
    }
    return v;
}

// A decimal integer with an optional sign, as Rust's i64 parse takes one.
pub fn parseInt(s: []const u8) ?i64 {
    if (s.len > 0 and (s[0] == '-' or s[0] == '+')) {
        const v = parseDigits(s[1..]) orelse return null;
        return if (s[0] == '-') -v else v;
    }
    return parseDigits(s);
}

// id as a record's index, if it's one of n.
pub fn indexOf(id: []const u8, n: usize) ?usize {
    const s = if (id.len > 0 and id[0] == '+') id[1..] else id;
    const v = parseDigits(s) orelse return null;
    if (v < 1 or v > n) return null;
    return @intCast(v - 1);
}

// The path parameter the route names; the router has matched it, so it's
// there.
pub fn param(req: *const http.Request, name: []const u8) []const u8 {
    return req.params.get(name).?;
}

fn hexDigit(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

// s with its percent-escapes decoded, and '+' as a space for a form, or null
// for a '%' without two hex digits after it.
pub fn decode(a: Allocator, s: []const u8, form: bool) !?[]const u8 {
    if (std.mem.indexOfScalar(u8, s, '%') == null and (!form or std.mem.indexOfScalar(u8, s, '+') == null)) return s;
    var b: std.ArrayList(u8) = try .initCapacity(a, s.len);
    var i: usize = 0;
    while (i < s.len) {
        const c = s[i];
        if (c == '%') {
            if (i + 2 >= s.len) return null;
            const hi = hexDigit(s[i + 1]) orelse return null;
            const lo = hexDigit(s[i + 2]) orelse return null;
            b.appendAssumeCapacity(hi * 16 + lo);
            i += 3;
        } else {
            b.appendAssumeCapacity(if (form and c == '+') ' ' else c);
            i += 1;
        }
    }
    return b.items;
}

// The whole of data as one JSON value, or null for anything else, trailing
// bytes included.
pub fn parseWhole(a: Allocator, body: []const u8) ?std.json.Value {
    return std.json.parseFromSliceLeaky(std.json.Value, a, body, .{}) catch null;
}

pub fn trimWs(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\n\r");
}

// Whether body's JSON value, if any, is an object.
pub fn isObject(body: []const u8) bool {
    const s = std.mem.trimStart(u8, body, " \t\n\r");
    return s.len > 0 and s[0] == '{';
}

// ms since the epoch as JavaScript's toISOString writes it, from Howard
// Hinnant's civil_from_days.
pub fn iso(ms: i64) [24]u8 {
    const digits = struct {
        fn f(b: []u8, v0: i64) void {
            var v = v0;
            var k = b.len;
            while (k > 0) {
                k -= 1;
                b[k] = '0' + @as(u8, @intCast(@mod(v, 10)));
                v = @divTrunc(v, 10);
            }
        }
    }.f;
    const d = @divFloor(ms, day);
    const t = ms - d * day;
    const z = d + 719_468;
    const era = @divTrunc(if (z >= 0) z else z - 146_096, 146_097);
    const doe = z - era * 146_097;
    const yoe = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146_096), 365);
    const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp = @divTrunc(5 * doy + 2, 153);
    const m = if (mp < 10) mp + 3 else mp - 9;
    var b: [24]u8 = "0000-00-00T00:00:00.000Z".*;
    digits(b[0..4], yoe + era * 400 + @as(i64, if (m <= 2) 1 else 0));
    digits(b[5..7], m);
    digits(b[8..10], doy - @divTrunc(153 * mp + 2, 5) + 1);
    digits(b[11..13], @divTrunc(t, 3_600_000));
    digits(b[14..16], @mod(@divTrunc(t, minute), 60));
    digits(b[17..19], @mod(@divTrunc(t, 1000), 60));
    digits(b[20..23], @mod(t, 1000));
    return b;
}

// A time as a JSON string, for a template's splice.
pub fn writeIso(w: *std.Io.Writer, ms: i64) !void {
    const s = iso(ms);
    try w.writeByte('"');
    try w.writeAll(&s);
    try w.writeByte('"');
}

// A time as a string from a, for a struct to serialize.
pub fn isoString(a: Allocator, ms: i64) ![]const u8 {
    const s = iso(ms);
    return a.dupe(u8, &s);
}

fn numberAt(s: []const u8, at: usize, n: usize) i64 {
    var v: i64 = 0;
    for (s[at .. at + n]) |c| {
        if (c < '0' or c > '9') return -1;
        v = v * 10 + (c - '0');
    }
    return v;
}

// Howard Hinnant's days_from_civil.
pub fn daysFrom(y: i64, m: i64, d: i64) i64 {
    const yy = if (m <= 2) y - 1 else y;
    const era = @divTrunc(if (yy >= 0) yy else yy - 399, 400);
    const yoe = yy - era * 400;
    const doy = @divTrunc(153 * (if (m > 2) m - 3 else m + 9) + 2, 5) + d - 1;
    return era * 146_097 + yoe * 365 + @divTrunc(yoe, 4) - @divTrunc(yoe, 100) + doy - 719_468;
}

// "YYYY-MM-DDTHH:MM:SS.sssZ", or without the milliseconds, as ms since the
// epoch.
pub fn parseIso(s: []const u8) ?i64 {
    const n = s.len;
    if (!((n == 24 or n == 20) and s[4] == '-' and s[7] == '-' and s[10] == 'T' and s[13] == ':' and
        s[16] == ':' and s[n - 1] == 'Z')) return null;
    const y = numberAt(s, 0, 4);
    const m = numberAt(s, 5, 2);
    const d = numberAt(s, 8, 2);
    const h = numberAt(s, 11, 2);
    const mi = numberAt(s, 14, 2);
    const sec = numberAt(s, 17, 2);
    const ms: i64 = if (n == 24 and s[19] == '.') numberAt(s, 20, 3) else if (n == 20) 0 else -1;
    const ok = y >= 0 and m >= 1 and m <= 12 and d >= 1 and d <= 31 and h >= 0 and h < 24 and mi >= 0 and
        mi < 60 and sec >= 0 and sec < 60 and ms >= 0;
    if (!ok) return null;
    return daysFrom(y, m, d) * day + ((h * 60 + mi) * 60 + sec) * 1000 + ms;
}

// "YYYY-MM-DD" as ms since the epoch at its midnight in UTC.
pub fn parseDay(s: []const u8) ?i64 {
    if (!(s.len == 10 and s[4] == '-' and s[7] == '-')) return null;
    const y = numberAt(s, 0, 4);
    const m = numberAt(s, 5, 2);
    const d = numberAt(s, 8, 2);
    if (!(y >= 0 and m >= 1 and m <= 12 and d >= 1 and d <= 31)) return null;
    return daysFrom(y, m, d) * day;
}

// A file's time, which must be toISOString's.
pub fn mustIso(s: []const u8, what: []const u8) i64 {
    return parseIso(s) orelse fatal("{s}: {s}", .{ what, s });
}

// Prebuilt records, the ones listed, joined with ',' between open and close.
pub fn join(w: *std.Io.Writer, open: []const u8, parts: []const []u8, listed: []const usize, close: []const u8) !void {
    try w.writeAll(open);
    for (listed, 0..) |i, k| {
        if (k > 0) try w.writeByte(',');
        try w.writeAll(parts[i]);
    }
    try w.writeAll(close);
}

// Tier A's routes, which tier M serves too. Tier A doesn't read the token
// every request carries.
pub const routes = [_]Route{
    route(.get, "/api/items/:id", getItem),
    route(.post, "/api/items/:id", postItem),
    route(.get, "/api/me", getMe),
};

// A record's response: its prebuilt JSON with servedAt spliced in, or the
// record and servedAt serialized.
fn served(ctx: Ctx, record: anytype, prebuilt: ?[]const u8) !Resp {
    const now = nowS(ctx.io);
    var o = try out(ctx, if (prebuilt) |p| p.len + 24 else 512);
    if (prebuilt) |p| {
        try o.writer.writeAll(p);
        try o.writer.print(",\"servedAt\":{d}}}", .{now});
    } else {
        var jw = stringify(&o.writer);
        try jw.write(Served(@TypeOf(record.*)){ .record = record, .served_at = now });
    }
    return jsonStatus(200, o.written());
}

// A write's body: an object whose name, price, and quantity are each absent,
// null, or of their type.
fn validWrite(a: Allocator, body: []const u8) bool {
    if (body.len == 0 or body[0] != '{') return false;
    const v = parseWhole(a, body) orelse return false;
    if (v != .object) return false;
    var it = v.object.iterator();
    while (it.next()) |e| {
        const x = e.value_ptr.*;
        if (x == .null) continue;
        const k = e.key_ptr.*;
        if (std.mem.eql(u8, k, "name")) {
            if (x != .string) return false;
        } else if (std.mem.eql(u8, k, "price") or std.mem.eql(u8, k, "quantity")) {
            if (x != .integer) return false;
        }
    }
    return true;
}

fn getItem(req: *http.Request) !Resp {
    const i = indexOf(param(req, "id"), data.items.len) orelse return empty(404);
    return served(ctxOf(req), &data.items[i], if (data.template) data.item_json[i] else null);
}

fn postItem(req: *http.Request) !Resp {
    _ = indexOf(param(req, "id"), data.items.len) orelse return empty(404);
    const body = try bodyOf(req) orelse return too_large;
    return empty(if (validWrite(req.arena, body)) 204 else 422);
}

fn getMe(req: *http.Request) !Resp {
    const v = req.headers.get("X-User-Id") orelse return empty(401);
    const i = indexOf(v, data.users.len) orelse return empty(401);
    return served(ctxOf(req), &data.users[i], if (data.template) data.user_json[i] else null);
}
