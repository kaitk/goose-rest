// Tier B, snowtime's k6 hot path, under /api/v1, answered as snowtime's Hono
// routes answer (goose-http's bench/rest/hyper/src/snow.rs). The routes are
// `routes`, mounted under /api/v1 behind SameOrigin.
//
// A session cookie names the user, by its token; a write needs Origin to be
// the app's. The data doesn't change: a PATCH answers the entry with the
// description it was sent, and timer start and stop answer as of now, as if
// the timer had started.
const std = @import("std");
const Allocator = std.mem.Allocator;
const http = @import("dusty");
const rest = @import("rest.zig");
const Ctx = rest.Ctx;
const Resp = rest.Resp;
const jsonStatus = rest.jsonStatus;
const day = rest.day;
const minute = rest.minute;

const app_url = "https://time.bench.example.com";
const session_cookie = "__Secure-better-auth.session_token";

const Project = struct {
    id: []const u8,
    name: []const u8,
    color: ?[]const u8 = null,
    archivedAt: ?[]const u8 = null,
    hasEntries: bool,
    teamIds: []const []const u8,
};

const OrgFile = struct {
    id: []const u8,
    name: []const u8,
    slug: []const u8,
    issueLinks: ?[]const u8 = null,
    projects: []Project,
};

const Org = struct {
    id: []const u8,
    name: []const u8,
    slug: []const u8,
    links: ?[]const u8,
    first: usize, // its projects, projects[first..first + count]
    count: usize,
};

const Settings = struct {
    timeZone: []const u8,
    weekStart: []const u8,
    locale: []const u8,
    theme: []const u8,
    timerLayout: []const u8,
    showSummary: bool,
    compactRows: bool,
    wideTimer: bool,
    timerView: []const u8,
    calendarWeekend: bool,
    appIcon: []const u8,
    sceneCollection: []const u8,
    scenePin: ?[]const u8 = null,
    sceneBackground: bool,
    sceneStrength: []const u8,
    surfaces: []const u8,
    sceneWeather: bool,
    sceneIntro: bool,
    sceneTagline: bool,
    durationFormat: []const u8,
    dateFormat: []const u8,
    timeFormat: []const u8,
    copyDurationPattern: []const u8,
    copyDurationControl: []const u8,
    country: ?[]const u8 = null,
};

const LastDay = struct {
    date: []const u8,
    filled: bool,
};

const Fill = struct {
    date: []const u8,
    timerStartedAt: ?i64 = null,
    today: []const u8,
    lastWorkingDay: ?LastDay = null,
    lastWeek: ?bool = null,
    lastMonth: ?bool = null,
    caughtUp: bool,
    emptyDays: i64,
    streak: i64,
};

const MemberFile = struct {
    id: []const u8,
    role: []const u8,
};

const PersonFile = struct {
    id: []const u8,
    name: []const u8,
    email: []const u8,
    image: ?[]const u8 = null,
    token: []const u8,
    signedInAt: ?[]const u8 = null,
    organizations: []MemberFile,
    activeOrganizationId: []const u8,
    teamIds: []const []const u8,
    settings: Settings,
    fill: Fill,
};

const Member = struct {
    org: usize,
    role: []const u8,
};

const Person = struct {
    file: PersonFile,
    orgs: []Member, // as the session lists them
    active: usize,
    first: usize = 0, // the person's entries, entries[first..first + count]
    count: usize = 0,
    running: ?usize = null,
};

// An entry as the routes answer it, and as the file holds it.
const EntryJson = struct {
    id: []const u8,
    organizationId: []const u8,
    userId: []const u8,
    projectId: ?[]const u8 = null,
    description: []const u8,
    ticket: ?[]const u8 = null,
    startedAt: []const u8,
    stoppedAt: ?[]const u8 = null,
};

const Entry = struct {
    json: EntryJson,
    user: usize,
    org: usize,
    started: i64,
    stopped: ?i64,
};

// An entry's prebuilt JSON, and where its description's value starts and
// ends, for a PATCH to put another there.
const EntryPrebuilt = struct {
    json: []u8,
    desc: usize,
    tail: usize,
};

const Index = std.StringHashMapUnmanaged(usize);

const Snow = struct {
    orgs: []Org = &.{},
    projects: std.ArrayList(Project) = .empty,
    people: []Person = &.{},
    entries: std.ArrayList(Entry) = .empty, // by person, then by start
    by_token: Index = .empty,
    by_person_id: Index = .empty,
    by_entry_id: Index = .empty,
    // JSON=template's: each session, each running timer as GET /timer
    // answers it, each project, and each entry.
    session_json: [][]u8 = &.{},
    timer_json: [][]const u8 = &.{},
    project_json: [][]u8 = &.{},
    entry_json: []EntryPrebuilt = &.{},
};

var s: Snow = .{};

const UserOut = struct {
    id: []const u8,
    name: []const u8,
    email: []const u8,
    image: ?[]const u8,
};

const OrgOut = struct {
    id: []const u8,
    name: []const u8,
    slug: []const u8,
    issueLinks: ?[]const u8,
    role: []const u8,
};

// The organizations a session lists, serialized as they're walked.
const OrgsOut = struct {
    orgs: []const Member,

    pub fn jsonStringify(self: OrgsOut, jw: *std.json.Stringify) !void {
        try jw.beginArray();
        for (self.orgs) |m| {
            const o = s.orgs[m.org];
            try jw.write(OrgOut{ .id = o.id, .name = o.name, .slug = o.slug, .issueLinks = o.links, .role = m.role });
        }
        try jw.endArray();
    }
};

const SessionOut = struct {
    user: UserOut,
    signedInAt: ?[]const u8,
    organizations: OrgsOut,
    activeOrganizationId: []const u8,
    settings: *const Settings,
    fill: *const Fill,
    invitationId: ?u8 = null,
    appUrl: []const u8 = app_url,
};

const ProjectRef = struct {
    id: []const u8,
    name: []const u8,
    color: ?[]const u8,
};

// GET /timer's answer: the running entry and its project.
const TimerOut = struct {
    entry: *const EntryJson,
    project: ?ProjectRef,

    pub fn jsonStringify(self: TimerOut, jw: *std.json.Stringify) !void {
        try jw.beginObject();
        try rest.writeFields(jw, self.entry.*);
        try jw.objectField("project");
        try jw.write(self.project);
        try jw.endObject();
    }
};

const StartOut = struct {
    started: EntryJson,
    stopped: ?EntryJson,
};

pub fn load(a: Allocator, io: std.Io, dir: []const u8, template: bool) usize {
    const orgs = rest.readJson([]OrgFile, a, io, dir, "snow-orgs.json");
    s.orgs = a.alloc(Org, orgs.len) catch rest.oom();
    for (orgs, s.orgs) |o, *to| {
        to.* = .{ .id = o.id, .name = o.name, .slug = o.slug, .links = o.issueLinks, .first = s.projects.items.len, .count = o.projects.len };
        s.projects.appendSlice(a, o.projects) catch rest.oom();
    }
    const people = rest.readJson([]PersonFile, a, io, dir, "snow-users.json");
    s.people = a.alloc(Person, people.len) catch rest.oom();
    for (people, s.people, 0..) |p, *to, k| {
        const ms = a.alloc(Member, p.organizations.len) catch rest.oom();
        for (p.organizations, ms) |m, *tm| {
            tm.* = .{ .org = orgIndex(m.id) orelse rest.fatal("a member of an organization snow-orgs.json lacks", .{}), .role = m.role };
        }
        const active = orgIndex(p.activeOrganizationId) orelse rest.fatal("a user without an organization", .{});
        rest.check(p.token.len == 64, "a user without a token");
        to.* = .{ .file = p, .orgs = ms, .active = active };
        s.by_token.put(a, p.token, k) catch rest.oom();
        s.by_person_id.put(a, p.id, k) catch rest.oom();
    }
    const entries = rest.readJson([]EntryJson, a, io, dir, "snow-entries.json");
    s.entries.ensureTotalCapacity(a, entries.len) catch rest.oom();
    for (entries) |e| {
        const org = orgIndex(e.organizationId) orelse rest.fatal("an entry of an organization snow-orgs.json lacks", .{});
        const user = s.by_person_id.get(e.userId) orelse rest.fatal("an entry of a user snow-users.json lacks", .{});
        if (e.projectId) |j| rest.check(projectIndex(j, org) != null, "an entry of a project snow-orgs.json lacks");
        const n = s.entries.items.len;
        const started = rest.mustIso(e.startedAt, "an entry's startedAt");
        const stopped: ?i64 = if (e.stoppedAt) |t| rest.mustIso(t, "an entry's stoppedAt") else null;
        const p = &s.people[user];
        if (p.count == 0) p.first = n;
        rest.check(p.first + p.count == n, "snow-entries.json doesn't have each user's entries together");
        rest.check(p.count == 0 or s.entries.items[n - 1].started < started, "a user's entries out of order");
        p.count += 1;
        if (stopped == null) p.running = n;
        s.entries.appendAssumeCapacity(.{ .json = e, .user = user, .org = org, .started = started, .stopped = stopped });
        s.by_entry_id.put(a, e.id, n) catch rest.oom();
    }
    if (template) prebuild(a);
    return s.entries.items.len;
}

fn prebuild(a: Allocator) void {
    s.session_json = a.alloc([]u8, s.people.len) catch rest.oom();
    s.timer_json = a.alloc([]const u8, s.people.len) catch rest.oom();
    for (s.people, 0..) |p, u| {
        s.session_json[u] = rest.marshal(a, sessionOut(u));
        s.timer_json[u] = if (p.running) |i| rest.marshal(a, timerOut(i)) else "null";
    }
    s.project_json = a.alloc([]u8, s.projects.items.len) catch rest.oom();
    for (s.projects.items, s.project_json) |j, *to| to.* = rest.marshal(a, j);
    s.entry_json = a.alloc(EntryPrebuilt, s.entries.items.len) catch rest.oom();
    for (s.entries.items, s.entry_json) |e, *to| {
        const j = rest.marshal(a, e.json);
        // A string's quotes are escaped, so these members' keys are the first
        // such bytes.
        const desc = std.mem.indexOf(u8, j, ",\"description\":").? + 15;
        const tail = std.mem.indexOfPos(u8, j, desc, ",\"ticket\":").?;
        to.* = .{ .json = j, .desc = desc, .tail = tail };
    }
}

fn orgIndex(id: []const u8) ?usize {
    for (s.orgs, 0..) |o, k| if (std.mem.eql(u8, o.id, id)) return k;
    return null;
}

fn projectIndex(id: []const u8, org: usize) ?usize {
    const o = s.orgs[org];
    for (o.first..o.first + o.count) |k| if (std.mem.eql(u8, s.projects.items[k].id, id)) return k;
    return null;
}

fn sessionOut(u: usize) SessionOut {
    const p = &s.people[u];
    const f = &p.file;
    return .{
        .user = .{ .id = f.id, .name = f.name, .email = f.email, .image = f.image },
        .signedInAt = f.signedInAt,
        .organizations = .{ .orgs = p.orgs },
        .activeOrganizationId = s.orgs[p.active].id,
        .settings = &f.settings,
        .fill = &f.fill,
    };
}

fn timerOut(i: usize) TimerOut {
    const e = &s.entries.items[i];
    var o: TimerOut = .{ .entry = &e.json, .project = null };
    if (e.json.projectId) |j| {
        const p = s.projects.items[projectIndex(j, e.org).?];
        o.project = .{ .id = p.id, .name = p.name, .color = p.color };
    }
    return o;
}

fn isLowerHex(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
}

// snowtime's Uuidv7: 8-4-4-4-12 lower-case hex digits, version 7, variant 8
// to b.
fn isUuid7(id: []const u8) bool {
    if (id.len != 36 or id[14] != '7') return false;
    switch (id[19]) {
        '8', '9', 'a', 'b' => {},
        else => return false,
    }
    for (id, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else if (!isLowerHex(c)) {
            return false;
        }
    }
    return true;
}

// The time a uuidv7 was made, from its first 48 bits.
fn uuidMs(id: []const u8) i64 {
    var v: i64 = 0;
    for (id[0..13]) |c| {
        if (c == '-') continue;
        v = v * 16 + (if (c <= '9') c - '0' else c - 'a' + 10);
    }
    return v;
}

// snowtime's ticket key: [A-Z][A-Z0-9]{1,9}-[1-9][0-9]{0,6}.
fn isTicket(t: []const u8) bool {
    const dash = std.mem.indexOfScalar(u8, t, '-') orelse return false;
    if (dash < 2 or dash > 10 or !(t[0] >= 'A' and t[0] <= 'Z')) return false;
    for (t[1..dash]) |c| if (!((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9'))) return false;
    const n = t[dash + 1 ..];
    if (n.len < 1 or n.len > 7 or n[0] < '1' or n[0] > '9') return false;
    for (n) |c| if (c < '0' or c > '9') return false;
    return true;
}

fn isAdmin(m: Member) bool {
    return std.mem.eql(u8, m.role, "owner") or std.mem.eql(u8, m.role, "admin");
}

fn coded(ctx: Ctx, status: u16, code: []const u8, key: []const u8) !Resp {
    const body = try std.fmt.allocPrint(ctx.arena, "{{\"error\":{{\"code\":\"{s}\",\"key\":\"{s}\"}}}}", .{ code, key });
    return jsonStatus(status, body);
}

fn invalid() Resp {
    return jsonStatus(400, "{\"error\":{\"message\":\"Invalid input.\"}}");
}

fn notJson() Resp {
    return jsonStatus(400, "{\"error\":{\"message\":\"The body is not JSON.\"}}");
}

// The person the session cookie names, read with dusty's cookie reader.
fn personOf(req: *const http.Request) ?usize {
    const v = req.cookies().get(session_cookie) orelse return null;
    if (!(v.len > 65 and v[64] == '.')) return null;
    return s.by_token.get(v[0..64]);
}

// listProjects's visibility: an admin sees every project, a member those
// with no team and those of a team of theirs.
fn sees(p: *const Person, m: Member, j: *const Project) bool {
    if (isAdmin(m) or j.teamIds.len == 0) return true;
    if (m.org != p.active) return false;
    for (j.teamIds) |t| {
        for (p.file.teamIds) |mine| if (std.mem.eql(u8, t, mine)) return true;
    }
    return false;
}

// Tier B's routes, under /api/v1. A request is checked in snowtime's order:
// an unknown call (dusty's not-found), a write from another origin
// (SameOrigin), GET /session, which answers null to no one, the sign-in, and
// the organization's membership.
pub const routes = [_]rest.Route{
    rest.route(.get, "/session", getSession),
    rest.route(.get, "/timer", getTimer),
    rest.route(.post, "/timer/stop", postTimerStop),
    rest.route(.get, "/organizations/:org/entries", getEntries),
    rest.route(.get, "/organizations/:org/projects", getProjects),
    rest.route(.patch, "/organizations/:org/entries/:id", patchEntry),
    rest.route(.post, "/organizations/:org/timer/start", postTimerStart),
};

pub const no_such_call = jsonStatus(404, "{\"error\":{\"message\":\"No such call.\"}}");

// dusty middleware that refuses a write whose Origin isn't the app's.
pub const SameOrigin = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !SameOrigin {
        return .{};
    }

    pub fn execute(_: *const SameOrigin, req: *http.Request, res: *http.Response, executor: anytype) !void {
        const read = req.method == .get or req.method == .head;
        if (!read and !std.mem.eql(u8, req.headers.get("Origin") orelse "", app_url)) {
            return rest.send(res, jsonStatus(403, "{\"error\":{\"message\":\"Cross-origin request refused.\"}}"));
        }
        return executor.next();
    }
};

fn unauthenticated(ctx: Ctx) !Resp {
    return coded(ctx, 401, "UNAUTHENTICATED", "sign_in_required");
}

// The organization of the route's :org, if the person is its member.
fn memberOf(req: *const http.Request, p: *const Person) ?Member {
    const org = rest.param(req, "org");
    for (p.orgs) |x| {
        if (std.mem.eql(u8, s.orgs[x.org].id, org)) return x;
    }
    return null;
}

fn notMember(ctx: Ctx) !Resp {
    return coded(ctx, 403, "FORBIDDEN", "not_organization_member");
}

fn getSession(req: *http.Request) !Resp {
    const u = personOf(req) orelse return jsonStatus(200, "null");
    if (templated()) return jsonStatus(200, s.session_json[u]);
    var o = try rest.out(rest.ctxOf(req), 4096);
    var jw = rest.stringify(&o.writer);
    try jw.write(sessionOut(u));
    return jsonStatus(200, o.written());
}

fn getTimer(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const u = personOf(req) orelse return unauthenticated(ctx);
    if (templated()) return jsonStatus(200, s.timer_json[u]);
    const i = s.people[u].running orelse return jsonStatus(200, "null");
    var o = try rest.out(ctx, 1024);
    var jw = rest.stringify(&o.writer);
    try jw.write(timerOut(i));
    return jsonStatus(200, o.written());
}

fn postTimerStop(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const u = personOf(req) orelse return unauthenticated(ctx);
    const body = try rest.bodyOf(req) orelse return rest.too_large;
    return stopTimer(ctx, body, u);
}

fn getEntries(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const p = &s.people[personOf(req) orelse return unauthenticated(ctx)];
    const m = memberOf(req, p) orelse return notMember(ctx);
    return listEntries(ctx, &req.query, p, m);
}

fn getProjects(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const p = &s.people[personOf(req) orelse return unauthenticated(ctx)];
    const m = memberOf(req, p) orelse return notMember(ctx);
    return listProjects(ctx, &req.query, p, m);
}

fn patchEntry(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const p = &s.people[personOf(req) orelse return unauthenticated(ctx)];
    const m = memberOf(req, p) orelse return notMember(ctx);
    const body = try rest.bodyOf(req) orelse return rest.too_large;
    return editEntry(ctx, rest.param(req, "id"), body, p, m);
}

fn postTimerStart(req: *http.Request) !Resp {
    const ctx = rest.ctxOf(req);
    const u = personOf(req) orelse return unauthenticated(ctx);
    const m = memberOf(req, &s.people[u]) orelse return notMember(ctx);
    const body = try rest.bodyOf(req) orelse return rest.too_large;
    return startTimer(ctx, body, u, m);
}

// GET .../entries: the entries of userId, or of the caller, that overlap
// [from, to), newest first, as listEntries selects them. dusty has decoded
// the query.
fn listEntries(ctx: Ctx, query: *const http.Params, p: *const Person, m: Member) !Resp {
    const f = query.get("from") orelse return invalid();
    const t = query.get("to") orelse return invalid();
    const from = rest.parseIso(f) orelse return invalid();
    const to = rest.parseIso(t) orelse return invalid();
    if (!(to > from and to - from <= 93 * day)) return invalid();
    var who = s.by_person_id.get(p.file.id);
    if (query.get("userId")) |uid| {
        if (!isUuid7(uid)) return invalid();
        if (!std.mem.eql(u8, uid, p.file.id)) {
            if (!isAdmin(m)) return coded(ctx, 403, "FORBIDDEN", "entries_forbidden");
            who = s.by_person_id.get(uid);
        }
    }
    var listed: std.ArrayList(usize) = try .initCapacity(ctx.arena, 64);
    if (who) |wi| if (s.people[wi].active == m.org) {
        const w = &s.people[wi];
        const mine = s.entries.items[w.first .. w.first + w.count];
        var i = std.sort.partitionPoint(Entry, mine, to, struct {
            fn before(bound: i64, e: Entry) bool {
                return e.started < bound;
            }
        }.before);
        while (i > 0 and mine[i - 1].started > from - day) {
            i -= 1;
            if (mine[i].stopped == null or mine[i].stopped.? > from) try listed.append(ctx.arena, w.first + i);
        }
    };
    var o = try rest.out(ctx, 16 * 1024);
    if (templated()) {
        try o.writer.writeByte('[');
        for (listed.items, 0..) |i, k| {
            if (k > 0) try o.writer.writeByte(',');
            try o.writer.writeAll(s.entry_json[i].json);
        }
        try o.writer.writeByte(']');
    } else {
        var jw = rest.stringify(&o.writer);
        try jw.beginArray();
        for (listed.items) |i| try jw.write(s.entries.items[i].json);
        try jw.endArray();
    }
    return jsonStatus(200, o.written());
}

fn templated() bool {
    return rest.data.template;
}

fn listProjects(ctx: Ctx, query: *const http.Params, p: *const Person, m: Member) !Resp {
    const v = query.get("includeArchived");
    if (v) |x| if (!std.mem.eql(u8, x, "true") and !std.mem.eql(u8, x, "false")) return invalid();
    const archived = v != null and std.mem.eql(u8, v.?, "true");
    const o = s.orgs[m.org];
    var listed: std.ArrayList(usize) = try .initCapacity(ctx.arena, o.count);
    for (o.first..o.first + o.count) |i| {
        const j = &s.projects.items[i];
        if ((archived or j.archivedAt == null) and sees(p, m, j)) listed.appendAssumeCapacity(i);
    }
    var w = try rest.out(ctx, 4096);
    if (templated()) {
        try rest.join(&w.writer, "[", s.project_json, listed.items, "]");
    } else {
        var jw = rest.stringify(&w.writer);
        try jw.beginArray();
        for (listed.items) |i| try jw.write(s.projects.items[i]);
        try jw.endArray();
    }
    return jsonStatus(200, w.written());
}

// What a member that must be a string if present reads as: absent, the
// string, or wrong, null included.
const Str = union(enum) { absent, value: []const u8, wrong };

fn stringMember(obj: std.json.ObjectMap, key: []const u8) Str {
    const v = obj.get(key) orelse return .absent;
    return if (v == .string) .{ .value = v.string } else .wrong;
}

// A member that may be absent or null, or else a string.
fn optionalString(obj: std.json.ObjectMap, key: []const u8) Str {
    const v = obj.get(key) orelse return .absent;
    if (v == .null) return .absent;
    return if (v == .string) .{ .value = v.string } else .wrong;
}

// body as a JSON object: notJson for a body that isn't JSON, and invalid for
// one that isn't an object.
fn bodyObject(ctx: Ctx, body: []const u8, refused: *Resp) ?std.json.ObjectMap {
    const v = rest.parseWhole(ctx.arena, body) orelse {
        refused.* = notJson();
        return null;
    };
    if (v != .object or !rest.isObject(body)) {
        refused.* = invalid();
        return null;
    }
    return v.object;
}

fn editEntry(ctx: Ctx, id: []const u8, body: []const u8, p: *const Person, m: Member) !Resp {
    if (!isUuid7(id)) return invalid();
    var refused: Resp = undefined;
    const obj = bodyObject(ctx, body, &refused) orelse return refused;
    const desc: ?[]const u8 = switch (stringMember(obj, "description")) {
        .absent => null,
        .value => |d| rest.trimWs(d),
        .wrong => return invalid(),
    };
    if (desc) |d| if (d.len > 500) return invalid();
    const i = s.by_entry_id.get(id) orelse return coded(ctx, 404, "NOT_FOUND", "entry_not_found");
    if (s.entries.items[i].org != m.org) return coded(ctx, 404, "NOT_FOUND", "entry_not_found");
    const e = &s.entries.items[i];
    if (!std.mem.eql(u8, s.people[e.user].file.id, p.file.id) and !isAdmin(m)) {
        return coded(ctx, 403, "FORBIDDEN", "entry_forbidden");
    }
    const d = desc orelse {
        if (templated()) return jsonStatus(200, s.entry_json[i].json);
        return jsonStatus(200, rest.marshal(ctx.arena, e.json));
    };
    var o = try rest.out(ctx, 512 + d.len);
    if (templated()) {
        const t = s.entry_json[i];
        try o.writer.writeAll(t.json[0..t.desc]);
        try rest.writeString(&o.writer, d);
        try o.writer.writeAll(t.json[t.tail..]);
    } else {
        var x = e.json;
        x.description = d;
        var jw = rest.stringify(&o.writer);
        try jw.write(x);
    }
    return jsonStatus(200, o.written());
}

// Running entry i stopped at now, as stopRunning stops it: after it started,
// and at most a day after.
fn stoppedAt(i: usize, now: i64) i64 {
    const started = s.entries.items[i].started;
    return @min(@max(now, started + 1), started + day);
}

fn writeStopped(ctx: Ctx, w: *std.Io.Writer, i: usize, now: i64) !void {
    const at = stoppedAt(i, now);
    if (templated()) {
        // A running entry's JSON ends in "null}".
        const j = s.entry_json[i].json;
        try w.writeAll(j[0 .. j.len - 5]);
        try rest.writeIso(w, at);
        try w.writeByte('}');
    } else {
        var x = s.entries.items[i].json;
        x.stoppedAt = try rest.isoString(ctx.arena, at);
        var jw = rest.stringify(w);
        try jw.write(x);
    }
}

// POST .../timer/start: the new entry, started now, and the timer it
// stopped, the caller's running one, or null.
fn startTimer(ctx: Ctx, body: []const u8, u: usize, m: Member) !Resp {
    var refused: Resp = undefined;
    const obj = bodyObject(ctx, body, &refused) orelse return refused;
    const id = stringMember(obj, "id");
    const desc_in = stringMember(obj, "description");
    const ticket = optionalString(obj, "ticket");
    const project = optionalString(obj, "projectId");
    if (id == .wrong or desc_in == .wrong or ticket == .wrong or project == .wrong) return invalid();
    const desc = rest.trimWs(if (desc_in == .value) desc_in.value else "");
    const valid = desc.len <= 500 and id == .value and isUuid7(id.value) and
        (ticket != .value or (ticket.value.len <= 18 and isTicket(ticket.value))) and
        (project != .value or isUuid7(project.value));
    if (!valid) return invalid();
    const p = &s.people[u];
    if (project == .value) {
        const j = projectIndex(project.value, m.org) orelse return coded(ctx, 404, "NOT_FOUND", "project_not_found");
        if (!sees(p, m, &s.projects.items[j])) return coded(ctx, 404, "NOT_FOUND", "project_not_found");
        if (s.projects.items[j].archivedAt != null) return coded(ctx, 409, "CONFLICT", "project_archived");
    }
    if (s.by_entry_id.contains(id.value)) return coded(ctx, 409, "CONFLICT", "entry_id_taken");
    const now = rest.nowMs(ctx.io);
    const started: EntryJson = .{
        .id = id.value,
        .organizationId = s.orgs[m.org].id,
        .userId = p.file.id,
        .projectId = if (project == .value) project.value else null,
        .description = desc,
        .ticket = if (ticket == .value) ticket.value else null,
        .startedAt = try rest.isoString(ctx.arena, now),
    };
    var o = try rest.out(ctx, 1024);
    if (templated()) {
        try o.writer.writeAll("{\"started\":");
        var jw = rest.stringify(&o.writer);
        try jw.write(started);
        try o.writer.writeAll(",\"stopped\":");
        if (p.running) |i| try writeStopped(ctx, &o.writer, i, now) else try o.writer.writeAll("null");
        try o.writer.writeByte('}');
    } else {
        var x: StartOut = .{ .started = started, .stopped = null };
        if (p.running) |i| {
            var stopped = s.entries.items[i].json;
            stopped.stoppedAt = try rest.isoString(ctx.arena, stoppedAt(i, now));
            x.stopped = stopped;
        }
        var jw = rest.stringify(&o.writer);
        try jw.write(x);
    }
    return jsonStatus(200, o.written());
}

// POST /timer/stop: the caller's running entry, stopped now. An id the
// dataset doesn't have is taken for a timer started with it, as timer start
// answered it: a uuidv7 made in the last day.
fn stopTimer(ctx: Ctx, body: []const u8, u: usize) !Resp {
    var refused: Resp = undefined;
    const obj = bodyObject(ctx, body, &refused) orelse return refused;
    const id = switch (stringMember(obj, "id")) {
        .value => |v| v,
        else => return invalid(),
    };
    if (!isUuid7(id)) return invalid();
    const p = &s.people[u];
    const now = rest.nowMs(ctx.io);
    var o = try rest.out(ctx, 512);
    if (p.running) |i| if (std.mem.eql(u8, s.entries.items[i].json.id, id)) {
        try writeStopped(ctx, &o.writer, i, now);
        return jsonStatus(200, o.written());
    };
    const started = uuidMs(id);
    if (!(started > now - day and started <= now + minute and !s.by_entry_id.contains(id))) {
        return coded(ctx, 404, "NOT_FOUND", "timer_not_running");
    }
    const x: EntryJson = .{
        .id = id,
        .organizationId = s.orgs[p.active].id,
        .userId = p.file.id,
        .description = "",
        .startedAt = try rest.isoString(ctx.arena, started),
        .stoppedAt = try rest.isoString(ctx.arena, @min(@max(now, started + 1), started + day)),
    };
    var jw = rest.stringify(&o.writer);
    try jw.write(x);
    return jsonStatus(200, o.written());
}
