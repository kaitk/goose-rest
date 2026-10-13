// Tier D, writes with large bodies, under /api/v3, behind tier C's token,
// answered from the body alone as goose-http's bench/rest/hyper/src/writes.rs
// answers them. The routes are `routes`, mounted under /api/v3 behind
// heavy.Bearer:
//
//   POST  /imports           a CSV: its rows, and each column's count and sum
//   POST  /attachments       multipart: the fields, the file's size and Adler-32
//   POST  /bookings/batch    JSON: each booking's id, or 422 with the errors
//   POST  /forms             a form: its fields, decoded
//
// The CSV and the multipart body are read as they arrive, through dusty's
// Request.reader, which undoes chunked framing: the CSV by a port of Goose's
// reader, and the multipart body by a port of goose-http's bench/rest/odin
// reader, which accepts and refuses what multer, hyper's, does for the
// checker's bodies. dusty's multiFormData takes only a whole body into a map,
// without the file's checksum or the fields' order. The batch and the form
// are read whole through the same reader, up to their own limits, below the
// server's max_body_size; the batch is parsed by std.json, and the form here,
// since dusty's formData keeps neither order nor repeats, and takes 32 fields.
//
// A handler that has an answer before the body's end reads the rest of the
// body and drops it, unless the answer is to close.
const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("dusty");
const rest = @import("rest.zig");
const Ctx = rest.Ctx;
const Resp = rest.Resp;
const jsonStatus = rest.jsonStatus;
const too_large = rest.too_large;

pub const import_limit = 16 << 20;
const batch_limit = 1 << 20;
const form_limit = 64 << 10;
const max_text = 1024;
const max_texts = 8;

pub fn err(status: u16) Resp {
    return switch (status) {
        400 => jsonStatus(400, "{\"error\":\"bad_request\",\"status\":400}"),
        401 => jsonStatus(401, "{\"error\":\"unauthorized\",\"status\":401}"),
        415 => jsonStatus(415, "{\"error\":\"unsupported_media_type\",\"status\":415}"),
        else => jsonStatus(404, "{\"error\":\"not_found\",\"status\":404}"),
    };
}

// Whether the Content-Type's media type is want, ignoring case and
// parameters. dusty's ContentType has no text/csv.
fn hasType(ctype: ?[]const u8, want: []const u8) bool {
    var v = ctype orelse return false;
    if (std.mem.indexOfScalar(u8, v, ';')) |semi| v = v[0..semi];
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, v, " \t"), want);
}

// Tier D's routes, under /api/v3. dusty answers another method or path with
// the not-found hook's 404, and heavy.Bearer a request without a token with
// 401, before these run.
pub const routes = [_]rest.Route{
    rest.route(.post, "/imports", postImport),
    rest.route(.post, "/attachments", postAttachment),
    rest.route(.post, "/bookings/batch", postBatch),
    rest.route(.post, "/forms", postForm),
};

const piece_size = 64 << 10;

// The answer the head gets before the body is read: 415 for another media
// type, or 413 for a declared length over limit.
fn refused(req: *const http.Request, want: []const u8, limit: usize) ?Resp {
    if (!hasType(req.headers.get("Content-Type"), want)) return err(415);
    if (req.content_length) |n| if (n > limit) return too_large;
    return null;
}

// answer, sent before the body's end, after the rest of the body is read and
// dropped, unless it closes the connection.
fn early(req: *http.Request, body: anytype, answer: Resp) !Resp {
    if (answer.close) return answer;
    // discardRemaining on dusty's body reader doesn't return once the body
    // has ended, so the rest is read into a piece instead.
    const piece = try req.arena.alloc(u8, piece_size);
    while (try readPiece(body, piece)) |_| {}
    return answer;
}

// Reads what has arrived of the body into piece, up to its length, or null
// at the body's end.
fn readPiece(body: anytype, piece: []u8) !?usize {
    var vec = [1][]u8{piece};
    return body.interface.readVec(&vec) catch |e| switch (e) {
        error.EndOfStream => null,
        error.ReadFailed => body.err orelse error.Unexpected,
    };
}

// The body whole, read through dusty's body reader up to limit; null for one
// over it.
fn readWhole(req: *http.Request, limit: usize) !?[]const u8 {
    var body = try req.reader(&.{});
    return body.interface.allocRemaining(req.arena, .limited(limit)) catch |e| switch (e) {
        error.StreamTooLong => null,
        error.ReadFailed => body.err orelse error.Unexpected,
        else => e,
    };
}

fn postImport(req: *http.Request) !Resp {
    var body = try req.reader(&.{});
    if (refused(req, "text/csv", import_limit)) |r| return early(req, &body, r);
    const piece = try req.arena.alloc(u8, piece_size);
    var csv: Csv = .{};
    var taken: usize = 0;
    while (try readPiece(&body, piece)) |n| {
        taken += n;
        if (taken > import_limit) return too_large;
        csv.piece(piece[0..n]);
    }
    return importAnswer(rest.ctxOf(req), &csv);
}

fn postAttachment(req: *http.Request) !Resp {
    var body = try req.reader(&.{});
    if (refused(req, "multipart/form-data", import_limit)) |r| return early(req, &body, r);
    const ctype = req.headers.get("Content-Type").?;
    const boundary = parseBoundary(ctype) orelse return early(req, &body, err(400));
    var parts: Parts = try .init(req.arena, boundary);
    const piece = try req.arena.alloc(u8, piece_size);
    var taken: usize = 0;
    while (try readPiece(&body, piece)) |n| {
        taken += n;
        if (taken > import_limit) return too_large;
        if (try parts.push(piece[0..n])) |a| return early(req, &body, a);
    }
    return parts.finish();
}

fn postBatch(req: *http.Request) !Resp {
    if (refused(req, "application/json", batch_limit)) |r| {
        var body = try req.reader(&.{});
        return early(req, &body, r);
    }
    const whole = try readWhole(req, batch_limit) orelse return too_large;
    return batch(rest.ctxOf(req), whole);
}

fn postForm(req: *http.Request) !Resp {
    if (refused(req, "application/x-www-form-urlencoded", form_limit)) |r| {
        var body = try req.reader(&.{});
        return early(req, &body, r);
    }
    const whole = try readWhole(req, form_limit) orelse return too_large;
    return form(rest.ctxOf(req), whole);
}

// An import's columns, of three kinds.
const ColumnKind = enum { text, int, dec };

const Column = struct {
    name: []const u8,
    kind: ColumnKind,
};

const columns = [6]Column{
    .{ .name = "id", .kind = .int },
    .{ .name = "date", .kind = .text },
    .{ .name = "account", .kind = .text },
    .{ .name = "description", .kind = .text },
    .{ .name = "quantity", .kind = .int },
    .{ .name = "amount", .kind = .dec },
};

const Quote = enum { outside, inside, after };

// A CSV body (RFC 4180, with LF or CRLF line ends) read piece by piece, as
// rest.goose's Csv: where the reader is, the field it's in, and each column's
// count of non-empty cells and its sum, or its bytes for text.
const Csv = struct {
    record: i64 = 1,
    column: usize = 0,
    quote: Quote = .outside,
    closed: bool = false,
    cr: bool = false,
    len: usize = 0,
    value: i64 = 0,
    neg: bool = false,
    digits: i64 = 0,
    point: i64 = -1,
    number: bool = true,
    header: [16]u8 = undefined,
    n_head: usize = 0,
    counts: [6]i64 = @splat(0),
    sums: [6]i64 = @splat(0),
    bad: i64 = 0,

    fn fail(c: *Csv) void {
        if (c.bad == 0) c.bad = c.record;
    }

    fn text(c: *Csv, s: []const u8) void {
        const before = c.len;
        c.len += s.len;
        if (c.record == 1) {
            if (c.n_head + s.len <= 16) {
                @memcpy(c.header[c.n_head..][0..s.len], s);
                c.n_head += s.len;
            }
            return;
        }
        if (c.column >= columns.len) return;
        const kind = columns[c.column].kind;
        if (kind == .text) return;
        for (s, 0..) |ch, i| {
            if (ch >= '0' and ch <= '9') {
                if (c.digits < 18) {
                    c.value = c.value * 10 + (ch - '0');
                } else {
                    c.number = false;
                }
                c.digits += 1;
                if (c.point >= 0) c.point += 1;
            } else if (ch == '-' and before + i == 0) {
                c.neg = true;
            } else if (ch == '.' and kind == .dec and c.point < 0 and c.digits > 0) {
                c.point = 0;
            } else {
                c.number = false;
            }
        }
    }

    fn fieldEnd(c: *Csv) void {
        const k = c.column;
        if (k >= columns.len) {
            c.fail();
        } else if (c.record == 1) {
            if (c.len > 16 or !std.mem.eql(u8, c.header[0..c.n_head], columns[k].name)) c.fail();
        } else if (c.len > 0) {
            const kind = columns[k].kind;
            if (kind == .text) {
                c.counts[k] += 1;
                c.sums[k] += @intCast(c.len);
            } else if (c.number and c.digits > 0 and (if (kind == .dec) c.point == 2 else c.point < 0)) {
                c.counts[k] += 1;
                c.sums[k] += if (c.neg) -c.value else c.value;
            } else {
                c.fail();
            }
        }
        c.column += 1;
        c.len = 0;
        c.value = 0;
        c.neg = false;
        c.digits = 0;
        c.point = -1;
        c.number = true;
        c.closed = false;
        c.n_head = 0;
    }

    fn recordEnd(c: *Csv) void {
        c.fieldEnd();
        if (c.column != columns.len) c.fail();
        c.record += 1;
        c.column = 0;
    }

    fn piece(c: *Csv, p: []const u8) void {
        var i: usize = 0;
        while (i < p.len and c.bad == 0) {
            const ch = p[i];
            if (c.quote == .inside) {
                const q = std.mem.indexOfScalarPos(u8, p, i, '"') orelse {
                    c.text(p[i..]);
                    return;
                };
                c.text(p[i..q]);
                c.quote = .after;
                i = q + 1;
                continue;
            }
            if (c.quote == .after) {
                c.quote = .outside;
                if (ch == '"') {
                    c.text(p[i .. i + 1]);
                    c.quote = .inside;
                    i += 1;
                    continue;
                }
                c.closed = true;
            }
            if (c.cr) {
                c.cr = false;
                if (ch != '\n') {
                    c.fail();
                    return;
                }
            }
            if (ch == ',') {
                c.fieldEnd();
                i += 1;
            } else if (ch == '\n') {
                c.recordEnd();
                i += 1;
            } else if (ch == '\r') {
                c.cr = true;
                i += 1;
            } else if (c.closed or (ch == '"' and c.len > 0)) {
                c.fail();
            } else if (ch == '"') {
                c.quote = .inside;
                i += 1;
            } else {
                var j = i + 1;
                while (j < p.len and p[j] != ',' and p[j] != '\n' and p[j] != '\r' and p[j] != '"') j += 1;
                c.text(p[i..j]);
                i = j;
            }
        }
    }

    fn end(c: *Csv) void {
        if (c.bad != 0) return;
        if (c.quote == .inside or c.cr) {
            c.fail();
            return;
        }
        if (c.quote == .after or c.closed or c.column > 0 or c.len > 0) c.recordEnd();
        if (c.record == 1) c.fail();
    }
};

fn writeCents(w: *std.Io.Writer, v: i64) !void {
    const a = @abs(v);
    if (v < 0) try w.writeByte('-');
    try w.print("{d}.{d:0>2}", .{ a / 100, a % 100 });
}

fn importAnswer(ctx: Ctx, c: *Csv) !Resp {
    c.end();
    var o = try rest.out(ctx, 512);
    const w = &o.writer;
    if (c.bad != 0) {
        try w.print("{{\"error\":\"bad_csv\",\"record\":{d}}}", .{c.bad});
        return jsonStatus(400, o.written());
    }
    try w.print("{{\"rows\":{d},\"columns\":[", .{c.record - 2});
    for (columns, 0..) |col, k| {
        if (k > 0) try w.writeByte(',');
        try w.print("{{\"name\":\"{s}\",\"count\":{d}", .{ col.name, c.counts[k] });
        switch (col.kind) {
            .text => try w.print(",\"bytes\":{d}", .{c.sums[k]}),
            .int => try w.print(",\"sum\":{d}", .{c.sums[k]}),
            .dec => {
                try w.writeAll(",\"sum\":");
                try writeCents(w, c.sums[k]);
            },
        }
        try w.writeByte('}');
    }
    try w.writeAll("]}");
    return jsonStatus(201, o.written());
}

// The boundary parameter of a multipart Content-Type, unquoted.
fn parseBoundary(ctype: []const u8) ?[]const u8 {
    const semi = std.mem.indexOfScalar(u8, ctype, ';') orelse return null;
    var params = std.mem.splitScalar(u8, ctype[semi + 1 ..], ';');
    while (params.next()) |raw| {
        const param = std.mem.trim(u8, raw, " \t");
        const eq = std.mem.indexOfScalar(u8, param, '=') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, param[0..eq], " \t"), "boundary")) continue;
        var v = std.mem.trim(u8, param[eq + 1 ..], " \t");
        if (v.len >= 2 and v[0] == '"' and v[v.len - 1] == '"') v = v[1 .. v.len - 1];
        if (v.len == 0 or v.len > 200) return null;
        return v;
    }
    return null;
}

const PartsState = enum {
    preamble, // before the first delimiter
    after_delimiter, // a delimiter read: CRLF, or "--" for the last
    head, // a part's head, up to its blank line
    content, // a part's content, up to CRLF and the next delimiter
    done,
};

// A multipart body read as it arrives. buf holds what isn't yet taken: a
// part's head, or the tail of a part's content that may start a delimiter.
const Parts = struct {
    a: Allocator,
    delimiter: []const u8, // "\r\n--" and the boundary
    state: PartsState = .preamble,
    buf: std.ArrayList(u8),
    // The part being read: a file's, or a text field's value.
    is_file: bool = false,
    text: std.ArrayList(u8),
    name: []const u8 = "",
    // The fields so far, as JSON members, and the file.
    fields: rest.Out,
    texts: usize = 0,
    has_file: bool = false,
    file: struct {
        field: []const u8 = "",
        filename: []const u8 = "",
        ctype: []const u8 = "",
        size: usize = 0,
        a: u32 = 1,
        b: u32 = 0,
    } = .{},

    fn init(a: Allocator, boundary: []const u8) !Parts {
        var p: Parts = .{
            .a = a,
            .delimiter = try std.mem.concat(a, u8, &.{ "\r\n--", boundary }),
            .buf = try .initCapacity(a, 64 << 10),
            .text = try .initCapacity(a, 256),
            .fields = try .initCapacity(a, 256),
        };
        // The first delimiter has no CRLF before it; a body is read as if it
        // had one.
        p.buf.appendSliceAssumeCapacity("\r\n");
        return p;
    }

    // Starts a part from its head: its name, and a file's name and type.
    fn partHead(p: *Parts, head: []const u8) !?Resp {
        var name: ?[]const u8 = null;
        var filename: ?[]const u8 = null;
        var ctype: ?[]const u8 = null;
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse return err(400);
            const key = std.mem.trim(u8, line[0..colon], " \t");
            const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
            if (std.ascii.eqlIgnoreCase(key, "content-disposition")) {
                name = dispositionParam(value, "name");
                filename = dispositionParam(value, "filename");
            } else if (std.ascii.eqlIgnoreCase(key, "content-type")) {
                ctype = value;
            }
        }
        const n = name orelse return err(400);
        if (n.len == 0 or n.len > 64) return err(400);
        // The head's strings outlive buf's bytes.
        p.name = try p.a.dupe(u8, n);
        p.is_file = filename != null and filename.?.len > 0;
        if (p.is_file) {
            const t = ctype orelse "application/octet-stream";
            if (p.has_file or filename.?.len > 256 or t.len > 128) return err(400);
            p.has_file = true;
            p.file = .{ .field = p.name, .filename = try p.a.dupe(u8, filename.?), .ctype = try p.a.dupe(u8, t) };
        } else {
            if (p.texts == max_texts) return err(400);
            p.text.clearRetainingCapacity();
        }
        return null;
    }

    // Takes some of a part's content.
    fn partContent(p: *Parts, d: []const u8) !?Resp {
        if (p.is_file) {
            p.file.size += d.len;
            adler(&p.file.a, &p.file.b, d);
            return null;
        }
        if (p.text.items.len + d.len > max_text) return err(400);
        try p.text.appendSlice(p.a, d);
        return null;
    }

    // Ends a part at its delimiter.
    fn partEnd(p: *Parts) !void {
        if (p.is_file) return;
        const w = &p.fields.writer;
        if (p.texts > 0) try w.writeByte(',');
        try rest.writeLossy(w, p.name);
        try w.writeByte(':');
        try rest.writeLossy(w, p.text.items);
        p.texts += 1;
    }

    fn push(p: *Parts, piece: []const u8) !?Resp {
        if (p.state == .done) return null;
        try p.buf.appendSlice(p.a, piece);
        return p.run();
    }

    // Reads as far as buf allows.
    fn run(p: *Parts) !?Resp {
        const d = p.delimiter;
        while (true) {
            const buf = p.buf.items;
            switch (p.state) {
                .preamble, .content => {
                    const at = std.mem.indexOf(u8, buf, d) orelse {
                        // Keep what may start a delimiter.
                        const keep = @min(buf.len, d.len - 1);
                        if (p.state == .content) {
                            if (try p.partContent(buf[0 .. buf.len - keep])) |r| return r;
                        }
                        p.consume(buf.len - keep);
                        return null;
                    };
                    if (p.state == .content) {
                        if (try p.partContent(buf[0..at])) |r| return r;
                        try p.partEnd();
                    }
                    p.consume(at + d.len);
                    p.state = .after_delimiter;
                },
                .after_delimiter => {
                    if (buf.len < 2) return null;
                    if (buf[0] == '-' and buf[1] == '-') {
                        p.state = .done;
                        return try p.answer();
                    }
                    if (buf[0] != '\r' or buf[1] != '\n') return err(400);
                    p.consume(2);
                    p.state = .head;
                },
                .head => {
                    const end = std.mem.indexOf(u8, buf, "\r\n\r\n") orelse {
                        if (buf.len > 8192) return err(400);
                        return null;
                    };
                    if (try p.partHead(buf[0..end])) |r| return r;
                    p.consume(end + 4);
                    p.state = .content;
                },
                .done => return null,
            }
        }
    }

    fn consume(p: *Parts, n: usize) void {
        if (n == 0) return;
        const rest_len = p.buf.items.len - n;
        std.mem.copyForwards(u8, p.buf.items[0..rest_len], p.buf.items[n..]);
        p.buf.shrinkRetainingCapacity(rest_len);
    }

    // The answer at the body's end: a body without its close delimiter is
    // refused, as multer refuses it.
    fn finish(p: *Parts) !Resp {
        if (p.state == .done) return p.answer();
        return err(400);
    }

    fn answer(p: *Parts) !Resp {
        if (!p.has_file) {
            return jsonStatus(422, "{\"error\":\"invalid\",\"errors\":[{\"field\":\"file\",\"message\":\"is required\"}]}");
        }
        var o: rest.Out = try .initCapacity(p.a, 256 + p.fields.written().len);
        const w = &o.writer;
        try w.writeAll("{\"fields\":{");
        try w.writeAll(p.fields.written());
        try w.writeAll("},\"file\":{\"field\":");
        try rest.writeLossy(w, p.file.field);
        try w.writeAll(",\"filename\":");
        try rest.writeLossy(w, p.file.filename);
        try w.writeAll(",\"contentType\":");
        try rest.writeLossy(w, p.file.ctype);
        try w.print(",\"size\":{d},\"adler32\":{d}}}}}", .{ p.file.size, @as(u64, p.file.b) << 16 | p.file.a });
        return jsonStatus(201, o.written());
    }
};

// A Content-Disposition parameter's value, quoted or not.
fn dispositionParam(v: []const u8, key: []const u8) ?[]const u8 {
    var params = std.mem.splitScalar(u8, v, ';');
    while (params.next()) |raw| {
        const param = std.mem.trim(u8, raw, " \t");
        const eq = std.mem.indexOfScalar(u8, param, '=') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, param[0..eq], " \t"), key)) continue;
        var x = std.mem.trim(u8, param[eq + 1 ..], " \t");
        if (x.len >= 2 and x[0] == '"' and x[x.len - 1] == '"') x = x[1 .. x.len - 1];
        return x;
    }
    return null;
}

// Adler-32 (RFC 1950), deferring the modulo as zlib does.
fn adler(a: *u32, b: *u32, data: []const u8) void {
    var r = data;
    while (r.len > 0) {
        const n = @min(r.len, 5552);
        for (r[0..n]) |c| {
            a.* += c;
            b.* += a.*;
        }
        a.* %= 65521;
        b.* %= 65521;
        r = r[n..];
    }
}

// How a booking's member read: absent, wrong, or fine.
const How = enum { absent, wrong, fine };

// An integer from lo to hi: a JSON number with no fraction.
fn intMember(obj: std.json.ObjectMap, key: []const u8, lo: f64, hi: f64) How {
    const v = obj.get(key) orelse return .absent;
    const n: f64 = switch (v) {
        .integer => |x| @floatFromInt(x),
        .float => |x| x,
        else => return .wrong,
    };
    return if (n >= lo and n <= hi and n == @trunc(n)) .fine else .wrong;
}

fn isService(t: []const u8) bool {
    const d = std.mem.indexOfScalar(u8, t, '-') orelse return false;
    if (d < 2 or d > 4 or t.len != d + 3) return false;
    for (t[0..d]) |c| if (c < 'A' or c > 'Z') return false;
    return std.ascii.isDigit(t[d + 1]) and std.ascii.isDigit(t[d + 2]);
}

fn timeMember(obj: std.json.ObjectMap, key: []const u8, t: *i64) How {
    const v = obj.get(key) orelse return .absent;
    if (v != .string) return .wrong;
    t.* = rest.parseIso(v.string) orelse return .wrong;
    return .fine;
}

fn bookingError(w: *std.Io.Writer, any: *bool, k: usize, field: []const u8, message: []const u8) !void {
    if (any.*) try w.writeByte(',');
    any.* = true;
    try w.print("{{\"index\":{d},\"field\":\"{s}\",\"message\":\"{s}\"}}", .{ k, field, message });
}

fn checkField(w: *std.Io.Writer, any: *bool, k: usize, how: How, field: []const u8, message: []const u8) !void {
    switch (how) {
        .absent => try bookingError(w, any, k, field, "is required"),
        .wrong => try bookingError(w, any, k, field, message),
        .fine => {},
    }
}

// POST /bookings/batch: each booking's id, the batch's id and its number, and
// their minutes, or 422 with each field that doesn't validate.
fn batch(ctx: Ctx, body: []const u8) !Resp {
    if (!rest.isObject(body)) return err(400);
    const v = rest.parseWhole(ctx.arena, body) orelse return err(400);
    if (v != .object) return err(400);
    const id_v = v.object.get("batchId") orelse return err(400);
    if (id_v != .string or id_v.string.len == 0 or id_v.string.len > 64) return err(400);
    const id = id_v.string;
    const list_v = v.object.get("bookings") orelse return err(400);
    if (list_v != .array) return err(400);
    const list = list_v.array.items;
    var errors = try rest.out(ctx, 256);
    const ew = &errors.writer;
    var any = false;
    var minutes: i64 = 0;
    for (list, 0..) |raw, k| {
        if (raw != .object) {
            try bookingError(ew, &any, k, "booking", "must be an object");
            continue;
        }
        const x = raw.object;
        try checkField(ew, &any, k, intMember(x, "clientId", 1, 1_000_000), "clientId", "must be an integer from 1 to 1000000");
        try checkField(ew, &any, k, intMember(x, "staffId", 1, 10), "staffId", "must be an integer from 1 to 10");
        var service: How = .absent;
        if (x.get("service")) |sv| service = if (sv == .string and isService(sv.string)) .fine else .wrong;
        try checkField(ew, &any, k, service, "service", "must be a service code");
        var from: i64 = 0;
        var to: i64 = 0;
        const s = timeMember(x, "start", &from);
        const e = timeMember(x, "end", &to);
        try checkField(ew, &any, k, s, "start", "must be an ISO 8601 time");
        try checkField(ew, &any, k, e, "end", "must be an ISO 8601 time");
        if (s == .fine and e == .fine and (to <= from or to - from > 8 * 3_600_000)) {
            try bookingError(ew, &any, k, "end", "must be after start, by at most 8 hours");
        }
        try checkField(ew, &any, k, intMember(x, "room", 1, 6), "room", "must be an integer from 1 to 6");
        var note: How = .fine;
        if (x.get("note")) |n| switch (n) {
            .null => {},
            .string => |t| if (t.len > 500) {
                note = .wrong;
            },
            else => note = .wrong,
        };
        try checkField(ew, &any, k, note, "note", "must be a string of at most 500 bytes");
        minutes += @divTrunc(to - from, rest.minute);
    }
    if (any) {
        var o = try rest.out(ctx, errors.written().len + 64);
        try o.writer.writeAll("{\"error\":\"invalid\",\"errors\":[");
        try o.writer.writeAll(errors.written());
        try o.writer.writeAll("]}");
        return jsonStatus(422, o.written());
    }
    var o = try rest.out(ctx, 64 + list.len * (id.len + 8));
    const w = &o.writer;
    try w.writeAll("{\"batchId\":");
    try rest.writeString(w, id);
    try w.print(",\"count\":{d},\"minutes\":{d},\"ids\":[", .{ list.len, minutes });
    for (0..list.len) |k| {
        if (k > 0) try w.writeByte(',');
        try rest.writeString(w, try std.fmt.allocPrint(ctx.arena, "{s}-{d}", .{ id, k + 1 }));
    }
    try w.writeAll("]}");
    return jsonStatus(201, o.written());
}

// POST /forms: the form's fields, decoded, in order.
fn form(ctx: Ctx, body: []const u8) !Resp {
    var o = try rest.out(ctx, body.len + 64);
    const w = &o.writer;
    try w.writeAll("{\"fields\":{");
    var n: usize = 0;
    var pairs = std.mem.splitScalar(u8, body, '&');
    while (pairs.next()) |pair| {
        if (pair.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, pair, '=');
        const k = if (eq) |i| pair[0..i] else pair;
        const v = if (eq) |i| pair[i + 1 ..] else "";
        const key = try rest.decode(ctx.arena, k, true) orelse return err(400);
        const value = try rest.decode(ctx.arena, v, true) orelse return err(400);
        if (n > 0) try w.writeByte(',');
        try rest.writeLossy(w, key);
        try w.writeByte(':');
        try rest.writeLossy(w, value);
        n += 1;
    }
    try w.print("}},\"count\":{d}}}", .{n});
    return jsonStatus(200, o.written());
}
