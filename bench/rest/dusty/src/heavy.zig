// Tier C, a clinic's schedule and records, under /api/v2, behind a bearer JWT
// that isn't verified (goose-http's bench/rest/hyper/src/heavy.rs). The
// routes are `routes`, mounted under /api/v2 behind Bearer.
//
// Ids are 1, 2, ... in each file, and the schedule's days are UTC's. The
// files hold each record in the shape the routes answer it, so the records
// are kept as read, with the times and staff the selections need beside them.
const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("dusty");
const rest = @import("rest.zig");
const Ctx = rest.Ctx;
const Resp = rest.Resp;
const jsonStatus = rest.jsonStatus;
const day = rest.day;
const minute = rest.minute;

const Meta = struct {
    versionEpoch: i64,
};

const Staffer = struct {
    id: i64,
    name: []const u8,
    title: []const u8,
};

const Address = struct {
    street: []const u8,
    city: []const u8,
    postcode: []const u8,
};

const Preferences = struct {
    channel: []const u8,
    language: []const u8,
};

const Contact = struct {
    name: []const u8,
    phone: []const u8,
    relation: []const u8,
};

const Consents = struct {
    sms: bool,
    email: bool,
    research: bool,
};

const Client = struct {
    id: i64,
    name: []const u8,
    code: []const u8,
    born: []const u8,
    phone: []const u8,
    email: []const u8,
    address: Address,
    preferences: Preferences,
    flags: []const []const u8,
    emergencyContact: Contact,
    consents: Consents,
    createdAt: []const u8,
    updatedAt: []const u8,
};

const ClientRef = struct {
    id: i64,
    name: []const u8,
    code: []const u8,
};

const StaffRef = struct {
    id: i64,
    name: []const u8,
};

const Line = struct {
    id: i64,
    code: []const u8,
    name: []const u8,
    minutes: i64,
    price: i64,
};

const Note = struct {
    id: i64,
    author: Staffer,
    text: []const u8,
    at: []const u8,
};

const Notes = struct {
    intake: []Note,
    findings: []Note,
    plan: []Note,
    internal: []Note,
};

const Encounter = struct {
    id: i64,
    caseId: i64,
    client: ClientRef,
    staff: Staffer,
    status: []const u8,
    kind: []const u8,
    priority: []const u8,
    start: []const u8,
    end: []const u8,
    items: []Line,
    codes: []const []const u8,
    notes: Notes,
};

const CaseNote = struct {
    id: i64,
    encounterId: i64,
    kind: []const u8,
    author: Staffer,
    text: []const u8,
    at: []const u8,
};

// GET /encounters/:id's answer: the visit, and the notes of every visit of
// its case.
const EncounterOut = struct {
    encounter: *const Encounter,
    case_notes: []const CaseNote,

    pub fn jsonStringify(self: EncounterOut, jw: *std.json.Stringify) !void {
        try jw.beginObject();
        try rest.writeFields(jw, self.encounter.*);
        try jw.objectField("caseNotes");
        try jw.write(self.case_notes);
        try jw.endObject();
    }
};

const Slot = struct {
    start: []const u8,
    end: []const u8,
};

const EncounterRef = struct {
    id: i64,
    status: []const u8,
    start: []const u8,
    end: []const u8,
};

const Reminder = struct {
    channel: []const u8,
    kind: []const u8,
    status: []const u8,
    at: []const u8,
};

const Booking = struct {
    id: i64,
    slot: Slot,
    client: ClientRef,
    staff: StaffRef,
    encounter: EncounterRef,
    items: []Line,
    reminders: []Reminder,
    status: []const u8,
    source: []const u8,
    note: ?[]const u8 = null,
    createdAt: []const u8,
    updatedAt: []const u8,
};

const Room = struct {
    id: i64,
    name: []const u8,
};

const Shift = struct {
    id: i64,
    staff: StaffRef,
    start: []const u8,
    end: []const u8,
    kind: []const u8,
    room: Room,
    note: ?[]const u8 = null,
};

const VersionOut = struct {
    version: i64,
    changedAt: []const u8,
};

// Where a record falls in the schedule: its start and its staff member's
// index.
const At = struct {
    start: i64,
    staff: usize,
};

const Heavy = struct {
    staff: []Staffer = &.{},
    clients: []Client = &.{},
    encounters: []Encounter = &.{},
    bookings: []Booking = &.{}, // by start
    booking_at: []At = &.{},
    shifts: []Shift = &.{}, // by start
    shift_at: []At = &.{},
    // Every encounter's notes as caseNotes lists them, in encounter order: an
    // encounter's are case_notes[note_first[i]..note_first[i + 1]].
    case_notes: []CaseNote = &.{},
    note_first: []usize = &.{},
    case_first: []usize = &.{}, // the first encounter of each one's case
    case_last: []usize = &.{}, // and its last
    // Completed visits, by client, newest first: a client's are
    // past[past_first[c]..past_first[c] + past_count[c]].
    past: []usize = &.{},
    past_first: []usize = &.{},
    past_count: []usize = &.{},
    version_epoch: i64 = 0,
    // JSON=template's: each booking, shift, and client whole; each encounter
    // without its closing brace; and each case note.
    booking_json: [][]u8 = &.{},
    shift_json: [][]u8 = &.{},
    client_json: [][]u8 = &.{},
    visit_json: [][]u8 = &.{},
    note_json: [][]u8 = &.{},
};

var h: Heavy = .{};

const note_kinds = [4][]const u8{ "intake", "findings", "plan", "internal" };

pub fn load(a: Allocator, io: std.Io, dir: []const u8, template: bool) usize {
    h.version_epoch = rest.readJson(Meta, a, io, dir, "heavy-meta.json").versionEpoch;
    rest.check(h.version_epoch > 0, "heavy-meta.json has no versionEpoch");
    h.staff = rest.readJson([]Staffer, a, io, dir, "heavy-staff.json");
    h.clients = rest.readJson([]Client, a, io, dir, "heavy-clients.json");
    h.encounters = rest.readJson([]Encounter, a, io, dir, "heavy-encounters.json");
    h.bookings = rest.readJson([]Booking, a, io, dir, "heavy-bookings.json");
    h.shifts = rest.readJson([]Shift, a, io, dir, "heavy-shifts.json");
    for (h.staff, 1..) |st, i| rest.check(st.id == i, "heavy-staff.json's ids aren't 1, 2, ...");
    for (h.clients, 1..) |c, i| rest.check(c.id == i, "heavy-clients.json's ids aren't 1, 2, ...");
    const n = h.encounters.len;
    h.note_first = a.alloc(usize, n + 1) catch rest.oom();
    h.case_first = a.alloc(usize, n) catch rest.oom();
    h.case_last = a.alloc(usize, n) catch rest.oom();
    var notes: std.ArrayList(CaseNote) = .empty;
    for (h.encounters, 0..) |e, i| {
        rest.check(e.id == i + 1, "heavy-encounters.json's ids aren't 1, 2, ...");
        rest.check(e.client.id >= 1 and e.client.id <= h.clients.len, "an encounter of a client heavy-clients.json lacks");
        h.note_first[i] = notes.items.len;
        const kinds = [4][]Note{ e.notes.intake, e.notes.findings, e.notes.plan, e.notes.internal };
        for (kinds, note_kinds) |ns, kind| {
            for (ns) |x| notes.append(a, .{
                .id = x.id,
                .encounterId = e.id,
                .kind = kind,
                .author = x.author,
                .text = x.text,
                .at = x.at,
            }) catch rest.oom();
        }
        // A case's encounters are together in the file.
        if (i > 0 and h.encounters[i - 1].caseId == e.caseId) {
            h.case_first[i] = h.case_first[i - 1];
        } else {
            rest.check(i == 0 or h.encounters[i - 1].caseId < e.caseId, "a case's encounters apart");
            h.case_first[i] = i;
        }
    }
    h.note_first[n] = notes.items.len;
    h.case_notes = notes.items;
    var i = n;
    while (i > 0) {
        i -= 1;
        h.case_last[i] = if (i + 1 < n and h.case_first[i + 1] == h.case_first[i]) h.case_last[i + 1] else i;
    }
    h.booking_at = a.alloc(At, h.bookings.len) catch rest.oom();
    for (h.bookings, h.booking_at, 0..) |b, *at, k| {
        rest.check(b.id == k + 1, "heavy-bookings.json's ids aren't 1, 2, ...");
        const start = rest.mustIso(b.slot.start, "a booking's start");
        rest.check(k == 0 or h.booking_at[k - 1].start <= start, "bookings out of order");
        at.* = .{ .start = start, .staff = @intCast(b.staff.id - 1) };
    }
    h.shift_at = a.alloc(At, h.shifts.len) catch rest.oom();
    for (h.shifts, h.shift_at, 0..) |sh, *at, k| {
        rest.check(sh.id == k + 1, "heavy-shifts.json's ids aren't 1, 2, ...");
        const start = rest.mustIso(sh.start, "a shift's start");
        rest.check(k == 0 or h.shift_at[k - 1].start <= start, "shifts out of order");
        at.* = .{ .start = start, .staff = @intCast(sh.staff.id - 1) };
    }
    var past: std.ArrayList(usize) = .empty;
    for (h.encounters, 0..) |e, k| {
        if (std.mem.eql(u8, e.status, "completed")) past.append(a, k) catch rest.oom();
    }
    // Newest first, and of two at once the later id first.
    std.sort.pdq(usize, past.items, {}, struct {
        fn lessThan(_: void, x: usize, y: usize) bool {
            const vx = &h.encounters[x];
            const vy = &h.encounters[y];
            if (vx.client.id != vy.client.id) return vx.client.id < vy.client.id;
            const order = std.mem.order(u8, vx.start, vy.start);
            if (order != .eq) return order == .gt;
            return x > y;
        }
    }.lessThan);
    h.past = past.items;
    h.past_first = a.alloc(usize, h.clients.len) catch rest.oom();
    h.past_count = a.alloc(usize, h.clients.len) catch rest.oom();
    @memset(h.past_first, 0);
    @memset(h.past_count, 0);
    for (h.past, 0..) |e, k| {
        const c: usize = @intCast(h.encounters[e].client.id - 1);
        if (h.past_count[c] == 0) h.past_first[c] = k;
        h.past_count[c] += 1;
    }
    if (template) {
        h.booking_json = a.alloc([]u8, h.bookings.len) catch rest.oom();
        for (h.bookings, h.booking_json) |b, *j| j.* = rest.marshal(a, b);
        h.shift_json = a.alloc([]u8, h.shifts.len) catch rest.oom();
        for (h.shifts, h.shift_json) |sh, *j| j.* = rest.marshal(a, sh);
        h.client_json = a.alloc([]u8, h.clients.len) catch rest.oom();
        for (h.clients, h.client_json) |c, *j| j.* = rest.marshal(a, c);
        h.visit_json = a.alloc([]u8, n) catch rest.oom();
        for (h.encounters, h.visit_json) |e, *j| j.* = rest.withoutBrace(rest.marshal(a, e));
        h.note_json = a.alloc([]u8, h.case_notes.len) catch rest.oom();
        for (h.case_notes, h.note_json) |x, *j| j.* = rest.marshal(a, x);
    }
    return h.bookings.len + n;
}

fn err(status: u16) Resp {
    return switch (status) {
        400 => jsonStatus(400, "{\"error\":\"bad_request\",\"status\":400}"),
        401 => jsonStatus(401, "{\"error\":\"unauthorized\",\"status\":401}"),
        else => jsonStatus(404, "{\"error\":\"not_found\",\"status\":404}"),
    };
}

fn isBase64url(t: []const u8) bool {
    if (t.len == 0) return false;
    for (t) |c| if (!(std.ascii.isAlphanumeric(c) or c == '-' or c == '_')) return false;
    return true;
}

// Whether Authorization is a bearer token of three base64url segments.
fn hasBearer(auth: ?[]const u8) bool {
    const v = auth orelse return false;
    if (!std.mem.startsWith(u8, v, "Bearer ")) return false;
    const t = v["Bearer ".len..];
    const x = std.mem.indexOfScalar(u8, t, '.') orelse return false;
    const y = std.mem.indexOfScalarPos(u8, t, x + 1, '.') orelse return false;
    return isBase64url(t[0..x]) and isBase64url(t[x + 1 .. y]) and isBase64url(t[y + 1 ..]);
}

// dusty middleware that refuses a request without a bearer token, for tiers
// C and D. Only a request a route takes gets here, so an unknown path is a
// 404 before it's a 401.
pub const Bearer = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !Bearer {
        return .{};
    }

    pub fn execute(_: *const Bearer, req: *http.Request, res: *http.Response, executor: anytype) !void {
        if (!hasBearer(req.headers.get("Authorization"))) return rest.send(res, err(401));
        return executor.next();
    }
};

// Tier C's routes, under /api/v2.
pub const routes = [_]rest.Route{
    .{ .method = .get, .path = "/schedule/version", .handler = getVersion },
    .{ .method = .get, .path = "/schedule/bookings", .handler = getBookings },
    .{ .method = .get, .path = "/schedule/shifts", .handler = getShifts },
    .{ .method = .get, .path = "/encounters/:id", .handler = getEncounter },
    .{ .method = .get, .path = "/clients/:id/encounters", .handler = getClientEncounters },
    .{ .method = .get, .path = "/clients/:id", .handler = getClient },
};

fn getVersion(req: *http.Request) !Resp {
    return scheduleVersion(rest.ctxOf(req), &req.query);
}

fn getBookings(req: *http.Request) !Resp {
    return listBookings(rest.ctxOf(req), &req.query);
}

fn getShifts(req: *http.Request) !Resp {
    return listShifts(rest.ctxOf(req), &req.query);
}

fn getEncounter(req: *http.Request) !Resp {
    const i = rest.indexOf(rest.param(req, "id"), h.encounters.len) orelse return err(404);
    return showEncounter(rest.ctxOf(req), i);
}

fn getClientEncounters(req: *http.Request) !Resp {
    const c = rest.indexOf(rest.param(req, "id"), h.clients.len) orelse return err(404);
    return clientHistory(rest.ctxOf(req), &req.query, c);
}

fn getClient(req: *http.Request) !Resp {
    const c = rest.indexOf(rest.param(req, "id"), h.clients.len) orelse return err(404);
    if (rest.data.template) return jsonStatus(200, h.client_json[c]);
    return jsonStatus(200, rest.marshal(req.arena, h.clients[c]));
}

const Range = struct {
    start: i64,
    end: i64,
    mask: u64,
};

// A start and an end day, end after start and at most 31 days on, and the
// staff of a list of their ids as bits. dusty has decoded the query.
fn rangeOf(query: *const http.Params) ?Range {
    const start = rest.parseDay(query.get("start") orelse return null) orelse return null;
    const end = rest.parseDay(query.get("end") orelse return null) orelse return null;
    const list = query.get("staff") orelse return null;
    if (!(end > start and end - start <= 31 * day) or list.len == 0) return null;
    var r: Range = .{ .start = start, .end = end, .mask = 0 };
    var ids = std.mem.splitScalar(u8, list, ',');
    while (ids.next()) |id| {
        const n = rest.parseInt(id) orelse return null;
        if (n < 1 or n > h.staff.len) return null;
        r.mask |= @as(u64, 1) << @intCast(n - 1);
    }
    return r;
}

// The indices of records by start in [start, end) of the range's staff.
fn select(ctx: Ctx, at: []const At, r: Range) ![]usize {
    const first = std.sort.partitionPoint(At, at, r.start, struct {
        fn f(bound: i64, x: At) bool {
            return x.start < bound;
        }
    }.f);
    var listed: std.ArrayList(usize) = try .initCapacity(ctx.arena, 1024);
    for (at[first..], first..) |x, i| {
        if (x.start >= r.end) break;
        if (r.mask >> @intCast(x.staff) & 1 != 0) try listed.append(ctx.arena, i);
    }
    return listed.items;
}

fn listBookings(ctx: Ctx, query: *const http.Params) !Resp {
    const r = rangeOf(query) orelse return err(400);
    const listed = try select(ctx, h.booking_at, r);
    var o = try rest.out(ctx, listed.len * 1100 + 64);
    if (rest.data.template) {
        try rest.join(&o.writer, "{\"bookings\":[", h.booking_json, listed, "],\"count\":");
        try o.writer.print("{d}}}", .{listed.len});
    } else {
        var jw = rest.stringify(&o.writer);
        try jw.beginObject();
        try jw.objectField("bookings");
        try jw.beginArray();
        for (listed) |i| try jw.write(h.bookings[i]);
        try jw.endArray();
        try jw.objectField("count");
        try jw.write(listed.len);
        try jw.endObject();
    }
    return jsonStatus(200, o.written());
}

fn listShifts(ctx: Ctx, query: *const http.Params) !Resp {
    const r = rangeOf(query) orelse return err(400);
    const listed = try select(ctx, h.shift_at, r);
    var o = try rest.out(ctx, listed.len * 220 + 64);
    if (rest.data.template) {
        try rest.join(&o.writer, "{\"shifts\":[", h.shift_json, listed, "],\"count\":");
        try o.writer.print("{d}}}", .{listed.len});
    } else {
        var jw = rest.stringify(&o.writer);
        try jw.beginObject();
        try jw.objectField("shifts");
        try jw.beginArray();
        for (listed) |i| try jw.write(h.shifts[i]);
        try jw.endArray();
        try jw.objectField("count");
        try jw.write(listed.len);
        try jw.endObject();
    }
    return jsonStatus(200, o.written());
}

// The encounter, and the notes of every visit of its case, oldest first.
fn showEncounter(ctx: Ctx, i: usize) !Resp {
    const first = h.note_first[h.case_first[i]];
    const last = h.note_first[h.case_last[i] + 1];
    var o = try rest.out(ctx, 16 * 1024);
    if (rest.data.template) {
        try o.writer.writeAll(h.visit_json[i]);
        try o.writer.writeAll(",\"caseNotes\":[");
        for (first..last) |j| {
            if (j > first) try o.writer.writeByte(',');
            try o.writer.writeAll(h.note_json[j]);
        }
        try o.writer.writeAll("]}");
    } else {
        var jw = rest.stringify(&o.writer);
        try jw.write(EncounterOut{ .encounter = &h.encounters[i], .case_notes = h.case_notes[first..last] });
    }
    return jsonStatus(200, o.written());
}

// The client's completed visits, newest first, up to limit, and how many
// there are.
fn clientHistory(ctx: Ctx, query: *const http.Params, c: usize) !Resp {
    var limit: usize = 20;
    if (query.get("limit")) |v| {
        const n = rest.parseInt(v) orelse return err(400);
        if (n < 1 or n > 50) return err(400);
        limit = @intCast(n);
    }
    const first = h.past_first[c];
    const count = h.past_count[c];
    const mine = h.past[first .. first + @min(limit, count)];
    var o = try rest.out(ctx, 64 * 1024);
    if (rest.data.template) {
        try o.writer.writeAll("{\"items\":[");
        for (mine, 0..) |e, k| {
            if (k > 0) try o.writer.writeByte(',');
            try o.writer.writeAll(h.visit_json[e]);
            try o.writer.writeByte('}');
        }
        try o.writer.print("],\"total\":{d}}}", .{count});
    } else {
        var jw = rest.stringify(&o.writer);
        try jw.beginObject();
        try jw.objectField("items");
        try jw.beginArray();
        for (mine) |e| try jw.write(h.encounters[e]);
        try jw.endArray();
        try jw.objectField("total");
        try jw.write(count);
        try jw.endObject();
    }
    return jsonStatus(200, o.written());
}

// GET /schedule/version: the schedule's version, the minutes since
// version_epoch, and when it changed to it.
fn scheduleVersion(ctx: Ctx, query: *const http.Params) !Resp {
    const since = query.get("since") orelse return err(400);
    const n = rest.parseInt(since) orelse return err(400);
    if (n < 0) return err(400);
    const version = @divTrunc(rest.nowMs(ctx.io) - h.version_epoch, minute);
    const changed = try rest.isoString(ctx.arena, h.version_epoch + version * minute);
    return jsonStatus(200, rest.marshal(ctx.arena, VersionOut{ .version = version, .changedAt = changed }));
}
