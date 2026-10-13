// The REST benchmark (goose-http's task 021) on dusty and the zio runtime,
// configured as goose-http's bench/dusty serves /plaintext and /json: one
// dusty Server on a work-stealing zio runtime with WORKERS executors, and the
// Server and Date fields.
//
// Unlike goose-http's bench/rest/dusty, which gives every path to one handler
// that matches paths itself, each route is registered on dusty's router with
// its path parameters, under a group per tier with the tier's middleware:
//
//   tier a   /           rest.routes
//   tier b   /api/v1     snow.routes, behind snow.SameOrigin
//   tier c   /api/v2     heavy.routes, behind heavy.Bearer
//   tier d   /api/v2 and /api/v3, writes.routes, both behind heavy.Bearer
//
// Stamp, the Server and Date fields, is global, so dusty runs it for a request
// no route takes too; that request gets App.notFound's 404.
//
//     REST_DATA=DIR TIER=a|b|c|d WORKERS=n [JSON=template] rest-dusty [port]

const std = @import("std");
const zio = @import("zio");
const http = @import("dusty");
const rest = @import("rest.zig");

// The Date field, formatted once a second per thread. It's copied into the
// request's arena: the response is sent after the handler returns, by which
// time another handler on this thread may have rewritten the buffer.
threadlocal var date_buf: [29]u8 = undefined;
threadlocal var date_secs: i64 = -1;

fn date(req: *http.Request) ![]const u8 {
    const now = std.Io.Timestamp.now(req.io, .real);
    const secs: i64 = @intCast(@divFloor(now.nanoseconds, std.time.ns_per_s));
    if (secs != date_secs) {
        const es = std.time.epoch.EpochSeconds{ .secs = @intCast(secs) };
        const day = es.getEpochDay();
        const yd = day.calculateYearDay();
        const md = yd.calculateMonthDay();
        const ds = es.getDaySeconds();
        // 1970-01-01 was a Thursday.
        const wd = (day.day + 4) % 7;
        const names = "SunMonTueWedThuFriSat";
        const months = "JanFebMarAprMayJunJulAugSepOctNovDec";
        const m = (@as(usize, @intFromEnum(md.month)) - 1) * 3;
        _ = try std.fmt.bufPrint(&date_buf, "{s}, {d:0>2} {s} {d} {d:0>2}:{d:0>2}:{d:0>2} GMT", .{
            names[wd * 3 ..][0..3],
            md.day_index + 1,
            months[m..][0..3],
            yd.year,
            ds.getHoursIntoDay(),
            ds.getMinutesIntoHour(),
            ds.getSecondsIntoMinute(),
        });
        date_secs = secs;
    }
    return req.arena.dupe(u8, &date_buf);
}

// dusty middleware that adds the Server and Date fields.
const Stamp = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !Stamp {
        return .{};
    }

    pub fn execute(_: *const Stamp, req: *http.Request, res: *http.Response, executor: anytype) !void {
        try res.header("Server", "dusty");
        try res.header("Date", try date(req));
        return executor.next();
    }
};

// Registers each route of table under prefix, behind middleware, which
// follows the router's global middleware.
fn mount(router: *rest.Router, prefix: []const u8, middleware: []const rest.Middleware, comptime table: []const rest.Route) void {
    const g = router.group(prefix, middleware);
    inline for (table) |r| {
        const a = rest.action(r.handler);
        switch (r.method) {
            .get => g.get(r.path, a),
            .post => g.post(r.path, a),
            .patch => g.patch(r.path, a),
            .put => g.put(r.path, a),
            .delete => g.delete(r.path, a),
            else => @compileError("no route method " ++ @tagName(r.method)),
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    const cfg = rest.init(a, init.io, init.environ_map, args, "dusty");

    var rt = try zio.Runtime.init(init.gpa, .{ .executors = .exact(cfg.workers) });
    defer rt.deinit();

    const listeners = [_]http.Listener{
        .{ .address = .{ .ip = try std.Io.net.IpAddress.parse("0.0.0.0", cfg.port) } },
    };
    var app: rest.App = .{};
    var server = http.Server(rest.App).init(init.gpa, rt.io(), .{
        .listeners = &listeners,
        .max_connections = 65_536,
        .request = .{ .max_body_size = rest.writes.import_limit },
    }, &app);
    defer server.deinit();

    const router = &server.router;
    // Set before any route is registered: a route takes the global
    // middleware as it is when it's registered.
    const global = [_]rest.Middleware{try server.middleware(Stamp, .{})};
    router.middlewares = &global;
    const bearer = [_]rest.Middleware{try server.middleware(rest.heavy.Bearer, .{})};
    const same_origin = [_]rest.Middleware{try server.middleware(rest.snow.SameOrigin, .{})};
    switch (cfg.tier) {
        .a => mount(router, "", &.{}, &rest.routes),
        .b => mount(router, "/api/v1", &same_origin, &rest.snow.routes),
        .c => mount(router, "/api/v2", &bearer, &rest.heavy.routes),
        .d => {
            mount(router, "/api/v2", &bearer, &rest.heavy.routes);
            mount(router, "/api/v3", &bearer, &rest.writes.routes);
        },
    }
    try server.run();
}
