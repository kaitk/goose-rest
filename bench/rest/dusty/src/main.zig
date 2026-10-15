// goose-http's REST benchmark on dusty and the zio runtime,
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
//   tier f   /           micro.f_routes
//   tier r   /           micro.r_routes, github.txt's 203
//   tier m   /           rest.routes, behind micro.Timing, dusty's Cors, and
//                        micro.Bearer
//
// Stamp, the Server and Date fields, is global, so dusty runs it for a request
// no route takes too; that request gets App.notFound's 404. Tier M's stack is
// global for the same reason: a preflight has no route of its own, and an
// error needs its Server-Timing.
//
//     REST_DATA=DIR TIER=a|b|c|d WORKERS=n [JSON=template] rest-dusty [port]

const std = @import("std");
const zio = @import("zio");
const http = @import("dusty");
const rest = @import("rest.zig");
const micro = @import("micro.zig");

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
        switch (r.method) {
            .get => g.get(r.path, r.handler),
            .post => g.post(r.path, r.handler),
            .patch => g.patch(r.path, r.handler),
            .put => g.put(r.path, r.handler),
            .delete => g.delete(r.path, r.handler),
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
    const stamp = try server.middleware(Stamp, .{});
    const global = [_]rest.Middleware{stamp};
    const stack = [_]rest.Middleware{
        stamp,
        try server.middleware(micro.Timing, .{}),
        try server.middleware(http.middleware.Cors, micro.cors),
        try server.middleware(micro.Bearer, .{}),
    };
    router.middlewares = if (cfg.tier == .m) &stack else &global;
    const bearer = [_]rest.Middleware{try server.middleware(rest.heavy.Bearer, .{})};
    const same_origin = [_]rest.Middleware{try server.middleware(rest.snow.SameOrigin, .{})};
    switch (cfg.tier) {
        .a, .m => mount(router, "", &.{}, &rest.routes),
        .f => mount(router, "", &.{}, &micro.f_routes),
        .r => mount(router, "", &.{}, &micro.r_routes),
        .b => mount(router, "/api/v1", &same_origin, &rest.snow.routes),
        .c => mount(router, "/api/v2", &bearer, &rest.heavy.routes),
        .d => {
            mount(router, "/api/v2", &bearer, &rest.heavy.routes);
            mount(router, "/api/v3", &bearer, &rest.writes.routes);
        },
    }
    try server.run();
}
