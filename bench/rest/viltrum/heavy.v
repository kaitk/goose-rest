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
// group's middleware checks the bearer token on the routes it has; main.v's
// fallback answers a path or method none takes with the 404 before any token
// is looked at.
module main

import strings
import viltrum
import x.json2

const note_kinds = ['intake', 'findings', 'plan', 'internal']

// A time as ms since the epoch, which JSON gives and takes as toISOString's
// string.
struct Iso {
mut:
	ms i64
}

pub fn (mut t Iso) from_json_string(raw string) ! {
	t.ms = parse_iso(raw) or { return error('not an ISO time: ${raw}') }
}

pub fn (t Iso) to_json() string {
	return '"${iso(t.ms)}"'
}

struct Meta {
	version_epoch i64 @[json: 'versionEpoch']
}

struct Staffer {
	id    u64
	name  string
	title string
}

struct Service {
	code    string
	name    string
	minutes i64
	price   i64
}

struct Address {
	street   string
	city     string
	postcode string
}

struct Preferences {
	channel  string
	language string
}

struct Contact {
	name     string
	phone    string
	relation string
}

struct Consents {
	sms      bool
	email    bool
	research bool
}

struct Client {
	id                u64
	name              string
	code              string
	born              string
	phone             string
	email             string
	address           Address
	preferences       Preferences
	flags             []string
	emergency_contact Contact @[json: 'emergencyContact']
	consents          Consents
	created_at        Iso @[json: 'createdAt']
	updated_at        Iso @[json: 'updatedAt']
}

// The id of an object such as {"id":3,"name":...}.
struct Ref {
	id u64
}

struct LineFile {
	id   i64
	code string
}

struct Line {
	id      i64
	service int
}

struct NoteFile {
	id     i64
	author Ref
	text   string
	at     Iso
}

struct NotesFile {
	intake   []NoteFile
	findings []NoteFile
	plan     []NoteFile
	internal []NoteFile
}

struct VisitFile {
	id       u64
	case_id  i64 @[json: 'caseId']
	client   Ref
	staff    Ref
	status   string
	kind     string
	priority string
	start    Iso
	end      Iso
	items    []LineFile
	codes    []string
	notes    NotesFile
}

struct Note {
	id     i64
	visit  int
	kind   int
	author int
	at     i64
	text   string
}

struct Visit {
	case_id  i64
	client   int
	staff    int
	status   string
	kind     string
	priority string
	start    i64
	end      i64
	lines    []Line
	codes    []string
	// notes[first_note, first_note + notes), by kind
	first_note int
	notes      int
mut:
	// the case's visits, visits[case_first, case_first + case_count)
	case_first int
	case_count int
}

struct Reminder {
	channel string
	kind    string
	status  string
	at      Iso
}

struct Slot {
	start Iso
	end   Iso
}

struct BookingFile {
	id         u64
	slot       Slot
	client     Ref
	staff      Ref
	encounter  Ref
	items      []LineFile
	reminders  []Reminder
	status     string
	source     string
	note       ?string
	created_at Iso @[json: 'createdAt']
	updated_at Iso @[json: 'updatedAt']
}

struct Booking {
	start     i64
	end       i64
	client    int
	staff     int
	visit     int
	lines     []Line
	reminders []Reminder
	status    string
	source    string
	note      ?string
	created   i64
	updated   i64
}

struct Room {
	id   i64
	name string
}

struct ShiftFile {
	id    u64
	staff Ref
	start Iso
	end   Iso
	kind  string
	room  Room
	note  ?string
}

struct Shift {
	staff int
	start i64
	end   i64
	kind  string
	room  Room
	note  ?string
}

// What the answers write.
struct StaffRef {
	id   int
	name string
}

struct StaffTitled {
	id    int
	name  string
	title string
}

struct ClientRef {
	id   int
	name string
	code string
}

struct LineOut {
	id      i64
	code    string
	name    string
	minutes i64
	price   i64
}

struct EncounterRef {
	id     int
	status string
	start  Iso
	end    Iso
}

// A booking's or a shift's note is null when it has none.
struct BookingOut {
	id         int
	slot       Slot
	client     ClientRef
	staff      StaffRef
	encounter  EncounterRef
	items      []LineOut
	reminders  []Reminder
	status     string
	source     string
	note       ?string @[json_null]
	created_at Iso     @[json: 'createdAt']
	updated_at Iso     @[json: 'updatedAt']
}

struct ShiftOut {
	id    int
	staff StaffRef
	start Iso
	end   Iso
	kind  string
	room  Room
	note  ?string @[json_null]
}

struct NoteOut {
	id     i64
	author StaffTitled
	text   string
	at     Iso
}

struct CaseNoteOut {
	id           i64
	encounter_id int @[json: 'encounterId']
	kind         string
	author       StaffTitled
	text         string
	at           Iso
}

struct NotesOut {
	intake   []NoteOut
	findings []NoteOut
	plan     []NoteOut
	internal []NoteOut
}

struct VisitOut {
	id       int
	case_id  i64 @[json: 'caseId']
	client   ClientRef
	staff    StaffTitled
	status   string
	kind     string
	priority string
	start    Iso
	end      Iso
	items    []LineOut
	codes    []string
	notes    NotesOut
}

// GET /encounters/:id's: the visit, and the notes of every visit of its case.
struct EncounterOut {
	id         int
	case_id    i64 @[json: 'caseId']
	client     ClientRef
	staff      StaffTitled
	status     string
	kind       string
	priority   string
	start      Iso
	end        Iso
	items      []LineOut
	codes      []string
	notes      NotesOut
	case_notes []CaseNoteOut @[json: 'caseNotes']
}

struct BookingsOut {
	bookings []BookingOut
	count    int
}

struct ShiftsOut {
	shifts []ShiftOut
	count  int
}

struct HistoryOut {
	items []VisitOut
	total int
}

struct VersionOut {
	version    i64
	changed_at Iso @[json: 'changedAt']
}

@[heap]
struct Heavy {
mut:
	staffers []Staffer
	services []Service
	clients  []Client
	visits   []Visit
	notes    []Note
	bookings []Booking // by start
	shifts   []Shift   // by start
	// Each client's completed visits, newest first: past[first[c], first[c] + count[c]).
	past          []int
	first         []int
	count         []int
	version_epoch i64
	template      bool
	// JSON=template's: each booking, shift, and client whole; each visit
	// without its closing brace; and each note as caseNotes lists it.
	booking_json []string
	shift_json   []string
	client_json  []string
	visit_json   []string
	note_json    []string
}

fn bad_request() Reply {
	return json_str(400, '{"error":"bad_request","status":400}')
}

fn unauthorized() Reply {
	return json_str(401, '{"error":"unauthorized","status":401}')
}

fn heavy_not_found() Reply {
	return json_str(404, '{"error":"not_found","status":404}')
}

// The bearer check, as middleware on tiers C's and D's groups: 401 without a
// bearer token of three base64url segments.
fn heavy_bearer(mut c viltrum.Ctx) {
	if has_bearer(c.header('authorization')) {
		c.next()
	} else {
		answer(mut c, unauthorized())
	}
}

// An id of 1..=n in a file as an index.
fn id_in(id u64, n int, what string) int {
	return index_of(id, n) or { stop('a ${what} id that isn\'t one of 1..${n}') }
}

fn (h &Heavy) lines(items []LineFile) []Line {
	mut out := []Line{cap: items.len}
	for l in items {
		mut s := -1
		for k, x in h.services {
			if x.code == l.code {
				s = k
				break
			}
		}
		if s < 0 {
			stop('a service heavy-services.json lacks: ${l.code}')
		}
		out << Line{
			id:      l.id
			service: s
		}
	}
	return out
}

struct PastKey {
	client int
	start  i64
	visit  int
}

fn load_heavy(cfg Config) &Heavy {
	mut h := &Heavy{
		template: cfg.template
	}
	meta := json2.decode[Meta](read_file(cfg.dir, 'heavy-meta.json')) or {
		stop('heavy-meta.json: ${err}')
	}
	h.version_epoch = meta.version_epoch
	if h.version_epoch <= 0 {
		stop('heavy-meta.json has no versionEpoch')
	}
	h.staffers = parse_file[Staffer](cfg.dir, 'heavy-staff.json')
	h.services = parse_file[Service](cfg.dir, 'heavy-services.json')
	h.clients = parse_file[Client](cfg.dir, 'heavy-clients.json')
	for i, s in h.staffers {
		if s.id != u64(i + 1) {
			stop("heavy-staff.json's ids aren't 1, 2, ...")
		}
	}
	for i, c in h.clients {
		if c.id != u64(i + 1) {
			stop("heavy-clients.json's ids aren't 1, 2, ...")
		}
	}
	for i, v in parse_file[VisitFile](cfg.dir, 'heavy-encounters.json') {
		if v.id != u64(i + 1) {
			stop("heavy-encounters.json's ids aren't 1, 2, ...")
		}
		first_note := h.notes.len
		for kind, list in [v.notes.intake, v.notes.findings, v.notes.plan, v.notes.internal] {
			for n in list {
				h.notes << Note{
					id:     n.id
					visit:  i
					kind:   kind
					author: id_in(n.author.id, h.staffers.len, 'staff')
					at:     n.at.ms
					text:   n.text
				}
			}
		}
		// A case's visits are together in the file.
		mut case_first, mut case_count := i, 1
		if h.visits.len > 0 {
			w := h.visits.last()
			if w.case_id == v.case_id {
				case_first = w.case_first
				case_count = 0
			} else if w.case_id > v.case_id {
				stop("a case's encounters apart")
			}
		}
		h.visits << Visit{
			case_id:    v.case_id
			client:     id_in(v.client.id, h.clients.len, 'client')
			staff:      id_in(v.staff.id, h.staffers.len, 'staff')
			status:     v.status
			kind:       v.kind
			priority:   v.priority
			start:      v.start.ms
			end:        v.end.ms
			lines:      h.lines(v.items)
			codes:      v.codes
			first_note: first_note
			notes:      h.notes.len - first_note
			case_first: case_first
			case_count: case_count
		}
		if case_count == 0 {
			for j in case_first .. i + 1 {
				h.visits[j].case_count = i + 1 - case_first
			}
		}
	}
	for i, b in parse_file[BookingFile](cfg.dir, 'heavy-bookings.json') {
		if b.id != u64(i + 1) {
			stop("heavy-bookings.json's ids aren't 1, 2, ...")
		}
		if h.bookings.len > 0 && h.bookings.last().start > b.slot.start.ms {
			stop('bookings out of order')
		}
		h.bookings << Booking{
			start:     b.slot.start.ms
			end:       b.slot.end.ms
			client:    id_in(b.client.id, h.clients.len, 'client')
			staff:     id_in(b.staff.id, h.staffers.len, 'staff')
			visit:     id_in(b.encounter.id, h.visits.len, 'encounter')
			lines:     h.lines(b.items)
			reminders: b.reminders
			status:    b.status
			source:    b.source
			note:      b.note
			created:   b.created_at.ms
			updated:   b.updated_at.ms
		}
	}
	for i, s in parse_file[ShiftFile](cfg.dir, 'heavy-shifts.json') {
		if s.id != u64(i + 1) {
			stop("heavy-shifts.json's ids aren't 1, 2, ...")
		}
		if h.shifts.len > 0 && h.shifts.last().start > s.start.ms {
			stop('shifts out of order')
		}
		h.shifts << Shift{
			staff: id_in(s.staff.id, h.staffers.len, 'staff')
			start: s.start.ms
			end:   s.end.ms
			kind:  s.kind
			room:  s.room
			note:  s.note
		}
	}
	mut keys := []PastKey{}
	for i, v in h.visits {
		if v.status == 'completed' {
			keys << PastKey{v.client, v.start, i}
		}
	}
	// Newest first, and of two at once the later id first.
	keys.sort_with_compare(fn (a &PastKey, b &PastKey) int {
		if a.client != b.client {
			return if a.client < b.client { -1 } else { 1 }
		}
		if a.start != b.start {
			return if a.start > b.start { -1 } else { 1 }
		}
		return if a.visit > b.visit { -1 } else { 1 }
	})
	h.past = keys.map(it.visit)
	h.first = []int{len: h.clients.len}
	h.count = []int{len: h.clients.len}
	for k, key in keys {
		if h.count[key.client] == 0 {
			h.first[key.client] = k
		}
		h.count[key.client]++
	}
	if h.template {
		h.booking_json = []string{len: h.bookings.len, init: written(h.booking_out(index)).bytestr()}
		h.shift_json = []string{len: h.shifts.len, init: written(h.shift_out(index)).bytestr()}
		h.client_json = h.clients.map(written(it).bytestr())
		h.visit_json = []string{len: h.visits.len, init: without_brace(h.visit_out(index))}
		h.note_json = h.notes.map(written(h.case_note_out(it)).bytestr())
	}
	return h
}

fn (h &Heavy) records() int {
	return h.bookings.len + h.visits.len
}

fn (h &Heavy) staff_ref(s int) StaffRef {
	return StaffRef{s + 1, h.staffers[s].name}
}

fn (h &Heavy) staff_titled(s int) StaffTitled {
	return StaffTitled{s + 1, h.staffers[s].name, h.staffers[s].title}
}

fn (h &Heavy) client_ref(c int) ClientRef {
	return ClientRef{c + 1, h.clients[c].name, h.clients[c].code}
}

fn (h &Heavy) lines_out(lines []Line) []LineOut {
	mut out := []LineOut{cap: lines.len}
	for l in lines {
		s := h.services[l.service]
		out << LineOut{l.id, s.code, s.name, s.minutes, s.price}
	}
	return out
}

fn (h &Heavy) booking_out(i int) BookingOut {
	b := h.bookings[i]
	v := h.visits[b.visit]
	return BookingOut{
		id:         i + 1
		slot:       Slot{Iso{b.start}, Iso{b.end}}
		client:     h.client_ref(b.client)
		staff:      h.staff_ref(b.staff)
		encounter:  EncounterRef{b.visit + 1, v.status, Iso{v.start}, Iso{v.end}}
		items:      h.lines_out(b.lines)
		reminders:  b.reminders
		status:     b.status
		source:     b.source
		note:       b.note
		created_at: Iso{b.created}
		updated_at: Iso{b.updated}
	}
}

fn (h &Heavy) shift_out(i int) ShiftOut {
	s := h.shifts[i]
	return ShiftOut{
		id:    i + 1
		staff: h.staff_ref(s.staff)
		start: Iso{s.start}
		end:   Iso{s.end}
		kind:  s.kind
		room:  s.room
		note:  s.note
	}
}

fn (h &Heavy) case_note_out(n Note) CaseNoteOut {
	return CaseNoteOut{n.id, n.visit + 1, note_kinds[n.kind], h.staff_titled(n.author), n.text, Iso{n.at}}
}

// A visit's notes by kind. The notes of a visit are in the order of
// note_kinds, so each kind's are together.
fn (h &Heavy) notes_out(v Visit) NotesOut {
	mut by_kind := [][]NoteOut{len: note_kinds.len}
	for n in h.notes[v.first_note..v.first_note + v.notes] {
		by_kind[n.kind] << NoteOut{n.id, h.staff_titled(n.author), n.text, Iso{n.at}}
	}
	return NotesOut{by_kind[0], by_kind[1], by_kind[2], by_kind[3]}
}

// The case's notes, oldest visit first, as notes[first, end).
fn (h &Heavy) case_notes(v Visit) (int, int) {
	f := h.visits[v.case_first]
	l := h.visits[v.case_first + v.case_count - 1]
	return f.first_note, l.first_note + l.notes
}

fn (h &Heavy) visit_out(i int) VisitOut {
	v := h.visits[i]
	return VisitOut{
		id:       i + 1
		case_id:  v.case_id
		client:   h.client_ref(v.client)
		staff:    h.staff_titled(v.staff)
		status:   v.status
		kind:     v.kind
		priority: v.priority
		start:    Iso{v.start}
		end:      Iso{v.end}
		items:    h.lines_out(v.lines)
		codes:    v.codes
		notes:    h.notes_out(v)
	}
}

fn (h &Heavy) encounter_out(i int) EncounterOut {
	v := h.visits[i]
	first, end := h.case_notes(v)
	return EncounterOut{
		id:         i + 1
		case_id:    v.case_id
		client:     h.client_ref(v.client)
		staff:      h.staff_titled(v.staff)
		status:     v.status
		kind:       v.kind
		priority:   v.priority
		start:      Iso{v.start}
		end:        Iso{v.end}
		items:      h.lines_out(v.lines)
		codes:      v.codes
		notes:      h.notes_out(v)
		case_notes: h.notes[first..end].map(h.case_note_out(it))
	}
}

// Prebuilt records joined with ',' between open and close.
fn join(mut out strings.Builder, open string, listed []int, json []string, close string) {
	out.write_string(open)
	for k, i in listed {
		if k > 0 {
			out.write_u8(`,`)
		}
		out.write_string(json[i])
	}
	out.write_string(close)
}

// A start and an end day, end after start and at most 31 days on, and the
// staff of a list of their ids as bits.
struct Range {
	start i64
	end   i64
	mask  u64
}

fn (h &Heavy) range_of(mut c viltrum.Ctx) ?Range {
	s := c.query_param('start')?
	e := c.query_param('end')?
	list := c.query_param('staff')?
	start := parse_day(s)?
	end := parse_day(e)?
	if !(end > start && end - start <= 31 * day) || list.len == 0 {
		return none
	}
	mut mask := u64(0)
	for id in list.split(',') {
		n := parse_int(id)?
		if n < 1 || n > h.staffers.len {
			return none
		}
		mask |= u64(1) << (n - 1)
	}
	return Range{start, end, mask}
}

// The indices of records by start in [start, end) of the mask's staff.
fn select[T](records []T, r Range) []int {
	mut lo, mut hi := 0, records.len
	for lo < hi {
		mid := (lo + hi) / 2
		if records[mid].start < r.start {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	mut out := []int{}
	for i := lo; i < records.len && records[i].start < r.end; i++ {
		if (r.mask >> records[i].staff) & 1 != 0 {
			out << i
		}
	}
	return out
}

fn (h &Heavy) list_bookings(mut c viltrum.Ctx) Reply {
	r := h.range_of(mut c) or { return bad_request() }
	listed := select(h.bookings, r)
	if h.template {
		mut b := strings.new_builder(listed.len * 1024 + 32)
		join(mut b, '{"bookings":[', listed, h.booking_json, '],"count":')
		push_int(mut b, listed.len)
		b.write_u8(`}`)
		return json_ok(b)
	}
	return json_ok(written(BookingsOut{listed.map(h.booking_out(it)), listed.len}))
}

fn (h &Heavy) list_shifts(mut c viltrum.Ctx) Reply {
	r := h.range_of(mut c) or { return bad_request() }
	listed := select(h.shifts, r)
	if h.template {
		mut b := strings.new_builder(listed.len * 256 + 32)
		join(mut b, '{"shifts":[', listed, h.shift_json, '],"count":')
		push_int(mut b, listed.len)
		b.write_u8(`}`)
		return json_ok(b)
	}
	return json_ok(written(ShiftsOut{listed.map(h.shift_out(it)), listed.len}))
}

// The encounter, and the notes of every visit of its case, oldest first.
fn (h &Heavy) show_encounter(id string) Reply {
	n := parse_uint(id) or { return heavy_not_found() }
	i := index_of(n, h.visits.len) or { return heavy_not_found() }
	if h.template {
		first, end := h.case_notes(h.visits[i])
		mut b := strings.new_builder(h.visit_json[i].len + (end - first) * 512 + 16)
		b.write_string(h.visit_json[i])
		b.write_string(',"caseNotes":[')
		for j in first .. end {
			if j > first {
				b.write_u8(`,`)
			}
			b.write_string(h.note_json[j])
		}
		b.write_string(']}')
		return json_ok(b)
	}
	return json_ok(written(h.encounter_out(i)))
}

// The client's completed visits, newest first, up to limit, and how many
// there are. The client is looked up before the query is read.
fn (h &Heavy) client_history(mut c viltrum.Ctx, id string) Reply {
	n := parse_uint(id) or { return heavy_not_found() }
	k := index_of(n, h.clients.len) or { return heavy_not_found() }
	mut limit := 20
	if v := c.query_param('limit') {
		l := parse_int(v) or { return bad_request() }
		if l < 1 || l > 50 {
			return bad_request()
		}
		limit = int(l)
	}
	first := h.first[k]
	mine := h.past[first..first + if limit < h.count[k] { limit } else { h.count[k] }]
	if h.template {
		mut b := strings.new_builder(mine.len * 4096 + 32)
		b.write_string('{"items":[')
		for j, i in mine {
			if j > 0 {
				b.write_u8(`,`)
			}
			b.write_string(h.visit_json[i])
			b.write_u8(`}`)
		}
		b.write_string('],"total":')
		push_int(mut b, h.count[k])
		b.write_u8(`}`)
		return json_ok(b)
	}
	return json_ok(written(HistoryOut{mine.map(h.visit_out(it)), h.count[k]}))
}

fn (h &Heavy) show_client(id string) Reply {
	n := parse_uint(id) or { return heavy_not_found() }
	k := index_of(n, h.clients.len) or { return heavy_not_found() }
	if h.template {
		return json_ok(h.client_json[k].bytes())
	}
	return json_ok(written(h.clients[k]))
}

// GET /schedule/version: the schedule's version, the minutes since
// version_epoch, and when it changed to it.
fn (h &Heavy) schedule_version(mut c viltrum.Ctx) Reply {
	since := c.query_param('since') or { return bad_request() }
	n := parse_int(since) or { return bad_request() }
	if n < 0 {
		return bad_request()
	}
	version := (now_ms() - h.version_epoch) / minute
	return json_ok(written(VersionOut{version, Iso{h.version_epoch + version * minute}}))
}

fn heavy_routes(mut app viltrum.App, h &Heavy) {
	mut v2 := app.group('/api/v2', heavy_bearer)
	v2.get('/schedule/version', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.schedule_version(mut c))
	})
	v2.get('/schedule/bookings', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.list_bookings(mut c))
	})
	v2.get('/schedule/shifts', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.list_shifts(mut c))
	})
	v2.get('/encounters/:id', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.show_encounter(c.param('id') or { '' }))
	})
	v2.get('/clients/:id/encounters', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.client_history(mut c, c.param('id') or { '' }))
	})
	v2.get('/clients/:id', fn [h] (mut c viltrum.Ctx) {
		answer(mut c, h.show_client(c.param('id') or { '' }))
	})
}
