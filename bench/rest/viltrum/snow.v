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
// The checks run in snowtime's order: an unknown call (main.v's fallback),
// a write from another origin (the group's middleware), GET /session, which
// answers null to no one, the sign-in, and the organization's membership.
// Only then are the query and body read.
module main

import strings
import viltrum
import x.json2

const app_url = 'https://time.bench.example.com'
const session_cookie = '__Secure-better-auth.session_token'

struct ProjectFile {
	id          string
	name        string
	color       ?string
	archived_at ?string  @[json: 'archivedAt']
	has_entries bool     @[json: 'hasEntries']
	team_ids    []string @[json: 'teamIds']
}

struct OrgFile {
	id          string
	name        string
	slug        string
	issue_links ?string @[json: 'issueLinks']
	projects    []ProjectFile
}

// A user's settings and fill, read from the file and written back as they
// are.
struct Settings {
	time_zone             string @[json: 'timeZone']
	week_start            string @[json: 'weekStart']
	locale                string
	theme                 string
	timer_layout          string  @[json: 'timerLayout']
	show_summary          bool    @[json: 'showSummary']
	compact_rows          bool    @[json: 'compactRows']
	wide_timer            bool    @[json: 'wideTimer']
	timer_view            string  @[json: 'timerView']
	calendar_weekend      bool    @[json: 'calendarWeekend']
	app_icon              string  @[json: 'appIcon']
	scene_collection      string  @[json: 'sceneCollection']
	scene_pin             ?string @[json: 'scenePin'; json_null]
	scene_background      bool    @[json: 'sceneBackground']
	scene_strength        string  @[json: 'sceneStrength']
	surfaces              string
	scene_weather         bool    @[json: 'sceneWeather']
	scene_intro           bool    @[json: 'sceneIntro']
	scene_tagline         bool    @[json: 'sceneTagline']
	duration_format       string  @[json: 'durationFormat']
	date_format           string  @[json: 'dateFormat']
	time_format           string  @[json: 'timeFormat']
	copy_duration_pattern string  @[json: 'copyDurationPattern']
	copy_duration_control string  @[json: 'copyDurationControl']
	country               ?string @[json_null]
}

struct LastDay {
	date   string
	filled bool
}

struct Fill {
	date             string
	timer_started_at ?i64 @[json: 'timerStartedAt'; json_null]
	today            string
	last_working_day ?LastDay @[json: 'lastWorkingDay'; json_null]
	last_week        ?bool    @[json: 'lastWeek'; json_null]
	last_month       ?bool    @[json: 'lastMonth'; json_null]
	caught_up        bool     @[json: 'caughtUp']
	empty_days       i64      @[json: 'emptyDays']
	streak           i64
}

struct MemberFile {
	id   string
	role string
}

struct PersonFile {
	id                     string
	name                   string
	email                  string
	image                  ?string
	token                  string
	signed_in_at           ?string @[json: 'signedInAt']
	organizations          []MemberFile
	active_organization_id string   @[json: 'activeOrganizationId']
	team_ids               []string @[json: 'teamIds']
	settings               Settings
	fill                   Fill
}

struct EntryFile {
	id              string
	organization_id string  @[json: 'organizationId']
	user_id         string  @[json: 'userId']
	project_id      ?string @[json: 'projectId']
	description     string
	ticket          ?string
	started_at      string  @[json: 'startedAt']
	stopped_at      ?string @[json: 'stoppedAt']
}

struct Project {
	id          string
	name        string
	color       ?string
	archived    ?i64
	has_entries bool
	teams       []string
}

struct Org {
	id    string
	name  string
	slug  string
	links ?string
	// its projects, projects[first..first + count]
	first int
	count int
}

struct Member {
	org  int
	role string
}

struct Person {
	id        string
	name      string
	email     string
	image     ?string
	token     string
	signed_in ?i64
	orgs      []Member // as the session lists them
	active    int
	teams     []string // in the active organization
	settings  Settings
	fill      Fill
mut:
	// the person's entries, entries[first..first + count]
	first   int
	count   int
	running ?int
}

struct Entry {
	id          string
	user        int
	org         int
	project     ?int
	description string
	ticket      ?string
	started     i64
	stopped     ?i64
}

// An entry's prebuilt JSON, and where its description's value starts and
// ends, for a PATCH to put another there.
struct EntryJson {
	json string
	desc int
	tail int
}

// A key and its record's index, for a lookup by binary search.
struct Keyed {
	key string
	i   int
}

// The answers' shapes.
struct UserOut {
	id    string
	name  string
	email string
	image ?string @[json_null]
}

struct OrgOut {
	id          string
	name        string
	slug        string
	issue_links ?string @[json: 'issueLinks'; json_null]
	role        string
}

struct SessionOut {
	user                   UserOut
	signed_in_at           ?string @[json: 'signedInAt'; json_null]
	organizations          []OrgOut
	active_organization_id string @[json: 'activeOrganizationId']
	settings               &Settings
	fill                   &Fill
	invitation_id          ?int   @[json: 'invitationId'; json_null]
	app_url                string @[json: 'appUrl']
}

struct ProjectOut {
	id          string
	name        string
	color       ?string  @[json_null]
	archived_at ?string  @[json: 'archivedAt'; json_null]
	has_entries bool     @[json: 'hasEntries']
	team_ids    []string @[json: 'teamIds']
}

struct ProjectRef {
	id    string
	name  string
	color ?string @[json_null]
}

struct EntryOut {
	id              string
	organization_id string  @[json: 'organizationId']
	user_id         string  @[json: 'userId']
	project_id      ?string @[json: 'projectId'; json_null]
	description     string
	ticket          ?string @[json_null]
	started_at      string  @[json: 'startedAt']
	stopped_at      ?string @[json: 'stoppedAt'; json_null]
}

// GET /timer's: the running entry and its project.
struct TimerOut {
	id              string
	organization_id string  @[json: 'organizationId']
	user_id         string  @[json: 'userId']
	project_id      ?string @[json: 'projectId'; json_null]
	description     string
	ticket          ?string     @[json_null]
	started_at      string      @[json: 'startedAt']
	stopped_at      ?string     @[json: 'stoppedAt'; json_null]
	project         ?ProjectRef @[json_null]
}

struct StartOut {
	started EntryOut
	stopped ?EntryOut @[json_null]
}

@[heap]
struct Snow {
	orgs         []Org
	projects     []Project
	people       []Person
	entries      []Entry // by person, then by start
	by_token     []Keyed
	by_person_id []Keyed
	by_entry_id  []Keyed
	template     bool
mut:
	// JSON=template's: each session, each person's timer as GET /timer
	// answers it, each project, and each entry.
	session_json []string
	timer_json   []string
	project_json []string
	entry_json   []EntryJson
}

fn iso_of(s string) i64 {
	return parse_iso(s) or { stop("snow: a time that isn't toISOString's") }
}

fn iso_or_null(s ?string) ?i64 {
	return iso_of(s?)
}

fn iso_opt(ms ?i64) ?string {
	return iso(ms?)
}

fn is_lower_hex(c u8) bool {
	return (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`)
}

// snowtime's Uuidv7: 8-4-4-4-12 lower-case hex digits, version 7, variant 8
// to b.
fn is_uuid7(s string) bool {
	if !(s.len == 36 && s[14] == `7` && s[19] in [`8`, `9`, `a`, `b`]) {
		return false
	}
	for i, c in s {
		dash := i == 8 || i == 13 || i == 18 || i == 23
		if (dash && c != `-`) || (!dash && !is_lower_hex(c)) {
			return false
		}
	}
	return true
}

// The time a uuidv7 was made, from its first 48 bits.
fn uuid_ms(s string) i64 {
	mut v := i64(0)
	for c in s[..13] {
		if c != `-` {
			v = v * 16 + i64(if c <= `9` { c - `0` } else { c - `a` + 10 })
		}
	}
	return v
}

// snowtime's ticket key: [A-Z][A-Z0-9]{1,9}-[1-9][0-9]{0,6}.
fn is_ticket(s string) bool {
	dash := s.index_u8(`-`)
	if dash < 2 || dash > 10 || !(s[0] >= `A` && s[0] <= `Z`) {
		return false
	}
	for c in s[1..dash] {
		if !((c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)) {
			return false
		}
	}
	n := s[dash + 1..]
	if n.len == 0 || n.len > 7 || !(n[0] >= `1` && n[0] <= `9`) {
		return false
	}
	for c in n {
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}

// The first value of name in the query q, as written; a key without '='
// has the empty value.
fn query_value(q string, name string) ?string {
	mut i := 0
	for i <= q.len {
		mut end := i
		for end < q.len && q[end] != `&` {
			end++
		}
		pair := q[i..end]
		eq := pair.index_u8(`=`)
		key := if eq < 0 { pair } else { pair[..eq] }
		if key.len > 0 && key == name {
			return if eq < 0 { '' } else { pair[eq + 1..] }
		}
		i = end + 1
	}
	return none
}

// A query value with its percent-escapes decoded, or none for a '%' without
// two hex digits after it; '+' stays.
fn percent_decoded(s string) ?string {
	if s.index_u8(`%`) < 0 {
		return s
	}
	mut out := strings.new_builder(s.len)
	mut i := 0
	for i < s.len {
		if s[i] == `%` {
			a := if i + 1 < s.len { hex(s[i + 1]) } else { -1 }
			b := if i + 2 < s.len { hex(s[i + 2]) } else { -1 }
			if a < 0 || b < 0 {
				return none
			}
			out.write_u8(u8(a * 16 + b))
			i += 3
		} else {
			out.write_u8(s[i])
			i++
		}
	}
	return out.str()
}

// The value of cookie name in the Cookie fields, without the quotes it may
// have; the first, if it repeats. viltrum's Ctx has no cookie accessor.
fn cookie_of(c &viltrum.Ctx, name string) ?string {
	ows := ' \t\n\r\x0c'
	mut fields := c.header_values('cookie')
	for {
		v := fields.next() or { break }
		for raw in v.split(';') {
			pair := raw.trim(ows)
			eq := pair.index_u8(`=`)
			if eq <= 0 || pair[..eq].trim(ows) != name {
				continue
			}
			value := pair[eq + 1..].trim(ows)
			if value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
				return value[1..value.len - 1]
			}
			return value
		}
	}
	return none
}

fn is_admin(m Member) bool {
	return m.role == 'owner' || m.role == 'admin'
}

fn coded(status int, code string, key string) Reply {
	return json_str(status, '{"error":{"code":"${code}","key":"${key}"}}')
}

// A query or body that doesn't validate.
fn invalid() Reply {
	return json_str(400, '{"error":{"message":"Invalid input."}}')
}

fn not_json() Reply {
	return json_str(400, '{"error":{"message":"The body is not JSON."}}')
}

fn cross_origin() Reply {
	return json_str(403, '{"error":{"message":"Cross-origin request refused."}}')
}

fn sign_in_required() Reply {
	return coded(401, 'UNAUTHENTICATED', 'sign_in_required')
}

fn snow_not_found() Reply {
	return json_str(404, '{"error":{"message":"No such call."}}')
}

// key's record in sorted.
fn find_by(sorted []Keyed, key string) ?int {
	mut lo, mut hi := 0, sorted.len
	for lo < hi {
		mid := (lo + hi) / 2
		if sorted[mid].key < key {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	if lo < sorted.len && sorted[lo].key == key {
		return sorted[lo].i
	}
	return none
}

fn keyed(keys []string) []Keyed {
	mut out := []Keyed{cap: keys.len}
	for i, k in keys {
		out << Keyed{k, i}
	}
	out.sort(a.key < b.key)
	return out
}

fn org_index(orgs []Org, id string) ?int {
	for i, o in orgs {
		if o.id == id {
			return i
		}
	}
	return none
}

fn project_index(projects []Project, o Org, id string) ?int {
	for i in o.first .. o.first + o.count {
		if projects[i].id == id {
			return i
		}
	}
	return none
}

// The signed-in person, by the session cookie's value: a 64-character token,
// a '.', and its signature, which isn't checked.
fn (s &Snow) signed_in(c &viltrum.Ctx) ?int {
	v := cookie_of(c, session_cookie)?
	if !(v.len > 65 && v[64] == `.`) {
		return none
	}
	return find_by(s.by_token, v[..64])
}

// Person u's membership of the organization of id org, as an index into
// their orgs.
fn (s &Snow) member(u int, org string) ?int {
	for k, m in s.people[u].orgs {
		if s.orgs[m.org].id == org {
			return k
		}
	}
	return none
}

fn (s &Snow) session_out(u int) SessionOut {
	p := &s.people[u]
	return SessionOut{
		user:                   UserOut{
			id:    p.id
			name:  p.name
			email: p.email
			image: p.image
		}
		signed_in_at:           iso_opt(p.signed_in)
		organizations:          p.orgs.map(OrgOut{
			id:          s.orgs[it.org].id
			name:        s.orgs[it.org].name
			slug:        s.orgs[it.org].slug
			issue_links: s.orgs[it.org].links
			role:        it.role
		})
		active_organization_id: s.orgs[p.active].id
		settings:               &p.settings
		fill:                   &p.fill
		app_url:                app_url
	}
}

fn project_out(j Project) ProjectOut {
	return ProjectOut{
		id:          j.id
		name:        j.name
		color:       j.color
		archived_at: iso_opt(j.archived)
		has_entries: j.has_entries
		team_ids:    j.teams
	}
}

fn (s &Snow) entry_out(i int, description string, stopped ?i64) EntryOut {
	e := &s.entries[i]
	mut project := ?string(none)
	if j := e.project {
		project = s.projects[j].id
	}
	return EntryOut{
		id:              e.id
		organization_id: s.orgs[e.org].id
		user_id:         s.people[e.user].id
		project_id:      project
		description:     description
		ticket:          e.ticket
		started_at:      iso(e.started)
		stopped_at:      iso_opt(stopped)
	}
}

fn (s &Snow) timer_out(i int) TimerOut {
	e := &s.entries[i]
	o := s.entry_out(i, e.description, none)
	mut project := ?ProjectRef(none)
	if k := e.project {
		j := &s.projects[k]
		project = ProjectRef{
			id:    j.id
			name:  j.name
			color: j.color
		}
	}
	return TimerOut{
		id:              o.id
		organization_id: o.organization_id
		user_id:         o.user_id
		project_id:      o.project_id
		description:     o.description
		ticket:          o.ticket
		started_at:      o.started_at
		project:         project
	}
}

// An entry that started at started, stopped at now as stopRunning stops it:
// after it started, and at most a day after.
fn stopped_at(started i64, now i64) i64 {
	at := if now > started { now } else { started + 1 }
	return if at > started + day { started + day } else { at }
}

fn (s &Snow) stopped_into(mut out strings.Builder, i int, now i64) {
	at := stopped_at(s.entries[i].started, now)
	if s.template {
		// A running entry's JSON ends in "null}".
		j := s.entry_json[i].json
		out.write_string(j[..j.len - 5])
		push_iso(mut out, at)
		out.write_u8(`}`)
	} else {
		out.write_string(json2.encode(s.entry_out(i, s.entries[i].description, at)))
	}
}

// listProjects's visibility: an admin sees every project, a member those
// with no team and those of a team of theirs.
fn sees(p &Person, m Member, j &Project) bool {
	if is_admin(m) || j.teams.len == 0 {
		return true
	}
	if m.org != p.active {
		return false
	}
	return j.teams.any(it in p.teams)
}

// Prebuilt records joined with ',' between '[' and ']'.
fn joined(listed []int, part fn (i int) string) Reply {
	mut b := strings.new_builder(listed.len * 320 + 2)
	b.write_u8(`[`)
	for k, i in listed {
		if k > 0 {
			b.write_u8(`,`)
		}
		b.write_string(part(i))
	}
	b.write_u8(`]`)
	return json_ok(b)
}

// A body's members, if it's one JSON object.
fn object_of(body string) ?map[string]json2.Any {
	v := json2.decode[json2.Any](body) or { return none }
	if v is map[string]json2.Any {
		return v
	}
	return none
}

// Whether m's member key, if present, is a string, or with nullable, null.
fn typed(m map[string]json2.Any, key string, nullable bool) bool {
	v := m[key] or { return true }
	return v is string || (nullable && v is json2.Null)
}

// m's member key, if it's a string.
fn text(m map[string]json2.Any, key string) ?string {
	v := m[key] or { return none }
	if v is string {
		return v
	}
	return none
}

// GET .../entries: the entries of userId, or of the caller, that overlap
// [from, to), newest first, as listEntries selects them.
fn list_entries(s &Snow, mut c viltrum.Ctx, u int, k int) Reply {
	p := &s.people[u]
	m := p.orgs[k]
	q := c.query()
	from_s := percent_decoded(query_value(q, 'from') or { return invalid() }) or {
		return invalid()
	}
	to_s := percent_decoded(query_value(q, 'to') or { return invalid() }) or { return invalid() }
	from := parse_iso(from_s) or { return invalid() }
	to := parse_iso(to_s) or { return invalid() }
	if !(to > from && to - from <= 93 * day) {
		return invalid()
	}
	mut who := ?int(u)
	if raw := query_value(q, 'userId') {
		uid := percent_decoded(raw) or { return invalid() }
		if !is_uuid7(uid) {
			return invalid()
		}
		if uid != p.id {
			if !is_admin(m) {
				return coded(403, 'FORBIDDEN', 'entries_forbidden')
			}
			who = find_by(s.by_person_id, uid)
		}
	}
	mut listed := []int{}
	if w := who {
		pw := &s.people[w]
		if pw.active == m.org {
			// The first of w's entries that starts at to or later.
			mut lo, mut hi := pw.first, pw.first + pw.count
			for lo < hi {
				mid := (lo + hi) / 2
				if s.entries[mid].started < to {
					lo = mid + 1
				} else {
					hi = mid
				}
			}
			mut i := lo
			for i > pw.first && s.entries[i - 1].started > from - day {
				i--
				if (s.entries[i].stopped or { max_i64 }) > from {
					listed << i
				}
			}
		}
	}
	if s.template {
		return joined(listed, fn [s] (i int) string {
			return s.entry_json[i].json
		})
	}
	return json_ok(written(listed.map(s.entry_out(it, s.entries[it].description,
		s.entries[it].stopped))))
}

fn list_projects(s &Snow, mut c viltrum.Ctx, u int, k int) Reply {
	p := &s.people[u]
	m := p.orgs[k]
	mut archived := false
	if v := query_value(c.query(), 'includeArchived') {
		if v != 'true' && v != 'false' {
			return invalid()
		}
		archived = v == 'true'
	}
	o := s.orgs[m.org]
	mut listed := []int{}
	for i in o.first .. o.first + o.count {
		j := &s.projects[i]
		if (archived || j.archived == none) && sees(p, m, j) {
			listed << i
		}
	}
	if s.template {
		return joined(listed, fn [s] (i int) string {
			return s.project_json[i]
		})
	}
	return json_ok(written(listed.map(project_out(s.projects[it]))))
}

fn patch_entry(s &Snow, mut c viltrum.Ctx, u int, k int) Reply {
	p := &s.people[u]
	m := p.orgs[k]
	id := c.param('id') or { '' }
	if !is_uuid7(id) {
		return invalid()
	}
	body := view(c.body())
	if !is_json(body) {
		return not_json()
	}
	patch := object_of(body) or { return invalid() }
	if !typed(patch, 'description', false) {
		return invalid()
	}
	mut description := ?string(none)
	if d := text(patch, 'description') {
		trimmed := d.trim(' \t\n\r')
		if trimmed.len > 500 {
			return invalid()
		}
		description = trimmed
	}
	i := s.entry_index(id) or { return coded(404, 'NOT_FOUND', 'entry_not_found') }
	e := &s.entries[i]
	if e.org != m.org {
		return coded(404, 'NOT_FOUND', 'entry_not_found')
	}
	if s.people[e.user].id != p.id && !is_admin(m) {
		return coded(403, 'FORBIDDEN', 'entry_forbidden')
	}
	d := description or {
		if s.template {
			return json_str(200, s.entry_json[i].json)
		}
		return json_ok(written(s.entry_out(i, e.description, e.stopped)))
	}

	if s.template {
		t := &s.entry_json[i]
		mut buf := strings.new_builder(t.json.len + d.len + 8)
		buf.write_string(t.json[..t.desc])
		push_string(mut buf, d)
		buf.write_string(t.json[t.tail..])
		return json_ok(buf)
	}
	return json_ok(written(s.entry_out(i, d, e.stopped)))
}

fn (s &Snow) entry_index(id string) ?int {
	return find_by(s.by_entry_id, id)
}

// POST .../timer/start: the new entry, started now, and the timer it
// stopped, the caller's running one, or null.
fn start_timer(s &Snow, mut c viltrum.Ctx, u int, k int) Reply {
	p := &s.people[u]
	m := p.orgs[k]
	body := view(c.body())
	if !is_json(body) {
		return not_json()
	}
	start := object_of(body) or { return invalid() }
	if !(typed(start, 'id', false) && typed(start, 'description', false)
		&& typed(start, 'ticket', true) && typed(start, 'projectId', true)) {
		return invalid()
	}
	id := text(start, 'id') or { return invalid() }
	description := (text(start, 'description') or { '' }).trim(' \t\n\r')
	ticket := text(start, 'ticket')
	project_id := text(start, 'projectId')
	if !(description.len <= 500 && is_uuid7(id)) {
		return invalid()
	}
	if t := ticket {
		if !(t.len <= 18 && is_ticket(t)) {
			return invalid()
		}
	}
	if pid := project_id {
		if !is_uuid7(pid) {
			return invalid()
		}
	}
	if pid := project_id {
		j := project_index(s.projects, s.orgs[m.org], pid) or {
			return coded(404, 'NOT_FOUND', 'project_not_found')
		}
		if !sees(p, m, &s.projects[j]) {
			return coded(404, 'NOT_FOUND', 'project_not_found')
		}
		if s.projects[j].archived != none {
			return coded(409, 'CONFLICT', 'project_archived')
		}
	}
	if s.entry_index(id) != none {
		return coded(409, 'CONFLICT', 'entry_id_taken')
	}
	now := now_ms()
	started := EntryOut{
		id:              id
		organization_id: s.orgs[m.org].id
		user_id:         p.id
		project_id:      project_id
		description:     description
		ticket:          ticket
		started_at:      iso(now)
	}
	if s.template {
		mut buf := strings.new_builder(1024)
		buf.write_string('{"started":')
		buf.write_string(json2.encode(started))
		buf.write_string(',"stopped":')
		if r := p.running {
			s.stopped_into(mut buf, r, now)
		} else {
			buf.write_string('null')
		}
		buf.write_u8(`}`)
		return json_ok(buf)
	}
	mut stopped := ?EntryOut(none)
	if r := p.running {
		stopped = s.entry_out(r, s.entries[r].description, stopped_at(s.entries[r].started, now))
	}
	return json_ok(written(StartOut{
		started: started
		stopped: stopped
	}))
}

// POST /timer/stop: the caller's running entry, stopped now. An id the
// dataset doesn't have is taken for a timer started with it, as timer start
// answered it: a uuidv7 made in the last day.
fn stop_timer(s &Snow, mut c viltrum.Ctx, u int) Reply {
	body := view(c.body())
	if !is_json(body) {
		return not_json()
	}
	stop_body := object_of(body) or { return invalid() }
	if !typed(stop_body, 'id', false) {
		return invalid()
	}
	id := text(stop_body, 'id') or { return invalid() }
	if !is_uuid7(id) {
		return invalid()
	}
	p := &s.people[u]
	now := now_ms()
	if r := p.running {
		if s.entries[r].id == id {
			mut buf := strings.new_builder(512)
			s.stopped_into(mut buf, r, now)
			return json_ok(buf)
		}
	}
	started := uuid_ms(id)
	if !(started > now - day && started <= now + minute && s.entry_index(id) == none) {
		return coded(404, 'NOT_FOUND', 'timer_not_running')
	}
	return json_ok(written(EntryOut{
		id:              id
		organization_id: s.orgs[p.active].id
		user_id:         p.id
		started_at:      iso(started)
		stopped_at:      iso(stopped_at(started, now))
	}))
}

type SignedCall = fn (s &Snow, mut c viltrum.Ctx, u int) Reply

type MemberCall = fn (s &Snow, mut c viltrum.Ctx, u int, k int) Reply

// A route that needs a sign-in: answers 401 without one.
fn signed_route(s &Snow, f SignedCall) viltrum.Handler {
	return fn [s, f] (mut c viltrum.Ctx) {
		u := s.signed_in(c) or {
			answer(mut c, sign_in_required())
			return
		}
		answer(mut c, f(s, mut c, u))
	}
}

// A route of an organization's: answers 401 without a sign-in, then 403 to
// one who isn't the path's organization's member.
fn member_route(s &Snow, f MemberCall) viltrum.Handler {
	return signed_route(s, fn [f] (s &Snow, mut c viltrum.Ctx, u int) Reply {
		k := s.member(u, c.param('org') or { '' }) or {
			return coded(403, 'FORBIDDEN', 'not_organization_member')
		}
		return f(s, mut c, u, k)
	})
}

// A write needs Origin to be the app's.
fn same_origin(mut c viltrum.Ctx) {
	method := c.method()
	if method != .get && method != .head && (c.header('origin') or { '' }) != app_url {
		answer(mut c, cross_origin())
		return
	}
	c.next()
}

fn (mut s Snow) prebuild() {
	for u in 0 .. s.people.len {
		s.session_json << json2.encode(s.session_out(u))
	}
	for p in s.people {
		s.timer_json << if r := p.running { json2.encode(s.timer_out(r)) } else { 'null' }
	}
	for j in s.projects {
		s.project_json << json2.encode(project_out(j))
	}
	for i, e in s.entries {
		j := json2.encode(s.entry_out(i, e.description, e.stopped))
		// A string's quotes are escaped, so these members' keys are the
		// first such bytes.
		desc := j.index(',"description":') or { stop('snow: an entry without a description') }
		tail := j.index_after(',"ticket":', desc) or { stop('snow: an entry without a ticket') }
		s.entry_json << EntryJson{j, desc + 15, tail}
	}
}

fn load_snow(cfg Config) &Snow {
	mut orgs := []Org{}
	mut projects := []Project{}
	for o in parse_file[OrgFile](cfg.dir, 'snow-orgs.json') {
		first := projects.len
		for j in o.projects {
			projects << Project{
				id:          j.id
				name:        j.name
				color:       j.color
				archived:    iso_or_null(j.archived_at)
				has_entries: j.has_entries
				teams:       j.team_ids
			}
		}
		orgs << Org{
			id:    o.id
			name:  o.name
			slug:  o.slug
			links: o.issue_links
			first: first
			count: o.projects.len
		}
	}
	mut people := []Person{}
	for f in parse_file[PersonFile](cfg.dir, 'snow-users.json') {
		mut member_of := []Member{}
		for m in f.organizations {
			org := org_index(orgs, m.id) or {
				stop('snow: a member of an organization snow-orgs.json lacks')
			}
			member_of << Member{org, m.role}
		}
		active := org_index(orgs, f.active_organization_id) or {
			stop('snow: a user without an organization')
		}
		if f.token.len != 64 {
			stop('snow: a user without a token')
		}
		people << Person{
			id:        f.id
			name:      f.name
			email:     f.email
			image:     f.image
			token:     f.token
			signed_in: iso_or_null(f.signed_in_at)
			orgs:      member_of
			active:    active
			teams:     f.team_ids
			settings:  f.settings
			fill:      f.fill
		}
	}
	by_person_id := keyed(people.map(it.id))
	mut entries := []Entry{}
	for f in parse_file[EntryFile](cfg.dir, 'snow-entries.json') {
		org := org_index(orgs, f.organization_id) or {
			stop('snow: an entry of an organization snow-orgs.json lacks')
		}
		user := find_by(by_person_id, f.user_id) or {
			stop('snow: an entry of a user snow-users.json lacks')
		}
		mut project := ?int(none)
		if pid := f.project_id {
			project = project_index(projects, orgs[org], pid) or {
				stop('snow: an entry of a project snow-orgs.json lacks')
			}
		}
		started := iso_of(f.started_at)
		n := entries.len
		if people[user].count == 0 {
			people[user].first = n
		}
		if people[user].first + people[user].count != n {
			stop("snow: snow-entries.json doesn't have each user's entries together")
		}
		if people[user].count != 0 && !(entries[n - 1].started < started) {
			stop("snow: a user's entries out of order")
		}
		people[user].count++
		stopped := iso_or_null(f.stopped_at)
		if stopped == none {
			people[user].running = n
		}
		entries << Entry{
			id:          f.id
			user:        user
			org:         org
			project:     project
			description: f.description
			ticket:      f.ticket
			started:     started
			stopped:     stopped
		}
	}
	mut s := &Snow{
		orgs:         orgs
		projects:     projects
		people:       people
		entries:      entries
		by_token:     keyed(people.map(it.token))
		by_person_id: by_person_id
		by_entry_id:  keyed(entries.map(it.id))
		template:     cfg.template
	}
	if cfg.template {
		s.prebuild()
	}
	return s
}

fn snow_routes(mut app viltrum.App, s &Snow) {
	mut api := app.group('/api/v1', same_origin)
	api.get('/session', fn [s] (mut c viltrum.Ctx) {
		u := s.signed_in(c) or {
			answer(mut c, json_str(200, 'null'))
			return
		}
		if s.template {
			answer(mut c, json_str(200, s.session_json[u]))
		} else {
			answer(mut c, json_ok(written(s.session_out(u))))
		}
	})
	api.get('/timer', signed_route(s, fn (s &Snow, mut c viltrum.Ctx, u int) Reply {
		if s.template {
			return json_str(200, s.timer_json[u])
		}
		if r := s.people[u].running {
			return json_ok(written(s.timer_out(r)))
		}
		return json_str(200, 'null')
	}))
	api.post('/timer/stop', signed_route(s, stop_timer))
	api.get('/organizations/:org/entries', member_route(s, list_entries))
	api.get('/organizations/:org/projects', member_route(s, list_projects))
	api.patch('/organizations/:org/entries/:id', member_route(s, patch_entry))
	api.post('/organizations/:org/timer/start', member_route(s, start_timer))
}
