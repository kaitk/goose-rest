// goose-rest's own tiers, whose spec is goose-rest's
// bench/rest/tiers/check.py:
//
//   F  the bun-http-framework-benchmark's three routes: f_routes
//   R  the GitHub API's 203 routes of github.txt: r_routes, a handler per route
//      made at compile time from the file the build embeds
//   M  tier A's routes behind a middleware stack: Timing, dusty's Cors, and
//      Bearer (main.zig)
//
// F and R answer as dusty's own handlers do: the body with `content_type` and
// `Response.json`.
const std = @import("std");
const http = @import("dusty");
const github = @import("github");
const rest = @import("rest.zig");

pub const f_routes = [_]rest.Route{
    .{ .method = .get, .path = "/", .handler = getRoot },
    .{ .method = .get, .path = "/id/:id", .handler = getId },
    .{ .method = .post, .path = "/json", .handler = postJson },
};

fn getRoot(_: *rest.App, _: *http.Request, res: *http.Response) !void {
    res.content_type = .text;
    res.body = "Hi";
}

fn getId(_: *rest.App, req: *http.Request, res: *http.Response) !void {
    try res.header("x-powered-by", "benchmark");
    res.content_type = .text;
    res.body = try std.fmt.allocPrint(req.arena, "{s} {s}", .{ rest.param(req, "id"), req.query.get("name") orelse "" });
}

// The body read into std.json's Value, whose objects keep their members'
// order, and written back. dusty's Request.jsonValue would do the same, but
// gives a body it can't read and one that isn't JSON the same error path. A
// repeated member keeps its last value, as JavaScript's JSON.parse does.
fn postJson(_: *rest.App, req: *http.Request, res: *http.Response) !void {
    const body = try rest.bodyOf(req) orelse return rest.send(res, rest.too_large);
    const v = std.json.parseFromSliceLeaky(std.json.Value, req.arena, body, .{
        .duplicate_field_behavior = .use_last,
    }) catch {
        return rest.send(res, rest.empty(400));
    };
    try res.json(v, .{});
}

// Tier R's routes: line n of github.txt, "METHOD /path/:param", answers
// "n" and each parameter's value in order, separated by spaces.
pub const r_routes = blk: {
    @setEvalBranchQuota(1_000_000);
    const text = github.text;
    var routes: [std.mem.count(u8, text, "\n") + 1]rest.Route = undefined;
    var n: usize = 0;
    var lines = std.mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        n += 1;
        const space = std.mem.indexOfScalar(u8, line, ' ') orelse @compileError("github.txt: " ++ line);
        const path = line[space + 1 ..];
        routes[n - 1] = .{ .method = methodOf(line[0..space]), .path = path, .handler = numbered(n, path) };
    }
    break :blk routes[0..n].*;
};

fn methodOf(comptime name: []const u8) http.Method {
    const methods = .{ .{ "GET", .get }, .{ "POST", .post }, .{ "PUT", .put }, .{ "PATCH", .patch }, .{ "DELETE", .delete } };
    inline for (methods) |m| if (std.mem.eql(u8, name, m[0])) return m[1];
    @compileError("github.txt: no method " ++ name);
}

// Route n's handler, with path's parameter names.
fn numbered(comptime n: usize, comptime path: []const u8) rest.Router.Handler {
    const names = comptime blk: {
        var list: []const []const u8 = &.{};
        var segs = std.mem.tokenizeScalar(u8, path, '/');
        while (segs.next()) |seg| {
            if (seg[0] == ':') list = list ++ .{seg[1..]};
        }
        break :blk list;
    };
    const number = std.fmt.comptimePrint("{d}", .{n});
    return struct {
        fn run(_: *rest.App, req: *http.Request, res: *http.Response) anyerror!void {
            res.content_type = .text;
            if (names.len == 0) {
                res.body = number;
                return;
            }
            var o = try rest.Out.initCapacity(req.arena, 64);
            try o.writer.writeAll(number);
            inline for (names) |name| {
                try o.writer.writeByte(' ');
                try o.writer.writeAll(rest.param(req, name));
            }
            res.body = o.written();
        }
    }.run;
}

// Tier M's outermost middleware: Server-Timing with the time the rest of the
// stack and the handler took, on every answer they give, errors included.
pub const Timing = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !Timing {
        return .{};
    }

    pub fn execute(_: *const Timing, req: *http.Request, res: *http.Response, executor: anytype) !void {
        const start = std.Io.Timestamp.now(req.io, .awake);
        const result = executor.next();
        const ns = start.durationTo(std.Io.Timestamp.now(req.io, .awake)).toNanoseconds();
        const us: u64 = @intCast(@max(@divTrunc(ns, 1000), 0));
        const v = try std.fmt.allocPrint(req.arena, "app;dur={d}.{d:0>3}", .{ us / 1000, us % 1000 });
        // A handler that sent its answer itself (a 413) has no field to add.
        res.header("Server-Timing", v) catch |e| switch (e) {
            error.HeadersAlreadySent => {},
            else => return e,
        };
        return result;
    }
};

// Tier M's bearer check: 401 without "Authorization: Bearer <token>", the
// token not read further.
pub const Bearer = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !Bearer {
        return .{};
    }

    pub fn execute(_: *const Bearer, req: *http.Request, res: *http.Response, executor: anytype) !void {
        const auth = req.headers.get("Authorization") orelse "";
        if (!(auth.len > "Bearer ".len and std.mem.startsWith(u8, auth, "Bearer "))) {
            return rest.send(res, rest.empty(401));
        }
        return executor.next();
    }
};

pub const cors: http.middleware.Cors.Config = .{
    .origin = "https://app.example",
    .methods = "GET, POST",
    .headers = "Authorization, Content-Type",
};
