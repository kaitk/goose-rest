// Tier C, a clinic's schedule and records, under /api/v2, behind a bearer JWT
// that isn't verified:
//
//   GET   /api/v2/schedule/version               ?since=, the schedule's poll
//   GET   /api/v2/schedule/bookings              ?start=&end=&staff=1,2,...
//   GET   /api/v2/schedule/shifts                ?start=&end=&staff=1,2,...
//   GET   /api/v2/encounters/:id                 the visit, and its case's notes
//   GET   /api/v2/clients/:id/encounters         ?limit=, the past visits
//   GET   /api/v2/clients/:id                    the client
//
// Ids are 1, 2, ... in each file, and the schedule's days are UTC's. The
// route group's middleware checks the bearer token on the routes it has;
// main.cpp's fallback answers a path or method none takes with not_found
// before any token is looked at.

#include "heavy.h"

#include <algorithm>
#include <array>
#include <ranges>
#include <span>
#include <vector>

namespace app::heavy {

namespace {

using aegon::http::Context;

constexpr std::array<std::string_view, 4> NOTE_KINDS = {"intake", "findings", "plan", "internal"};

constexpr glz::opts READ{.error_on_unknown_keys = false};
// A booking's or a shift's note is null when it has none.
constexpr glz::opts WRITE{.skip_null_members = false};

struct Meta {
    int64_t versionEpoch{};
};

struct Staffer {
    size_t id{};
    std::string name;
    std::string title;
};

struct Service {
    std::string code;
    std::string name;
    int64_t minutes{};
    int64_t price{};
};

struct Address {
    std::string street;
    std::string city;
    std::string postcode;
};

struct Preferences {
    std::string channel;
    std::string language;
};

struct Contact {
    std::string name;
    std::string phone;
    std::string relation;
};

struct Consents {
    bool sms{};
    bool email{};
    bool research{};
};

struct Client {
    size_t id{};
    std::string name;
    std::string code;
    std::string born;
    std::string phone;
    std::string email;
    Address address;
    Preferences preferences;
    std::vector<std::string> flags;
    Contact emergencyContact;
    Consents consents;
    Iso createdAt;
    Iso updatedAt;
};

// The id of an object such as {"id":3,"name":...}.
struct Ref {
    size_t id{};
};

struct LineFile {
    int64_t id{};
    std::string code;
};

struct Line {
    int64_t id;
    size_t service;
};

struct NoteFile {
    int64_t id{};
    Ref author;
    std::string text;
    Iso at;
};

struct NotesFile {
    std::vector<NoteFile> intake;
    std::vector<NoteFile> findings;
    std::vector<NoteFile> plan;
    std::vector<NoteFile> internal;
};

struct VisitFile {
    size_t id{};
    int64_t caseId{};
    Ref client;
    Ref staff;
    std::string status;
    std::string kind;
    std::string priority;
    Iso start;
    Iso end;
    std::vector<LineFile> items;
    std::vector<std::string> codes;
    NotesFile notes;
};

struct Note {
    int64_t id;
    size_t visit;
    size_t kind;
    size_t author;
    int64_t at;
    std::string text;
};

struct Visit {
    int64_t case_id;
    size_t client;
    size_t staff;
    std::string status;
    std::string kind;
    std::string priority;
    int64_t start;
    int64_t end;
    std::vector<Line> lines;
    std::vector<std::string> codes;
    size_t first_note;  // notes[first_note, first_note + notes), by kind
    size_t notes;
    size_t case_first;  // the case's visits, visits[case_first, case_first + case_count)
    size_t case_count;
};

struct Reminder {
    std::string channel;
    std::string kind;
    std::string status;
    Iso at;
};

struct Slot {
    Iso start;
    Iso end;
};

struct BookingFile {
    size_t id{};
    Slot slot;
    Ref client;
    Ref staff;
    Ref encounter;
    std::vector<LineFile> items;
    std::vector<Reminder> reminders;
    std::string status;
    std::string source;
    std::optional<std::string> note;
    Iso createdAt;
    Iso updatedAt;
};

struct Booking {
    int64_t start;
    int64_t end;
    size_t client;
    size_t staff;
    size_t visit;
    std::vector<Line> lines;
    std::vector<Reminder> reminders;
    std::string status;
    std::string source;
    std::optional<std::string> note;
    int64_t created;
    int64_t updated;
};

struct Room {
    int64_t id{};
    std::string name;
};

struct ShiftFile {
    size_t id{};
    Ref staff;
    Iso start;
    Iso end;
    std::string kind;
    Room room;
    std::optional<std::string> note;
};

struct Shift {
    size_t staff;
    int64_t start;
    int64_t end;
    std::string kind;
    Room room;
    std::optional<std::string> note;
};

// What the answers write, borrowing the records' strings.
struct StaffRef {
    size_t id;
    std::string_view name;
};

struct StaffTitled {
    size_t id;
    std::string_view name;
    std::string_view title;
};

struct ClientRef {
    size_t id;
    std::string_view name;
    std::string_view code;
};

struct LineOut {
    int64_t id;
    std::string_view code;
    std::string_view name;
    int64_t minutes;
    int64_t price;
};

struct EncounterRef {
    size_t id;
    std::string_view status;
    Iso start;
    Iso end;
};

struct RoomOut {
    int64_t id;
    std::string_view name;
};

template <class L>
struct BookingOut {
    size_t id;
    Slot slot;
    ClientRef client;
    StaffRef staff;
    EncounterRef encounter;
    L items;
    std::span<const Reminder> reminders;
    std::string_view status;
    std::string_view source;
    std::optional<std::string_view> note;
    Iso createdAt;
    Iso updatedAt;

    // Glaze's reflection can't count the members of a struct holding a view,
    // so the templates below name theirs.
    struct glaze {
        using T = BookingOut;
        static constexpr auto value =
            glz::object("id", &T::id, "slot", &T::slot, "client", &T::client, "staff", &T::staff, "encounter",
                        &T::encounter, "items", &T::items, "reminders", &T::reminders, "status", &T::status, "source",
                        &T::source, "note", &T::note, "createdAt", &T::createdAt, "updatedAt", &T::updatedAt);
    };
};

struct ShiftOut {
    size_t id;
    StaffRef staff;
    Iso start;
    Iso end;
    std::string_view kind;
    RoomOut room;
    std::optional<std::string_view> note;
};

struct NoteOut {
    int64_t id;
    StaffTitled author;
    std::string_view text;
    Iso at;
};

struct CaseNoteOut {
    int64_t id;
    size_t encounterId;
    std::string_view kind;
    StaffTitled author;
    std::string_view text;
    Iso at;
};

template <class N>
struct NotesOut {
    N intake;
    N findings;
    N plan;
    N internal;

    struct glaze {
        using T = NotesOut;
        static constexpr auto value = glz::object("intake", &T::intake, "findings", &T::findings, "plan", &T::plan,
                                                  "internal", &T::internal);
    };
};

template <class L, class N>
struct VisitOut {
    size_t id;
    int64_t caseId;
    ClientRef client;
    StaffTitled staff;
    std::string_view status;
    std::string_view kind;
    std::string_view priority;
    Iso start;
    Iso end;
    L items;
    std::span<const std::string> codes;
    NotesOut<N> notes;

    struct glaze {
        using T = VisitOut;
        static constexpr auto value =
            glz::object("id", &T::id, "caseId", &T::caseId, "client", &T::client, "staff", &T::staff, "status",
                        &T::status, "kind", &T::kind, "priority", &T::priority, "start", &T::start, "end", &T::end,
                        "items", &T::items, "codes", &T::codes, "notes", &T::notes);
    };
};

// GET /encounters/:id's: the visit, and the notes of every visit of its case.
template <class L, class N, class C>
struct EncounterOut {
    size_t id;
    int64_t caseId;
    ClientRef client;
    StaffTitled staff;
    std::string_view status;
    std::string_view kind;
    std::string_view priority;
    Iso start;
    Iso end;
    L items;
    std::span<const std::string> codes;
    NotesOut<N> notes;
    C caseNotes;

    struct glaze {
        using T = EncounterOut;
        static constexpr auto value =
            glz::object("id", &T::id, "caseId", &T::caseId, "client", &T::client, "staff", &T::staff, "status",
                        &T::status, "kind", &T::kind, "priority", &T::priority, "start", &T::start, "end", &T::end,
                        "items", &T::items, "codes", &T::codes, "notes", &T::notes, "caseNotes", &T::caseNotes);
    };
};

template <class L>
struct BookingsOut {
    L bookings;
    size_t count;

    struct glaze {
        using T = BookingsOut;
        static constexpr auto value = glz::object("bookings", &T::bookings, "count", &T::count);
    };
};

template <class L>
struct ShiftsOut {
    L shifts;
    size_t count;

    struct glaze {
        using T = ShiftsOut;
        static constexpr auto value = glz::object("shifts", &T::shifts, "count", &T::count);
    };
};

template <class L>
struct HistoryOut {
    L items;
    size_t total;

    struct glaze {
        using T = HistoryOut;
        static constexpr auto value = glz::object("items", &T::items, "total", &T::total);
    };
};

struct VersionOut {
    int64_t version;
    Iso changedAt;
};

std::vector<Staffer> staffers;
std::vector<Service> services;
std::vector<Client> clients;
// Each client's completed visits, newest first: past[first[c], first[c] + count[c]).
std::vector<size_t> first;
std::vector<size_t> count;
std::vector<Visit> visits;
std::vector<Note> notes;
std::vector<Booking> bookings;  // by start
std::vector<Shift> shifts;      // by start
std::vector<size_t> past;       // completed visits, by client, newest first
int64_t version_epoch = 0;
bool template_json = false;
// JSON=template's: each booking, shift, and client whole; each visit without
// its closing brace; and each note as caseNotes lists it.
std::vector<std::string> booking_json;
std::vector<std::string> shift_json;
std::vector<std::string> client_json;
std::vector<std::string> visit_json;
std::vector<std::string> note_json;

[[noreturn]] void stop(std::string_view what) {
    std::fprintf(stderr, "%.*s\n", int(what.size()), what.data());
    std::exit(1);
}

template <class T>
T file(const std::string& dir, std::string_view name) {
    T out{};
    std::string text = read_file(dir, name);
    if (auto ec = glz::read<READ>(out, text)) {
        stop(std::string(name) + ": " + glz::format_error(ec, text));
    }
    return out;
}

// An id of 1..=n in a file as an index.
size_t id_in(size_t id, size_t n, std::string_view what) {
    if (id < 1 || id > n) stop(std::string("a ") + std::string(what) + " id that isn't one of 1.." + std::to_string(n));
    return id - 1;
}

template <class T>
std::string written(const T& value) {
    std::string b;
    (void)glz::write<WRITE>(value, b);
    return b;
}

StaffRef staff_ref(size_t s) {
    return {s + 1, staffers[s].name};
}

StaffTitled staff_titled(size_t s) {
    return {s + 1, staffers[s].name, staffers[s].title};
}

ClientRef client_ref(size_t c) {
    return {c + 1, clients[c].name, clients[c].code};
}

auto lines_out(const std::vector<Line>& lines) {
    return lines | std::views::transform([](const Line& l) {
               const Service& s = services[l.service];
               return LineOut{l.id, s.code, s.name, s.minutes, s.price};
           });
}

std::optional<std::string_view> note_of(const std::optional<std::string>& n) {
    if (n) return std::string_view(*n);
    return std::nullopt;
}

auto booking_out(size_t i) {
    const Booking& b = bookings[i];
    const Visit& v = visits[b.visit];
    return BookingOut{i + 1,
                      Slot{{b.start}, {b.end}},
                      client_ref(b.client),
                      staff_ref(b.staff),
                      EncounterRef{b.visit + 1, v.status, {v.start}, {v.end}},
                      lines_out(b.lines),
                      std::span<const Reminder>(b.reminders),
                      b.status,
                      b.source,
                      note_of(b.note),
                      {b.created},
                      {b.updated}};
}

ShiftOut shift_out(size_t i) {
    const Shift& s = shifts[i];
    return {i + 1, staff_ref(s.staff), {s.start}, {s.end}, s.kind, {s.room.id, s.room.name}, note_of(s.note)};
}

CaseNoteOut case_note_out(const Note& n) {
    return {n.id, n.visit + 1, NOTE_KINDS[n.kind], staff_titled(n.author), n.text, {n.at}};
}

auto notes_of_kind(std::span<const Note> ns) {
    return ns | std::views::transform([](const Note& n) {
               return NoteOut{n.id, staff_titled(n.author), n.text, {n.at}};
           });
}

// A visit's notes by kind, each kind's notes together in the order of
// NOTE_KINDS.
auto notes_out(const Visit& v) {
    std::span<const Note> rest(notes.data() + v.first_note, v.notes);
    std::array<std::span<const Note>, 4> by_kind;
    for (size_t kind = 0; kind < NOTE_KINDS.size(); ++kind) {
        size_t k = std::ranges::partition_point(rest, [&](const Note& n) { return n.kind == kind; }) - rest.begin();
        by_kind[kind] = rest.first(k);
        rest = rest.subspan(k);
    }
    return NotesOut{notes_of_kind(by_kind[0]), notes_of_kind(by_kind[1]), notes_of_kind(by_kind[2]),
                    notes_of_kind(by_kind[3])};
}

// The case's notes, oldest visit first.
std::span<const Note> case_notes(const Visit& v) {
    const Visit& f = visits[v.case_first];
    const Visit& l = visits[v.case_first + v.case_count - 1];
    return std::span<const Note>(notes).subspan(f.first_note, l.first_note + l.notes - f.first_note);
}

auto visit_out(size_t i) {
    const Visit& v = visits[i];
    return VisitOut{i + 1, v.case_id, client_ref(v.client), staff_titled(v.staff), v.status, v.kind, v.priority,
                    {v.start}, {v.end}, lines_out(v.lines), std::span<const std::string>(v.codes), notes_out(v)};
}

auto encounter_out(size_t i) {
    const Visit& v = visits[i];
    return EncounterOut{i + 1, v.case_id, client_ref(v.client), staff_titled(v.staff), v.status, v.kind, v.priority,
                        {v.start}, {v.end}, lines_out(v.lines), std::span<const std::string>(v.codes), notes_out(v),
                        case_notes(v) | std::views::transform(case_note_out)};
}

// Prebuilt records joined with ',' between open and close.
void join(std::string& out, std::string_view open, const std::vector<size_t>& listed,
          const std::vector<std::string>& json, std::string_view close) {
    out.append(open);
    for (size_t k = 0; k < listed.size(); ++k) {
        if (k > 0) out.push_back(',');
        out.append(json[listed[k]]);
    }
    out.append(close);
}

// A start and an end day, end after start and at most 31 days on, and the
// staff of a list of their ids as bits.
struct Range {
    int64_t start;
    int64_t end;
    uint64_t mask;
};

std::optional<std::string> query(const aegon::http::Request& req, std::string_view key) {
    if (auto v = req.query_param(key)) return aegon::http::Request::url_decode(*v);
    return std::nullopt;
}

std::optional<Range> range_of(const aegon::http::Request& req) {
    auto s = query(req, "start"), e = query(req, "end"), list = query(req, "staff");
    if (!s || !e || !list) return std::nullopt;
    auto start = parse_day(*s), end = parse_day(*e);
    if (!start || !end || !(*end > *start && *end - *start <= 31 * DAY) || list->empty()) return std::nullopt;
    uint64_t mask = 0;
    for (auto id : std::views::split(*list, ',')) {
        auto n = parse_int(std::string_view(id.begin(), id.end()));
        if (!n || *n < 1 || static_cast<size_t>(*n) > staffers.size()) return std::nullopt;
        mask |= uint64_t{1} << (*n - 1);
    }
    return Range{*start, *end, mask};
}

// The indices of records by start in [start, end) of the mask's staff.
template <class T>
std::vector<size_t> select(const std::vector<T>& records, const Range& r) {
    auto first = std::ranges::partition_point(records, [&](const T& x) { return x.start < r.start; });
    std::vector<size_t> out;
    for (auto it = first; it != records.end() && it->start < r.end; ++it) {
        if (r.mask >> it->staff & 1) out.push_back(static_cast<size_t>(it - records.begin()));
    }
    return out;
}

Reply list_bookings(const aegon::http::Request& req) {
    auto range = range_of(req);
    if (!range) return bad_request();
    auto listed = select(bookings, *range);
    std::string b;
    if (template_json) {
        join(b, "{\"bookings\":[", listed, booking_json, "],\"count\":");
        push_int(b, static_cast<int64_t>(listed.size()));
        b.push_back('}');
    } else {
        (void)glz::write<WRITE>(BookingsOut{listed | std::views::transform(booking_out), listed.size()}, b);
    }
    return json(std::move(b));
}

Reply list_shifts(const aegon::http::Request& req) {
    auto range = range_of(req);
    if (!range) return bad_request();
    auto listed = select(shifts, *range);
    std::string b;
    if (template_json) {
        join(b, "{\"shifts\":[", listed, shift_json, "],\"count\":");
        push_int(b, static_cast<int64_t>(listed.size()));
        b.push_back('}');
    } else {
        (void)glz::write<WRITE>(ShiftsOut{listed | std::views::transform(shift_out), listed.size()}, b);
    }
    return json(std::move(b));
}

// The encounter, and the notes of every visit of its case, oldest first.
Reply show_encounter(std::string_view id) {
    auto n = parse_uint(id);
    auto i = n ? index_of(*n, visits.size()) : std::nullopt;
    if (!i) return not_found();
    std::string b;
    if (template_json) {
        const Visit& v = visits[*i];
        size_t first_note = visits[v.case_first].first_note;
        size_t m = case_notes(v).size();
        b.append(visit_json[*i]);
        b.append(",\"caseNotes\":[");
        for (size_t j = first_note; j < first_note + m; ++j) {
            if (j > first_note) b.push_back(',');
            b.append(note_json[j]);
        }
        b.append("]}");
    } else {
        (void)glz::write<WRITE>(encounter_out(*i), b);
    }
    return json(std::move(b));
}

// The client's completed visits, newest first, up to limit, and how many
// there are. The client is looked up before the query is read.
Reply client_history(std::string_view id, const aegon::http::Request& req) {
    auto n = parse_uint(id);
    auto c = n ? index_of(*n, clients.size()) : std::nullopt;
    if (!c) return not_found();
    size_t limit = 20;
    if (auto v = query(req, "limit")) {
        auto l = parse_int(*v);
        if (!l || *l < 1 || *l > 50) return bad_request();
        limit = static_cast<size_t>(*l);
    }
    std::span<const size_t> mine(past.data() + first[*c], std::min(limit, count[*c]));
    std::string b;
    if (template_json) {
        b.append("{\"items\":[");
        for (size_t k = 0; k < mine.size(); ++k) {
            if (k > 0) b.push_back(',');
            b.append(visit_json[mine[k]]);
            b.push_back('}');
        }
        b.append("],\"total\":");
        push_int(b, static_cast<int64_t>(count[*c]));
        b.push_back('}');
    } else {
        (void)glz::write<WRITE>(HistoryOut{mine | std::views::transform(visit_out), count[*c]}, b);
    }
    return json(std::move(b));
}

Reply show_client(std::string_view id) {
    auto n = parse_uint(id);
    auto c = n ? index_of(*n, clients.size()) : std::nullopt;
    if (!c) return not_found();
    if (template_json) return json(client_json[*c]);
    return json(written(clients[*c]));
}

// GET /schedule/version: the schedule's version, the minutes since
// version_epoch, and when it changed to it.
Reply schedule_version(const aegon::http::Request& req) {
    auto since = query(req, "since");
    auto n = since ? parse_int(*since) : std::nullopt;
    if (!n || *n < 0) return bad_request();
    int64_t version = (now_ms() - version_epoch) / MINUTE;
    return json(written(VersionOut{version, {version_epoch + version * MINUTE}}));
}

}  // namespace

Reply bad_request() {
    return Reply::json_with(400, "{\"error\":\"bad_request\",\"status\":400}");
}

Reply unauthorized() {
    return Reply::json_with(401, "{\"error\":\"unauthorized\",\"status\":401}");
}

Reply not_found() {
    return Reply::json_with(404, "{\"error\":\"not_found\",\"status\":404}");
}

aegon::http::MiddlewareFn bearer() {
    return [](Context& ctx, aegon::http::Next next) -> aegon::core::Task<void> {
        if (has_bearer(ctx.req().header("authorization"))) {
            co_await next(ctx);
        } else {
            answer(ctx, unauthorized());
        }
    };
}

void load(const std::string& dir, bool template_) {
    template_json = template_;
    version_epoch = file<Meta>(dir, "heavy-meta.json").versionEpoch;
    if (version_epoch <= 0) stop("heavy-meta.json has no versionEpoch");
    staffers = file<std::vector<Staffer>>(dir, "heavy-staff.json");
    services = file<std::vector<Service>>(dir, "heavy-services.json");
    clients = file<std::vector<Client>>(dir, "heavy-clients.json");
    for (size_t i = 0; i < staffers.size(); ++i) {
        if (staffers[i].id != i + 1) stop("heavy-staff.json's ids aren't 1, 2, ...");
    }
    for (size_t i = 0; i < clients.size(); ++i) {
        if (clients[i].id != i + 1) stop("heavy-clients.json's ids aren't 1, 2, ...");
    }
    auto lines = [](const std::vector<LineFile>& items) {
        std::vector<Line> out;
        for (const auto& l : items) {
            auto s = std::ranges::find(services, l.code, &Service::code);
            if (s == services.end()) stop("a service heavy-services.json lacks: " + l.code);
            out.push_back({l.id, static_cast<size_t>(s - services.begin())});
        }
        return out;
    };
    auto files = file<std::vector<VisitFile>>(dir, "heavy-encounters.json");
    visits.reserve(files.size());
    for (size_t i = 0; i < files.size(); ++i) {
        VisitFile& v = files[i];
        if (v.id != i + 1) stop("heavy-encounters.json's ids aren't 1, 2, ...");
        size_t first_note = notes.size();
        std::array<std::vector<NoteFile>*, 4> kinds = {&v.notes.intake, &v.notes.findings, &v.notes.plan,
                                                       &v.notes.internal};
        for (size_t kind = 0; kind < kinds.size(); ++kind) {
            for (auto& n : *kinds[kind]) {
                notes.push_back({n.id, i, kind, id_in(n.author.id, staffers.size(), "staff"), n.at.ms,
                                 std::move(n.text)});
            }
        }
        // A case's visits are together in the file.
        size_t case_first = i, case_count = 1;
        if (!visits.empty()) {
            const Visit& w = visits.back();
            if (w.case_id == v.caseId) {
                case_first = w.case_first;
                case_count = 0;
            } else if (w.case_id > v.caseId) {
                stop("a case's encounters apart");
            }
        }
        visits.push_back({v.caseId, id_in(v.client.id, clients.size(), "client"),
                          id_in(v.staff.id, staffers.size(), "staff"), std::move(v.status), std::move(v.kind),
                          std::move(v.priority), v.start.ms, v.end.ms, lines(v.items), std::move(v.codes), first_note,
                          notes.size() - first_note, case_first, case_count});
        if (case_count == 0) {
            for (size_t j = case_first; j <= i; ++j) visits[j].case_count = i + 1 - case_first;
        }
    }
    for (size_t i = 0; auto& b : file<std::vector<BookingFile>>(dir, "heavy-bookings.json")) {
        if (b.id != ++i) stop("heavy-bookings.json's ids aren't 1, 2, ...");
        if (!bookings.empty() && bookings.back().start > b.slot.start.ms) stop("bookings out of order");
        bookings.push_back({b.slot.start.ms, b.slot.end.ms, id_in(b.client.id, clients.size(), "client"),
                            id_in(b.staff.id, staffers.size(), "staff"),
                            id_in(b.encounter.id, visits.size(), "encounter"), lines(b.items),
                            std::move(b.reminders), std::move(b.status), std::move(b.source), std::move(b.note),
                            b.createdAt.ms, b.updatedAt.ms});
    }
    for (size_t i = 0; auto& s : file<std::vector<ShiftFile>>(dir, "heavy-shifts.json")) {
        if (s.id != ++i) stop("heavy-shifts.json's ids aren't 1, 2, ...");
        if (!shifts.empty() && shifts.back().start > s.start.ms) stop("shifts out of order");
        shifts.push_back({id_in(s.staff.id, staffers.size(), "staff"), s.start.ms, s.end.ms, std::move(s.kind),
                          std::move(s.room), std::move(s.note)});
    }
    for (size_t i = 0; i < visits.size(); ++i) {
        if (visits[i].status == "completed") past.push_back(i);
    }
    // Newest first, and of two at once the later id first.
    std::ranges::sort(past, [](size_t a, size_t b) {
        const Visit &va = visits[a], &vb = visits[b];
        if (va.client != vb.client) return va.client < vb.client;
        if (va.start != vb.start) return va.start > vb.start;
        return a > b;
    });
    first.assign(clients.size(), 0);
    count.assign(clients.size(), 0);
    for (size_t k = 0; k < past.size(); ++k) {
        size_t c = visits[past[k]].client;
        if (count[c] == 0) first[c] = k;
        ++count[c];
    }
    if (template_json) {
        for (size_t i = 0; i < bookings.size(); ++i) booking_json.push_back(written(booking_out(i)));
        for (size_t i = 0; i < shifts.size(); ++i) shift_json.push_back(written(shift_out(i)));
        for (const auto& c : clients) client_json.push_back(written(c));
        for (size_t i = 0; i < visits.size(); ++i) {
            visit_json.push_back(written(visit_out(i)));
            visit_json.back().pop_back();
        }
        for (const auto& n : notes) note_json.push_back(written(case_note_out(n)));
    }
}

size_t records() {
    return bookings.size() + visits.size();
}

void routes(aegon::http::Router& router) {
    auto v2 = router.group("/api/v2");
    v2.use(bearer());
    v2.get("/schedule/version", [](Context& ctx) { answer(ctx, schedule_version(ctx.req())); });
    v2.get("/schedule/bookings", [](Context& ctx) { answer(ctx, list_bookings(ctx.req())); });
    v2.get("/schedule/shifts", [](Context& ctx) { answer(ctx, list_shifts(ctx.req())); });
    v2.get("/encounters/:id", [](Context& ctx) { answer(ctx, show_encounter(*ctx.req().param("id"))); });
    v2.get("/clients/:id/encounters", [](Context& ctx) {
        answer(ctx, client_history(*ctx.req().param("id"), ctx.req()));
    });
    v2.get("/clients/:id", [](Context& ctx) { answer(ctx, show_client(*ctx.req().param("id"))); });
}

}  // namespace app::heavy
