// Tier B, snowtime's k6 hot path, under /api/v1, answered as snowtime's Hono
// routes answer:
//
//   GET   /api/v1/session                        the session, or null
//   GET   /api/v1/timer                          the running timer, or null
//   GET   /api/v1/organizations/:org/entries     ?from=&to=&userId=
//   GET   /api/v1/organizations/:org/projects    ?includeArchived=
//   PATCH /api/v1/organizations/:org/entries/:id {"description"}
//   POST  /api/v1/organizations/:org/timer/start {"id","description",...}
//   POST  /api/v1/timer/stop                     {"id"}
//
// A session cookie names the user, by its token; a write needs Origin to be
// the app's. The data doesn't change: a PATCH answers the entry with the
// description it was sent, and timer start and stop answer as of now, as if
// the timer had started.
//
// The checks run in snowtime's order: an unknown call (main.cpp's fallback),
// a write from another origin (the group's middleware), GET /session, which
// answers null to no one, the sign-in, and the organization's membership.
// Only then are the query and body read.

#include <algorithm>
#include <span>
#include <vector>

#include <glaze/glaze.hpp>

#include "app.h"

namespace app::snow {

namespace {

using aegon::http::Context;
using aegon::http::Method;
using aegon::http::Next;

constexpr std::string_view APP_URL = "https://time.bench.example.com";
constexpr std::string_view SESSION_COOKIE = "__Secure-better-auth.session_token";

// Read with unknown members ignored; written with null members kept.
constexpr glz::opts READ{.error_on_unknown_keys = false};
constexpr glz::opts WRITE{.skip_null_members = false};

struct ProjectFile {
    std::string id;
    std::string name;
    std::optional<std::string> color;
    std::optional<std::string> archivedAt;
    bool hasEntries{};
    std::vector<std::string> teamIds;
};

struct OrgFile {
    std::string id;
    std::string name;
    std::string slug;
    std::optional<std::string> issueLinks;
    std::vector<ProjectFile> projects;
};

struct Settings {
    std::string timeZone;
    std::string weekStart;
    std::string locale;
    std::string theme;
    std::string timerLayout;
    bool showSummary{};
    bool compactRows{};
    bool wideTimer{};
    std::string timerView;
    bool calendarWeekend{};
    std::string appIcon;
    std::string sceneCollection;
    std::optional<std::string> scenePin;
    bool sceneBackground{};
    std::string sceneStrength;
    std::string surfaces;
    bool sceneWeather{};
    bool sceneIntro{};
    bool sceneTagline{};
    std::string durationFormat;
    std::string dateFormat;
    std::string timeFormat;
    std::string copyDurationPattern;
    std::string copyDurationControl;
    std::optional<std::string> country;
};

struct LastDay {
    std::string date;
    bool filled{};
};

struct Fill {
    std::string date;
    std::optional<int64_t> timerStartedAt;
    std::string today;
    std::optional<LastDay> lastWorkingDay;
    std::optional<bool> lastWeek;
    std::optional<bool> lastMonth;
    bool caughtUp{};
    int64_t emptyDays{};
    int64_t streak{};
};

struct MemberFile {
    std::string id;
    std::string role;
};

struct PersonFile {
    std::string id;
    std::string name;
    std::string email;
    std::optional<std::string> image;
    std::string token;
    std::optional<std::string> signedInAt;
    std::vector<MemberFile> organizations;
    std::string activeOrganizationId;
    std::vector<std::string> teamIds;
    Settings settings;
    Fill fill;
};

struct EntryFile {
    std::string id;
    std::string organizationId;
    std::string userId;
    std::optional<std::string> projectId;
    std::string description;
    std::optional<std::string> ticket;
    std::string startedAt;
    std::optional<std::string> stoppedAt;
};

struct Project {
    std::string id;
    std::string name;
    std::optional<std::string> color;
    std::optional<int64_t> archived;
    bool has_entries{};
    std::vector<std::string> teams;
};

struct Org {
    std::string id;
    std::string name;
    std::string slug;
    std::optional<std::string> links;
    size_t first{};  // its projects, projects[first, first + count)
    size_t count{};
};

struct Member {
    size_t org{};
    std::string role;
};

struct Person {
    std::string id;
    std::string name;
    std::string email;
    std::optional<std::string> image;
    std::string token;
    std::optional<int64_t> signed_in;
    std::vector<Member> orgs;  // as the session lists them
    size_t active{};
    std::vector<std::string> teams;  // in the active organization
    Settings settings;
    Fill fill;
    size_t first{};  // the person's entries, entries[first, first + count)
    size_t count{};
    std::optional<size_t> running;
};

struct Entry {
    std::string id;
    size_t user{};
    size_t org{};
    std::optional<size_t> project;
    std::string description;
    std::optional<std::string> ticket;
    int64_t started{};
    std::optional<int64_t> stopped;
};

// An entry's prebuilt JSON, and where its description's value starts and
// ends, for a PATCH to put another there.
struct EntryJson {
    std::string json;
    size_t desc{};
    size_t tail{};
};

// The answers' shapes, borrowing the records' strings.
struct UserOut {
    std::string_view id;
    std::string_view name;
    std::string_view email;
    std::optional<std::string_view> image;
};

struct OrgOut {
    std::string_view id;
    std::string_view name;
    std::string_view slug;
    std::optional<std::string_view> issueLinks;
    std::string_view role;
};

struct SessionOut {
    UserOut user;
    std::optional<std::string> signedInAt;
    std::vector<OrgOut> organizations;
    std::string_view activeOrganizationId;
    const Settings* settings{};
    const Fill* fill{};
    std::optional<int> invitationId;
    std::string_view appUrl;
};

struct ProjectOut {
    std::string_view id;
    std::string_view name;
    std::optional<std::string_view> color;
    std::optional<std::string> archivedAt;
    bool hasEntries{};
    std::span<const std::string> teamIds;
};

struct ProjectRef {
    std::string_view id;
    std::string_view name;
    std::optional<std::string_view> color;
};

struct EntryOut {
    std::string_view id;
    std::string_view organizationId;
    std::string_view userId;
    std::optional<std::string_view> projectId;
    std::string_view description;
    std::optional<std::string_view> ticket;
    std::string startedAt;
    std::optional<std::string> stoppedAt;
};

// GET /timer's: the running entry and its project, or null.
struct TimerOut {
    std::string_view id;
    std::string_view organizationId;
    std::string_view userId;
    std::optional<std::string_view> projectId;
    std::string_view description;
    std::optional<std::string_view> ticket;
    std::string startedAt;
    std::optional<std::string> stoppedAt;
    std::optional<ProjectRef> project;
};

struct StartOut {
    EntryOut started;
    std::optional<EntryOut> stopped;
};

std::vector<Org> orgs;
std::vector<Project> projects;
std::vector<Person> people;
std::vector<Entry> entries;       // by person, then by start
std::vector<size_t> by_token;     // people, by token
std::vector<size_t> by_person_id; // people, by id
std::vector<size_t> by_entry_id;  // entries, by id
bool template_json = false;
// JSON=template's: each session, each running timer as GET /timer answers
// it, each project, and each entry.
std::vector<std::string> session_json;
std::vector<std::string> timer_json;
std::vector<std::string> project_json;
std::vector<EntryJson> entry_json;

[[noreturn]] void stop(std::string_view what) {
    std::fprintf(stderr, "snow: %.*s\n", int(what.size()), what.data());
    std::exit(1);
}

template <class T>
std::vector<T> parse(const std::string& dir, std::string_view name) {
    std::vector<T> out;
    std::string text = read_file(dir, name);
    if (auto ec = glz::read<READ>(out, text)) stop(glz::format_error(ec, text));
    return out;
}

int64_t iso_of(std::string_view s) {
    auto ms = parse_iso(s);
    if (!ms) stop("a time that isn't toISOString's");
    return *ms;
}

std::optional<int64_t> iso_or_null(const std::optional<std::string>& s) {
    if (!s) return std::nullopt;
    return iso_of(*s);
}

std::optional<std::string> iso_opt(std::optional<int64_t> ms) {
    if (!ms) return std::nullopt;
    return iso(*ms);
}

std::optional<std::string_view> view(const std::optional<std::string>& s) {
    if (!s) return std::nullopt;
    return std::string_view(*s);
}

template <class T>
void write_into(std::string& out, const T& value) {
    std::string b;
    (void)glz::write<WRITE>(value, b);
    out.append(b);
}

template <class T>
std::string written(const T& value) {
    std::string b;
    (void)glz::write<WRITE>(value, b);
    return b;
}

bool is_lower_hex(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
}

// snowtime's Uuidv7: 8-4-4-4-12 lower-case hex digits, version 7, variant 8
// to b.
bool is_uuid7(std::string_view s) {
    if (!(s.size() == 36 && s[14] == '7' && (s[19] == '8' || s[19] == '9' || s[19] == 'a' || s[19] == 'b'))) {
        return false;
    }
    for (size_t i = 0; i < s.size(); ++i) {
        bool dash = i == 8 || i == 13 || i == 18 || i == 23;
        if (dash ? s[i] != '-' : !is_lower_hex(s[i])) return false;
    }
    return true;
}

// The time a uuidv7 was made, from its first 48 bits.
int64_t uuid_ms(std::string_view s) {
    int64_t v = 0;
    for (char c : s.substr(0, 13)) {
        if (c == '-') continue;
        v = v * 16 + (c <= '9' ? c - '0' : c - 'a' + 10);
    }
    return v;
}

// snowtime's ticket key: [A-Z][A-Z0-9]{1,9}-[1-9][0-9]{0,6}.
bool is_ticket(std::string_view s) {
    size_t dash = s.find('-');
    if (dash == std::string_view::npos || dash < 2 || dash > 10 || !(s[0] >= 'A' && s[0] <= 'Z')) return false;
    for (char c : s.substr(1, dash - 1)) {
        if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))) return false;
    }
    std::string_view n = s.substr(dash + 1);
    if (n.empty() || n.size() > 7 || !(n[0] >= '1' && n[0] <= '9')) return false;
    return std::all_of(n.begin(), n.end(), [](char c) { return c >= '0' && c <= '9'; });
}

// Trimmed of the whitespace JSON allows, as the Goose server's trim.
std::string_view trim(std::string_view s) {
    size_t a = s.find_first_not_of(" \t\n\r");
    if (a == std::string_view::npos) return {};
    size_t b = s.find_last_not_of(" \t\n\r");
    return s.substr(a, b - a + 1);
}

// A query value with its percent-escapes decoded, or nullopt for a '%'
// without two hex digits after it; '+' stays.
std::optional<std::string> percent_decoded(std::optional<std::string_view> s) {
    if (!s) return std::nullopt;
    std::string out;
    for (size_t i = 0; i < s->size();) {
        char c = (*s)[i];
        if (c == '%') {
            auto hex = [](char h) {
                return h >= '0' && h <= '9' ? h - '0' : h >= 'a' && h <= 'f' ? h - 'a' + 10 : h >= 'A' && h <= 'F' ? h - 'A' + 10 : -1;
            };
            int a = i + 1 < s->size() ? hex((*s)[i + 1]) : -1;
            int b = i + 2 < s->size() ? hex((*s)[i + 2]) : -1;
            if (a < 0 || b < 0) return std::nullopt;
            out.push_back(static_cast<char>(a * 16 + b));
            i += 3;
        } else {
            out.push_back(c);
            ++i;
        }
    }
    return out;
}

bool is_admin(const Member& m) {
    return m.role == "owner" || m.role == "admin";
}

Reply coded(uint16_t status, std::string_view code, std::string_view key) {
    std::string b = "{\"error\":{\"code\":\"";
    b.append(code).append("\",\"key\":\"").append(key).append("\"}}");
    return Reply::json_with(status, std::move(b));
}

// A query or body that doesn't validate.
Reply invalid() {
    return Reply::json_with(400, "{\"error\":{\"message\":\"Invalid input.\"}}");
}

Reply not_json() {
    return Reply::json_with(400, "{\"error\":{\"message\":\"The body is not JSON.\"}}");
}

Reply cross_origin() {
    return Reply::json_with(403, "{\"error\":{\"message\":\"Cross-origin request refused.\"}}");
}

Reply sign_in_required() {
    return coded(401, "UNAUTHENTICATED", "sign_in_required");
}

std::optional<size_t> org_index(std::string_view id) {
    for (size_t i = 0; i < orgs.size(); ++i) {
        if (orgs[i].id == id) return i;
    }
    return std::nullopt;
}

std::optional<size_t> project_index(std::string_view id, size_t org) {
    const Org& o = orgs[org];
    for (size_t i = o.first; i < o.first + o.count; ++i) {
        if (projects[i].id == id) return i;
    }
    return std::nullopt;
}

// k's record in sorted, an index sorted by key(record).
template <class Key>
std::optional<size_t> find_by(const std::vector<size_t>& sorted, std::string_view k, Key key) {
    auto it = std::lower_bound(sorted.begin(), sorted.end(), k,
                               [&](size_t i, std::string_view v) { return key(i) < v; });
    if (it != sorted.end() && key(*it) == k) return *it;
    return std::nullopt;
}

std::optional<size_t> person_index(std::string_view id) {
    return find_by(by_person_id, id, [](size_t i) { return std::string_view(people[i].id); });
}

std::optional<size_t> entry_index(std::string_view id) {
    return find_by(by_entry_id, id, [](size_t i) { return std::string_view(entries[i].id); });
}

// The person the session cookie's value names: a 64-character token, a '.',
// and its signature, which isn't checked.
std::optional<size_t> person(std::optional<std::string_view> cookie) {
    if (!cookie || !(cookie->size() > 65 && (*cookie)[64] == '.')) return std::nullopt;
    return find_by(by_token, cookie->substr(0, 64), [](size_t i) { return std::string_view(people[i].token); });
}

// The signed-in person, by the session cookie.
std::optional<size_t> signed_in(Context& ctx) {
    return person(ctx.req().cookie(SESSION_COOKIE));
}

// Person u's membership of the organization of id org, as an index into
// their orgs.
std::optional<size_t> member(size_t u, std::string_view org) {
    const auto& ms = people[u].orgs;
    for (size_t k = 0; k < ms.size(); ++k) {
        if (orgs[ms[k].org].id == org) return k;
    }
    return std::nullopt;
}

SessionOut session_out(size_t u) {
    const Person& p = people[u];
    std::vector<OrgOut> listed;
    listed.reserve(p.orgs.size());
    for (const Member& m : p.orgs) {
        const Org& o = orgs[m.org];
        listed.push_back({o.id, o.name, o.slug, view(o.links), m.role});
    }
    return SessionOut{{p.id, p.name, p.email, view(p.image)},
                      iso_opt(p.signed_in),
                      std::move(listed),
                      orgs[p.active].id,
                      &p.settings,
                      &p.fill,
                      std::nullopt,
                      APP_URL};
}

ProjectOut project_out(const Project& j) {
    return {j.id, j.name, view(j.color), iso_opt(j.archived), j.has_entries, j.teams};
}

EntryOut entry_out(size_t i, std::string_view description, std::optional<int64_t> stopped) {
    const Entry& e = entries[i];
    std::optional<std::string_view> project;
    if (e.project) project = projects[*e.project].id;
    return {e.id,          orgs[e.org].id, people[e.user].id, project, description,
            view(e.ticket), iso(e.started), iso_opt(stopped)};
}

TimerOut timer_out(size_t i) {
    const Entry& e = entries[i];
    EntryOut o = entry_out(i, e.description, std::nullopt);
    std::optional<ProjectRef> project;
    if (e.project) {
        const Project& j = projects[*e.project];
        project = ProjectRef{j.id, j.name, view(j.color)};
    }
    return {o.id,     o.organizationId, o.userId, o.projectId, o.description, o.ticket, std::move(o.startedAt),
            std::nullopt, project};
}

void entry_into(std::string& out, size_t i) {
    if (template_json) {
        out.append(entry_json[i].json);
    } else {
        const Entry& e = entries[i];
        write_into(out, entry_out(i, e.description, e.stopped));
    }
}

// Running entry i stopped at now, as stopRunning stops it: after it started,
// and at most a day after.
int64_t stopped_at(size_t i, int64_t now) {
    int64_t started = entries[i].started;
    return std::min(std::max(now, started + 1), started + DAY);
}

void stopped_into(std::string& out, size_t i, int64_t now) {
    int64_t at = stopped_at(i, now);
    if (template_json) {
        // A running entry's JSON ends in "null}".
        const std::string& j = entry_json[i].json;
        out.append(j, 0, j.size() - 5);
        push_iso(out, at);
        out.push_back('}');
    } else {
        write_into(out, entry_out(i, entries[i].description, at));
    }
}

// listProjects's visibility: an admin sees every project, a member those
// with no team and those of a team of theirs.
bool sees(const Person& p, const Member& m, const Project& j) {
    if (is_admin(m) || j.teams.empty()) return true;
    if (m.org != p.active) return false;
    for (const auto& t : j.teams) {
        if (std::find(p.teams.begin(), p.teams.end(), t) != p.teams.end()) return true;
    }
    return false;
}

// Prebuilt records joined with ',' between '[' and ']'.
template <class Parts>
std::string joined(const std::vector<size_t>& listed, Parts part) {
    std::string b = "[";
    for (size_t k = 0; k < listed.size(); ++k) {
        if (k > 0) b.push_back(',');
        b.append(part(listed[k]));
    }
    b.push_back(']');
    return b;
}

// A body's members, if it's one JSON object; a member that must be a string
// is refused when it's another value, null included, and an optional one
// when it's neither a string nor null.
struct Body {
    glz::generic doc;

    const glz::generic* field(std::string_view key) const {
        const auto& obj = doc.get_object();
        auto it = obj.find(key);
        return it == obj.end() ? nullptr : &it->second;
    }

    // A member that must be a string if present.
    bool string(std::string_view key, std::optional<std::string>& out) const {
        const glz::generic* v = field(key);
        if (!v) return true;
        if (!v->is_string()) return false;
        out = v->get<std::string>();
        return true;
    }

    // A member that may be a string or null.
    bool nullable(std::string_view key, std::optional<std::string>& out) const {
        const glz::generic* v = field(key);
        if (!v || v->is_null()) return true;
        if (!v->is_string()) return false;
        out = v->get<std::string>();
        return true;
    }
};

std::optional<Body> object_of(std::string_view body) {
    Body b;
    if (!is_object(body) || glz::read_json(b.doc, body) || !b.doc.is_object()) return std::nullopt;
    return b;
}

// GET .../entries: the entries of userId, or of the caller, that overlap
// [from, to), newest first, as listEntries selects them.
Reply list_entries(Context& ctx, size_t u, size_t k) {
    const Person& p = people[u];
    const Member& m = p.orgs[k];
    auto& req = ctx.req();
    auto from_s = percent_decoded(req.query_param("from"));
    auto to_s = percent_decoded(req.query_param("to"));
    auto from = from_s ? parse_iso(*from_s) : std::nullopt;
    auto to = to_s ? parse_iso(*to_s) : std::nullopt;
    if (!from || !to) return invalid();
    if (!(*to > *from && *to - *from <= 93 * DAY)) return invalid();
    std::optional<size_t> who = person_index(p.id);
    if (auto raw = req.query_param("userId")) {
        auto uid = percent_decoded(raw);
        if (!uid || !is_uuid7(*uid)) return invalid();
        if (*uid != p.id) {
            if (!is_admin(m)) return coded(403, "FORBIDDEN", "entries_forbidden");
            who = person_index(*uid);
        }
    }
    std::vector<size_t> listed;
    if (who && people[*who].active == m.org) {
        const Person& w = people[*who];
        auto mine = std::span<const Entry>(entries).subspan(w.first, w.count);
        size_t i = std::partition_point(mine.begin(), mine.end(), [&](const Entry& e) { return e.started < *to; }) -
                   mine.begin();
        while (i > 0 && mine[i - 1].started > *from - DAY) {
            --i;
            if (!mine[i].stopped || *mine[i].stopped > *from) listed.push_back(w.first + i);
        }
    }
    if (template_json) return json(joined(listed, [](size_t i) -> const std::string& { return entry_json[i].json; }));
    std::vector<EntryOut> out;
    out.reserve(listed.size());
    for (size_t i : listed) out.push_back(entry_out(i, entries[i].description, entries[i].stopped));
    return json(written(out));
}

Reply list_projects(Context& ctx, size_t u, size_t k) {
    const Person& p = people[u];
    const Member& m = p.orgs[k];
    auto v = ctx.req().query_param("includeArchived");
    if (v && *v != "true" && *v != "false") return invalid();
    bool archived = v == "true";
    const Org& o = orgs[m.org];
    std::vector<size_t> listed;
    for (size_t i = o.first; i < o.first + o.count; ++i) {
        const Project& j = projects[i];
        if ((archived || !j.archived) && sees(p, m, j)) listed.push_back(i);
    }
    if (template_json) return json(joined(listed, [](size_t i) -> const std::string& { return project_json[i]; }));
    std::vector<ProjectOut> out;
    out.reserve(listed.size());
    for (size_t i : listed) out.push_back(project_out(projects[i]));
    return json(written(out));
}

Reply patch_entry(Context& ctx, size_t u, size_t k) {
    const Person& p = people[u];
    const Member& m = p.orgs[k];
    std::string_view id = *ctx.req().param("id");
    std::string_view body = ctx.req().body();
    if (!is_uuid7(id)) return invalid();
    if (!is_json(body)) return not_json();
    auto patch = object_of(body);
    std::optional<std::string> description_s;
    if (!patch || !patch->string("description", description_s)) return invalid();
    std::optional<std::string_view> description;
    if (description_s) description = trim(*description_s);
    if (description && description->size() > 500) return invalid();
    auto i = entry_index(id);
    if (!i || entries[*i].org != m.org) return coded(404, "NOT_FOUND", "entry_not_found");
    const Entry& e = entries[*i];
    if (people[e.user].id != p.id && !is_admin(m)) return coded(403, "FORBIDDEN", "entry_forbidden");
    std::string buf;
    if (!description) {
        entry_into(buf, *i);
    } else if (template_json) {
        const EntryJson& t = entry_json[*i];
        buf.append(t.json, 0, t.desc);
        write_into(buf, *description);
        buf.append(t.json, t.tail);
    } else {
        write_into(buf, entry_out(*i, *description, e.stopped));
    }
    return json(std::move(buf));
}

// POST .../timer/start: the new entry, started now, and the timer it
// stopped, the caller's running one, or null.
Reply start_timer(Context& ctx, size_t u, size_t k) {
    const Person& p = people[u];
    const Member& m = p.orgs[k];
    std::string_view body = ctx.req().body();
    if (!is_json(body)) return not_json();
    auto start = object_of(body);
    std::optional<std::string> id, description_s, ticket, project_id;
    if (!start || !start->string("id", id) || !start->string("description", description_s) ||
        !start->nullable("ticket", ticket) || !start->nullable("projectId", project_id)) {
        return invalid();
    }
    std::string_view description = description_s ? trim(*description_s) : std::string_view();
    bool ok = description.size() <= 500 && id && is_uuid7(*id) &&
              (!ticket || (ticket->size() <= 18 && is_ticket(*ticket))) && (!project_id || is_uuid7(*project_id));
    if (!ok) return invalid();
    if (project_id) {
        auto j = project_index(*project_id, m.org);
        if (!j || !sees(p, m, projects[*j])) return coded(404, "NOT_FOUND", "project_not_found");
        if (projects[*j].archived) return coded(409, "CONFLICT", "project_archived");
    }
    if (entry_index(*id)) return coded(409, "CONFLICT", "entry_id_taken");
    int64_t now = now_ms();
    EntryOut started{*id, orgs[m.org].id, p.id, view(project_id), description, view(ticket), iso(now), std::nullopt};
    std::string buf;
    if (template_json) {
        buf.append("{\"started\":");
        write_into(buf, started);
        buf.append(",\"stopped\":");
        if (p.running) stopped_into(buf, *p.running, now);
        else buf.append("null");
        buf.push_back('}');
    } else {
        std::optional<EntryOut> stopped;
        if (p.running) stopped = entry_out(*p.running, entries[*p.running].description, stopped_at(*p.running, now));
        write_into(buf, StartOut{std::move(started), std::move(stopped)});
    }
    return json(std::move(buf));
}

// POST /timer/stop: the caller's running entry, stopped now. An id the
// dataset doesn't have is taken for a timer started with it, as timer start
// answered it: a uuidv7 made in the last day.
Reply stop_timer(Context& ctx, size_t u) {
    std::string_view body = ctx.req().body();
    if (!is_json(body)) return not_json();
    auto stop_body = object_of(body);
    std::optional<std::string> id;
    if (!stop_body || !stop_body->string("id", id) || !id || !is_uuid7(*id)) return invalid();
    const Person& p = people[u];
    int64_t now = now_ms();
    std::string buf;
    if (p.running && entries[*p.running].id == *id) {
        stopped_into(buf, *p.running, now);
    } else {
        int64_t started = uuid_ms(*id);
        if (!(started > now - DAY && started <= now + MINUTE && !entry_index(*id))) {
            return coded(404, "NOT_FOUND", "timer_not_running");
        }
        EntryOut out{*id, orgs[p.active].id, p.id, std::nullopt, "", std::nullopt, iso(started),
                     iso(std::min(std::max(now, started + 1), started + DAY))};
        write_into(buf, out);
    }
    return json(std::move(buf));
}

// A route that needs a sign-in: answers 401 without one.
template <class F>
auto signed_route(F f) {
    return [f](Context& ctx) {
        auto u = signed_in(ctx);
        answer(ctx, u ? f(ctx, *u) : sign_in_required());
    };
}

// A route of an organization's: answers 401 without a sign-in, then 403 to
// one who isn't the path's organization's member.
template <class F>
auto member_route(F f) {
    return signed_route([f](Context& ctx, size_t u) {
        auto k = member(u, *ctx.req().param("org"));
        return k ? f(ctx, u, *k) : coded(403, "FORBIDDEN", "not_organization_member");
    });
}

void prebuild() {
    for (size_t u = 0; u < people.size(); ++u) session_json.push_back(written(session_out(u)));
    for (const Person& p : people) timer_json.push_back(p.running ? written(timer_out(*p.running)) : "null");
    for (const Project& j : projects) project_json.push_back(written(project_out(j)));
    for (size_t i = 0; i < entries.size(); ++i) {
        const Entry& e = entries[i];
        std::string j = written(entry_out(i, e.description, e.stopped));
        // A string's quotes are escaped, so these members' keys are the
        // first such bytes.
        size_t desc = j.find(",\"description\":") + 15;
        size_t tail = j.find(",\"ticket\":", desc);
        entry_json.push_back({std::move(j), desc, tail});
    }
}

}  // namespace

void load(const std::string& dir, bool template_) {
    template_json = template_;
    for (OrgFile& o : parse<OrgFile>(dir, "snow-orgs.json")) {
        size_t first = projects.size();
        for (ProjectFile& j : o.projects) {
            projects.push_back({std::move(j.id), std::move(j.name), std::move(j.color), iso_or_null(j.archivedAt),
                                j.hasEntries, std::move(j.teamIds)});
        }
        orgs.push_back({std::move(o.id), std::move(o.name), std::move(o.slug), std::move(o.issueLinks), first,
                        o.projects.size()});
    }
    for (PersonFile& f : parse<PersonFile>(dir, "snow-users.json")) {
        Person p;
        for (MemberFile& m : f.organizations) {
            auto org = org_index(m.id);
            if (!org) stop("a member of an organization snow-orgs.json lacks");
            p.orgs.push_back({*org, std::move(m.role)});
        }
        auto active = org_index(f.activeOrganizationId);
        if (!active) stop("a user without an organization");
        if (f.token.size() != 64) stop("a user without a token");
        p.id = std::move(f.id);
        p.name = std::move(f.name);
        p.email = std::move(f.email);
        p.image = std::move(f.image);
        p.token = std::move(f.token);
        p.signed_in = iso_or_null(f.signedInAt);
        p.active = *active;
        p.teams = std::move(f.teamIds);
        p.settings = std::move(f.settings);
        p.fill = std::move(f.fill);
        people.push_back(std::move(p));
    }
    auto sorted = [](size_t n, auto key) {
        std::vector<size_t> v(n);
        for (size_t i = 0; i < n; ++i) v[i] = i;
        std::sort(v.begin(), v.end(), [&](size_t a, size_t b) { return key(a) < key(b); });
        return v;
    };
    by_token = sorted(people.size(), [](size_t i) { return std::string_view(people[i].token); });
    by_person_id = sorted(people.size(), [](size_t i) { return std::string_view(people[i].id); });
    for (EntryFile& f : parse<EntryFile>(dir, "snow-entries.json")) {
        auto org = org_index(f.organizationId);
        if (!org) stop("an entry of an organization snow-orgs.json lacks");
        auto user = person_index(f.userId);
        if (!user) stop("an entry of a user snow-users.json lacks");
        std::optional<size_t> project;
        if (f.projectId) {
            project = project_index(*f.projectId, *org);
            if (!project) stop("an entry of a project snow-orgs.json lacks");
        }
        int64_t started = iso_of(f.startedAt);
        size_t n = entries.size();
        Person& p = people[*user];
        if (p.count == 0) p.first = n;
        if (p.first + p.count != n) stop("snow-entries.json doesn't have each user's entries together");
        if (p.count != 0 && !(entries[n - 1].started < started)) stop("a user's entries out of order");
        ++p.count;
        auto stopped = iso_or_null(f.stoppedAt);
        if (!stopped) p.running = n;
        entries.push_back({std::move(f.id), *user, *org, project, std::move(f.description), std::move(f.ticket), started,
                           stopped});
    }
    by_entry_id = sorted(entries.size(), [](size_t i) { return std::string_view(entries[i].id); });
    if (template_json) prebuild();
}

size_t records() {
    return entries.size();
}

Reply not_found() {
    return Reply::json_with(404, "{\"error\":{\"message\":\"No such call.\"}}");
}

void routes(aegon::http::Router& router) {
    auto api = router.group("/api/v1");
    // A write needs Origin to be the app's.
    api.use([](Context& ctx, Next next) -> aegon::core::Task<void> {
        Method method = ctx.req().method();
        if (method != Method::GET && method != Method::HEAD && ctx.req().header("origin") != APP_URL) {
            answer(ctx, cross_origin());
            co_return;
        }
        co_await next(ctx);
    });
    api.get("/session", [](Context& ctx) {
        auto u = signed_in(ctx);
        if (!u) answer(ctx, json("null"));
        else if (template_json) answer(ctx, json(session_json[*u]));
        else answer(ctx, json(written(session_out(*u))));
    });
    api.get("/timer", signed_route([](Context&, size_t u) {
        const Person& p = people[u];
        if (template_json) return json(timer_json[u]);
        return json(p.running ? written(timer_out(*p.running)) : "null");
    }));
    api.post("/timer/stop", signed_route(stop_timer));
    api.get("/organizations/:org/entries", member_route(list_entries));
    api.get("/organizations/:org/projects", member_route(list_projects));
    api.patch("/organizations/:org/entries/:id", member_route(patch_entry));
    api.post("/organizations/:org/timer/start", member_route(start_timer));
}

}  // namespace app::snow
