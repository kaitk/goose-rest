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
// Ids are 1, 2, ... in each file, and the schedule's days are UTC's. A server
// answers an unknown path with not_found, then a request without a bearer
// token (crate::has_bearer) with unauthorized, before the route's function.

use serde::ser::SerializeStruct;
use serde::{Deserialize, Serialize, Serializer};

use crate::{
    data, de_iso, index_of, iso, join, json, now_ms, parse_day, parse_int, read_file, seq_of, Reply, DAY, MINUTE,
};

const NOTE_KINDS: [&str; 4] = ["intake", "findings", "plan", "internal"];

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Meta {
    version_epoch: i64,
}

#[derive(Deserialize)]
struct Staffer {
    id: usize,
    name: String,
    title: String,
}

#[derive(Deserialize)]
struct Service {
    code: String,
    name: String,
    minutes: i64,
    price: i64,
}

#[derive(Deserialize, Serialize)]
struct Address {
    street: String,
    city: String,
    postcode: String,
}

#[derive(Deserialize, Serialize)]
struct Preferences {
    channel: String,
    language: String,
}

#[derive(Deserialize, Serialize)]
struct Contact {
    name: String,
    phone: String,
    relation: String,
}

#[derive(Deserialize, Serialize)]
struct Consents {
    sms: bool,
    email: bool,
    research: bool,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Client {
    id: usize,
    name: String,
    code: String,
    born: String,
    phone: String,
    email: String,
    address: Address,
    preferences: Preferences,
    flags: Vec<String>,
    emergency_contact: Contact,
    consents: Consents,
    #[serde(deserialize_with = "de_iso", serialize_with = "iso")]
    created_at: i64,
    #[serde(deserialize_with = "de_iso", serialize_with = "iso")]
    updated_at: i64,
    // The client's completed visits, newest first: past[first..first + count].
    #[serde(skip)]
    first: usize,
    #[serde(skip)]
    count: usize,
}

// The id of an object such as {"id":3,"name":...}.
#[derive(Deserialize)]
struct Ref {
    id: usize,
}

#[derive(Deserialize)]
struct LineFile {
    id: i64,
    code: String,
}

struct Line {
    id: i64,
    service: usize,
}

#[derive(Deserialize)]
struct NoteFile {
    id: i64,
    author: Ref,
    text: String,
    #[serde(deserialize_with = "de_iso")]
    at: i64,
}

#[derive(Deserialize)]
struct NotesFile {
    intake: Vec<NoteFile>,
    findings: Vec<NoteFile>,
    plan: Vec<NoteFile>,
    internal: Vec<NoteFile>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VisitFile {
    id: usize,
    case_id: i64,
    client: Ref,
    staff: Ref,
    status: String,
    kind: String,
    priority: String,
    #[serde(deserialize_with = "de_iso")]
    start: i64,
    #[serde(deserialize_with = "de_iso")]
    end: i64,
    items: Vec<LineFile>,
    codes: Vec<String>,
    notes: NotesFile,
}

struct Note {
    id: i64,
    visit: usize,
    kind: usize,
    author: usize,
    at: i64,
    text: String,
}

struct Visit {
    case_id: i64,
    client: usize,
    staff: usize,
    status: String,
    kind: String,
    priority: String,
    start: i64,
    end: i64,
    lines: Vec<Line>,
    codes: Vec<String>,
    first_note: usize, // notes[first_note..first_note + notes], by kind
    notes: usize,
    case_first: usize, // the case's visits, visits[case_first..case_first + case_count]
    case_count: usize,
}

#[derive(Deserialize, Serialize)]
struct Reminder {
    channel: String,
    kind: String,
    status: String,
    #[serde(deserialize_with = "de_iso", serialize_with = "iso")]
    at: i64,
}

#[derive(Deserialize)]
struct Slot {
    #[serde(deserialize_with = "de_iso")]
    start: i64,
    #[serde(deserialize_with = "de_iso")]
    end: i64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct BookingFile {
    id: usize,
    slot: Slot,
    client: Ref,
    staff: Ref,
    encounter: Ref,
    items: Vec<LineFile>,
    reminders: Vec<Reminder>,
    status: String,
    source: String,
    note: Option<String>,
    #[serde(deserialize_with = "de_iso")]
    created_at: i64,
    #[serde(deserialize_with = "de_iso")]
    updated_at: i64,
}

struct Booking {
    start: i64,
    end: i64,
    client: usize,
    staff: usize,
    visit: usize,
    lines: Vec<Line>,
    reminders: Vec<Reminder>,
    status: String,
    source: String,
    note: Option<String>,
    created: i64,
    updated: i64,
}

#[derive(Deserialize, Serialize)]
struct Room {
    id: i64,
    name: String,
}

#[derive(Deserialize)]
struct ShiftFile {
    id: usize,
    staff: Ref,
    #[serde(deserialize_with = "de_iso")]
    start: i64,
    #[serde(deserialize_with = "de_iso")]
    end: i64,
    kind: String,
    room: Room,
    note: Option<String>,
}

struct Shift {
    staff: usize,
    start: i64,
    end: i64,
    kind: String,
    room: Room,
    note: Option<String>,
}

#[derive(Default)]
pub struct Heavy {
    staffers: Vec<Staffer>,
    services: Vec<Service>,
    clients: Vec<Client>,
    visits: Vec<Visit>,
    notes: Vec<Note>,
    bookings: Vec<Booking>, // by start
    shifts: Vec<Shift>,     // by start
    past: Vec<usize>,       // completed visits, by client, newest first
    version_epoch: i64,
    // JSON=template's: each booking, shift, and client whole; each visit
    // without its closing brace; and each note as caseNotes lists it.
    booking_json: Vec<Vec<u8>>,
    shift_json: Vec<Vec<u8>>,
    client_json: Vec<Vec<u8>>,
    visit_json: Vec<Vec<u8>>,
    note_json: Vec<Vec<u8>>,
}

#[derive(Serialize)]
struct StaffRef<'a> {
    id: usize,
    name: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    title: Option<&'a str>,
}

#[derive(Serialize)]
struct ClientRef<'a> {
    id: usize,
    name: &'a str,
    code: &'a str,
}

#[derive(Serialize)]
struct LineOut<'a> {
    id: i64,
    code: &'a str,
    name: &'a str,
    minutes: i64,
    price: i64,
}

#[derive(Serialize)]
struct SlotOut {
    #[serde(serialize_with = "iso")]
    start: i64,
    #[serde(serialize_with = "iso")]
    end: i64,
}

#[derive(Serialize)]
struct EncounterRef<'a> {
    id: usize,
    status: &'a str,
    #[serde(serialize_with = "iso")]
    start: i64,
    #[serde(serialize_with = "iso")]
    end: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BookingOut<'a, L> {
    id: usize,
    slot: SlotOut,
    client: ClientRef<'a>,
    staff: StaffRef<'a>,
    encounter: EncounterRef<'a>,
    items: L,
    reminders: &'a [Reminder],
    status: &'a str,
    source: &'a str,
    note: &'a Option<String>,
    #[serde(serialize_with = "iso")]
    created_at: i64,
    #[serde(serialize_with = "iso")]
    updated_at: i64,
}

#[derive(Serialize)]
struct ShiftOut<'a> {
    id: usize,
    staff: StaffRef<'a>,
    #[serde(serialize_with = "iso")]
    start: i64,
    #[serde(serialize_with = "iso")]
    end: i64,
    kind: &'a str,
    room: &'a Room,
    note: &'a Option<String>,
}

#[derive(Serialize)]
struct NoteOut<'a> {
    id: i64,
    author: StaffRef<'a>,
    text: &'a str,
    #[serde(serialize_with = "iso")]
    at: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CaseNoteOut<'a> {
    id: i64,
    encounter_id: usize,
    kind: &'static str,
    author: StaffRef<'a>,
    text: &'a str,
    #[serde(serialize_with = "iso")]
    at: i64,
}

// A visit's notes by kind, as an object of a list for each.
struct NotesOut<'a>(&'a Heavy, &'a [Note]);

impl Serialize for NotesOut<'_> {
    fn serialize<S: Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        let mut st = s.serialize_struct("notes", NOTE_KINDS.len())?;
        let mut rest = self.1;
        for (kind, name) in NOTE_KINDS.iter().enumerate() {
            let k = rest.partition_point(|n| n.kind == kind);
            st.serialize_field(name, &seq_of(&rest[..k], |n| NoteOut {
                id: n.id,
                author: self.0.staff_ref(n.author, true),
                text: &n.text,
                at: n.at,
            }))?;
            rest = &rest[k..];
        }
        st.end()
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct VisitOut<'a, L, N, C> {
    id: usize,
    case_id: i64,
    client: ClientRef<'a>,
    staff: StaffRef<'a>,
    status: &'a str,
    kind: &'a str,
    priority: &'a str,
    #[serde(serialize_with = "iso")]
    start: i64,
    #[serde(serialize_with = "iso")]
    end: i64,
    items: L,
    codes: &'a [String],
    notes: N,
    // GET /encounters/:id's: the notes of every visit of the case.
    #[serde(skip_serializing_if = "Option::is_none")]
    case_notes: Option<C>,
}

#[derive(Serialize)]
struct BookingsOut<T> {
    bookings: T,
    count: usize,
}

#[derive(Serialize)]
struct ShiftsOut<T> {
    shifts: T,
    count: usize,
}

#[derive(Serialize)]
struct HistoryOut<T> {
    items: T,
    total: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct VersionOut {
    version: i64,
    #[serde(serialize_with = "iso")]
    changed_at: i64,
}

// Tiers C's and D's errors, of the status in the body too.
pub fn bad_request() -> Reply {
    Reply::json(400, "{\"error\":\"bad_request\",\"status\":400}")
}

pub fn unauthorized() -> Reply {
    Reply::json(401, "{\"error\":\"unauthorized\",\"status\":401}")
}

pub fn not_found() -> Reply {
    Reply::json(404, "{\"error\":\"not_found\",\"status\":404}")
}

// GET /api/v2/schedule/version, with since's value.
pub fn version(since: Option<&str>) -> Reply {
    data().heavy.schedule_version(since, Vec::new())
}

// GET /api/v2/schedule/bookings, with start's, end's, and staff's values.
pub fn bookings(start: Option<&str>, end: Option<&str>, staff: Option<&str>) -> Reply {
    let d = data();
    d.heavy.list_bookings(d.template, (start, end, staff), Vec::new())
}

// GET /api/v2/schedule/shifts, as bookings.
pub fn shifts(start: Option<&str>, end: Option<&str>, staff: Option<&str>) -> Reply {
    let d = data();
    d.heavy.list_shifts(d.template, (start, end, staff), Vec::new())
}

// GET /api/v2/encounters/:id.
pub fn encounter(id: usize) -> Reply {
    let d = data();
    match index_of(id, d.heavy.visits.len()) {
        Some(i) => d.heavy.show_encounter(d.template, i, Vec::new()),
        None => not_found(),
    }
}

// The index of client id, or 404, which GET /clients/:id/encounters answers
// before it reads its query.
pub fn client_of(id: usize) -> Result<usize, Reply> {
    index_of(id, data().heavy.clients.len()).ok_or_else(not_found)
}

// GET /api/v2/clients/:id/encounters, of client_of's index, with limit's
// value.
pub fn client_encounters(c: usize, limit: Option<&str>) -> Reply {
    let d = data();
    d.heavy.client_history(d.template, limit, c, Vec::new())
}

// GET /api/v2/clients/:id.
pub fn client(id: usize) -> Reply {
    let d = data();
    let Some(c) = index_of(id, d.heavy.clients.len()) else { return not_found() };
    let mut buf = Vec::new();
    if d.template {
        buf.extend_from_slice(&d.heavy.client_json[c]);
    } else {
        serde_json::to_writer(&mut buf, &d.heavy.clients[c]).unwrap();
    }
    json(buf)
}

// A range's start, end, and staff values, as a query gives them.
type Range<'a> = (Option<&'a str>, Option<&'a str>, Option<&'a str>);

// An id of 1..=n in a file as an index.
fn id_in(id: usize, n: usize, what: &str) -> usize {
    assert!(id >= 1 && id <= n, "a {what} id that isn't one of 1..{n}: {id}");
    id - 1
}

impl Heavy {
    pub fn records(&self) -> usize {
        self.bookings.len() + self.visits.len()
    }

    pub fn load(dir: &str, template: bool) -> Heavy {
        fn file<T: for<'de> Deserialize<'de>>(dir: &str, name: &str) -> T {
            serde_json::from_slice(&read_file(dir, name)).unwrap_or_else(|e| panic!("{name}: {e}"))
        }
        let mut h = Heavy::default();
        h.version_epoch = file::<Meta>(dir, "heavy-meta.json").version_epoch;
        assert!(h.version_epoch > 0, "heavy-meta.json has no versionEpoch");
        h.staffers = file(dir, "heavy-staff.json");
        h.services = file(dir, "heavy-services.json");
        h.clients = file(dir, "heavy-clients.json");
        assert!(h.staffers.iter().enumerate().all(|(i, s)| s.id == i + 1), "heavy-staff.json's ids aren't 1, 2, ...");
        assert!(h.clients.iter().enumerate().all(|(i, c)| c.id == i + 1), "heavy-clients.json's ids aren't 1, 2, ...");
        let (staff, clients) = (h.staffers.len(), h.clients.len());
        let services = &h.services;
        let lines = |items: Vec<LineFile>| -> Vec<Line> {
            items.into_iter().map(|l| Line {
                id: l.id,
                service: services.iter().position(|s| s.code == l.code)
                    .unwrap_or_else(|| panic!("a service heavy-services.json lacks: {}", l.code)),
            }).collect()
        };
        let visits: Vec<VisitFile> = file(dir, "heavy-encounters.json");
        let mut notes = Vec::new();
        let mut list: Vec<Visit> = Vec::with_capacity(visits.len());
        for (i, v) in visits.into_iter().enumerate() {
            assert!(v.id == i + 1, "heavy-encounters.json's ids aren't 1, 2, ...");
            let first_note = notes.len();
            let NotesFile { intake, findings, plan, internal } = v.notes;
            for (kind, ns) in [intake, findings, plan, internal].into_iter().enumerate() {
                notes.extend(ns.into_iter().map(|n| Note {
                    id: n.id,
                    visit: i,
                    kind,
                    author: id_in(n.author.id, staff, "staff"),
                    at: n.at,
                    text: n.text,
                }));
            }
            // A case's visits are together in the file.
            let (case_first, case_count) = match list.last() {
                Some(w) if w.case_id == v.case_id => (w.case_first, 0),
                Some(w) => {
                    assert!(w.case_id < v.case_id, "a case's encounters apart");
                    (i, 1)
                }
                None => (i, 1),
            };
            list.push(Visit {
                case_id: v.case_id,
                client: id_in(v.client.id, clients, "client"),
                staff: id_in(v.staff.id, staff, "staff"),
                status: v.status,
                kind: v.kind,
                priority: v.priority,
                start: v.start,
                end: v.end,
                lines: lines(v.items),
                codes: v.codes,
                first_note,
                notes: notes.len() - first_note,
                case_first,
                case_count,
            });
            if case_count == 0 {
                let n = i + 1 - case_first;
                for w in &mut list[case_first..] {
                    w.case_count = n;
                }
            }
        }
        let bookings: Vec<BookingFile> = file(dir, "heavy-bookings.json");
        let mut booked = Vec::with_capacity(bookings.len());
        for (i, b) in bookings.into_iter().enumerate() {
            assert!(b.id == i + 1, "heavy-bookings.json's ids aren't 1, 2, ...");
            assert!(booked.last().map_or(true, |p: &Booking| p.start <= b.slot.start), "bookings out of order");
            booked.push(Booking {
                start: b.slot.start,
                end: b.slot.end,
                client: id_in(b.client.id, clients, "client"),
                staff: id_in(b.staff.id, staff, "staff"),
                visit: id_in(b.encounter.id, list.len(), "encounter"),
                lines: lines(b.items),
                reminders: b.reminders,
                status: b.status,
                source: b.source,
                note: b.note,
                created: b.created_at,
                updated: b.updated_at,
            });
        }
        let shifts: Vec<ShiftFile> = file(dir, "heavy-shifts.json");
        let mut shifted = Vec::with_capacity(shifts.len());
        for (i, s) in shifts.into_iter().enumerate() {
            assert!(s.id == i + 1, "heavy-shifts.json's ids aren't 1, 2, ...");
            assert!(shifted.last().map_or(true, |p: &Shift| p.start <= s.start), "shifts out of order");
            shifted.push(Shift {
                staff: id_in(s.staff.id, staff, "staff"),
                start: s.start,
                end: s.end,
                kind: s.kind,
                room: s.room,
                note: s.note,
            });
        }
        h.visits = list;
        h.notes = notes;
        h.bookings = booked;
        h.shifts = shifted;
        let mut past: Vec<usize> = (0..h.visits.len()).filter(|&i| h.visits[i].status == "completed").collect();
        // Newest first, and of two at once the later id first.
        past.sort_by(|&a, &b| {
            let (va, vb) = (&h.visits[a], &h.visits[b]);
            va.client.cmp(&vb.client).then(vb.start.cmp(&va.start)).then(b.cmp(&a))
        });
        for (k, &i) in past.iter().enumerate() {
            let c = &mut h.clients[h.visits[i].client];
            if c.count == 0 {
                c.first = k;
            }
            c.count += 1;
        }
        h.past = past;
        if template {
            h.booking_json = (0..h.bookings.len()).map(|i| serde_json::to_vec(&h.booking_out(i)).unwrap()).collect();
            h.shift_json = (0..h.shifts.len()).map(|i| serde_json::to_vec(&h.shift_out(i)).unwrap()).collect();
            h.client_json = h.clients.iter().map(|c| serde_json::to_vec(c).unwrap()).collect();
            h.visit_json = (0..h.visits.len()).map(|i| {
                let mut v = serde_json::to_vec(&h.visit_out(i, false)).unwrap();
                v.pop();
                v
            }).collect();
            h.note_json = h.notes.iter().map(|n| serde_json::to_vec(&h.case_note_out(n)).unwrap()).collect();
        }
        h
    }

    fn staff_ref(&self, s: usize, title: bool) -> StaffRef<'_> {
        let st = &self.staffers[s];
        StaffRef { id: s + 1, name: &st.name, title: title.then_some(st.title.as_str()) }
    }

    fn client_ref(&self, c: usize) -> ClientRef<'_> {
        let cl = &self.clients[c];
        ClientRef { id: c + 1, name: &cl.name, code: &cl.code }
    }

    fn lines_out<'a>(&'a self, lines: &'a [Line]) -> impl Serialize + 'a {
        seq_of(lines, move |l| {
            let s = &self.services[l.service];
            LineOut { id: l.id, code: &s.code, name: &s.name, minutes: s.minutes, price: s.price }
        })
    }

    fn booking_out(&self, i: usize) -> impl Serialize + '_ {
        let b = &self.bookings[i];
        let v = &self.visits[b.visit];
        BookingOut {
            id: i + 1,
            slot: SlotOut { start: b.start, end: b.end },
            client: self.client_ref(b.client),
            staff: self.staff_ref(b.staff, false),
            encounter: EncounterRef { id: b.visit + 1, status: &v.status, start: v.start, end: v.end },
            items: self.lines_out(&b.lines),
            reminders: &b.reminders,
            status: &b.status,
            source: &b.source,
            note: &b.note,
            created_at: b.created,
            updated_at: b.updated,
        }
    }

    fn shift_out(&self, i: usize) -> ShiftOut<'_> {
        let s = &self.shifts[i];
        ShiftOut {
            id: i + 1,
            staff: self.staff_ref(s.staff, false),
            start: s.start,
            end: s.end,
            kind: &s.kind,
            room: &s.room,
            note: &s.note,
        }
    }

    fn case_note_out<'a>(&'a self, n: &'a Note) -> CaseNoteOut<'a> {
        CaseNoteOut {
            id: n.id,
            encounter_id: n.visit + 1,
            kind: NOTE_KINDS[n.kind],
            author: self.staff_ref(n.author, true),
            text: &n.text,
            at: n.at,
        }
    }

    // The case's notes, oldest visit first.
    fn case_notes(&self, v: &Visit) -> &[Note] {
        let first = &self.visits[v.case_first];
        let last = &self.visits[v.case_first + v.case_count - 1];
        &self.notes[first.first_note..last.first_note + last.notes]
    }

    fn visit_out(&self, i: usize, case_notes: bool) -> impl Serialize + '_ {
        let v = &self.visits[i];
        VisitOut {
            id: i + 1,
            case_id: v.case_id,
            client: self.client_ref(v.client),
            staff: self.staff_ref(v.staff, true),
            status: &v.status,
            kind: &v.kind,
            priority: &v.priority,
            start: v.start,
            end: v.end,
            items: self.lines_out(&v.lines),
            codes: &v.codes,
            notes: NotesOut(self, &self.notes[v.first_note..v.first_note + v.notes]),
            case_notes: case_notes.then(|| seq_of(self.case_notes(v), |n| self.case_note_out(n))),
        }
    }

    // A start and an end day, end after start and at most 31 days on, and the
    // staff of a list of their ids as bits.
    fn range_of(&self, (start, end, staff): Range) -> Option<(i64, i64, u64)> {
        let start = parse_day(start?.as_bytes())?;
        let end = parse_day(end?.as_bytes())?;
        let list = staff?.as_bytes();
        if !(end > start && end - start <= 31 * DAY) || list.is_empty() {
            return None;
        }
        list.split(|&c| c == b',').try_fold(0u64, |mask, id| {
            let n = parse_int(id).filter(|&n| n >= 1 && n as usize <= self.staffers.len())?;
            Some(mask | 1 << (n - 1))
        }).map(|mask| (start, end, mask))
    }

    // The indices of records by start in [start, end) of the mask's staff.
    fn select<T>(records: &[T], (start, end, mask): (i64, i64, u64), at: impl Fn(&T) -> (i64, usize)) -> Vec<usize> {
        let first = records.partition_point(|r| at(r).0 < start);
        (first..records.len()).take_while(|&i| at(&records[i]).0 < end).filter(|&i| mask >> at(&records[i]).1 & 1 != 0)
            .collect()
    }

    fn list_bookings(&self, template: bool, query: Range, mut buf: Vec<u8>) -> Reply {
        let Some(range) = self.range_of(query) else { return bad_request() };
        let listed = Self::select(&self.bookings, range, |b| (b.start, b.staff));
        if template {
            join(&mut buf, b"{\"bookings\":[", listed.iter().map(|&i| &self.booking_json[i][..]), b"],\"count\":");
            buf.extend_from_slice(listed.len().to_string().as_bytes());
            buf.push(b'}');
        } else {
            let out = BookingsOut { bookings: seq_of(&listed, |&i| self.booking_out(i)), count: listed.len() };
            serde_json::to_writer(&mut buf, &out).unwrap();
        }
        json(buf)
    }

    fn list_shifts(&self, template: bool, query: Range, mut buf: Vec<u8>) -> Reply {
        let Some(range) = self.range_of(query) else { return bad_request() };
        let listed = Self::select(&self.shifts, range, |s| (s.start, s.staff));
        if template {
            join(&mut buf, b"{\"shifts\":[", listed.iter().map(|&i| &self.shift_json[i][..]), b"],\"count\":");
            buf.extend_from_slice(listed.len().to_string().as_bytes());
            buf.push(b'}');
        } else {
            let out = ShiftsOut { shifts: seq_of(&listed, |&i| self.shift_out(i)), count: listed.len() };
            serde_json::to_writer(&mut buf, &out).unwrap();
        }
        json(buf)
    }

    // The encounter, and the notes of every visit of its case, oldest first.
    fn show_encounter(&self, template: bool, i: usize, mut buf: Vec<u8>) -> Reply {
        if template {
            let v = &self.visits[i];
            let first = self.visits[v.case_first].first_note;
            let notes = first..first + self.case_notes(v).len();
            buf.extend_from_slice(&self.visit_json[i]);
            join(&mut buf, b",\"caseNotes\":[", notes.map(|j| &self.note_json[j][..]), b"]}");
        } else {
            serde_json::to_writer(&mut buf, &self.visit_out(i, true)).unwrap();
        }
        json(buf)
    }

    // The client's completed visits, newest first, up to limit, and how many
    // there are.
    fn client_history(&self, template: bool, limit_of: Option<&str>, c: usize, mut buf: Vec<u8>) -> Reply {
        let mut limit = 20;
        if let Some(v) = limit_of {
            let Some(n) = parse_int(v.as_bytes()).filter(|n| (1..=50).contains(n)) else {
                return bad_request();
            };
            limit = n as usize;
        }
        let cl = &self.clients[c];
        let mine = &self.past[cl.first..cl.first + limit.min(cl.count)];
        if template {
            buf.extend_from_slice(b"{\"items\":[");
            for (k, &i) in mine.iter().enumerate() {
                if k > 0 {
                    buf.push(b',');
                }
                buf.extend_from_slice(&self.visit_json[i]);
                buf.push(b'}');
            }
            buf.extend_from_slice(b"],\"total\":");
            buf.extend_from_slice(cl.count.to_string().as_bytes());
            buf.push(b'}');
        } else {
            let out = HistoryOut { items: seq_of(mine, |&i| self.visit_out(i, false)), total: cl.count };
            serde_json::to_writer(&mut buf, &out).unwrap();
        }
        json(buf)
    }

    // GET /schedule/version: the schedule's version, the minutes since
    // version_epoch, and when it changed to it.
    fn schedule_version(&self, since: Option<&str>, mut buf: Vec<u8>) -> Reply {
        if !since.and_then(|s| parse_int(s.as_bytes())).is_some_and(|n| n >= 0) {
            return bad_request();
        }
        let version = (now_ms() - self.version_epoch) / MINUTE;
        let out = VersionOut { version, changed_at: self.version_epoch + version * MINUTE };
        serde_json::to_writer(&mut buf, &out).unwrap();
        json(buf)
    }
}
