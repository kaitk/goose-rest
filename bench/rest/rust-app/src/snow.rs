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
// A server checks in snowtime's order: an unknown call (not_found), a write
// from another origin (cross_origin), GET /session, which answers null to no
// one, the sign-in (person, else sign_in_required), and the organization's
// membership (member). Only then are the query and body read.

use serde::{Deserialize, Serialize};

use crate::{
    data, de_iso, de_iso_or_null, de_string, is_json, is_object, iso, iso_or_null, join, json, now_ms, parse_iso,
    push_iso, read_file, seq_of, Reply, DAY, MINUTE,
};

pub const APP_URL: &str = "https://time.bench.example.com";
pub const SESSION_COOKIE: &str = "__Secure-better-auth.session_token";

#[derive(Deserialize)]
struct OrgFile {
    id: String,
    name: String,
    slug: String,
    #[serde(rename = "issueLinks")]
    links: Option<String>,
    projects: Vec<Project>,
}

struct Org {
    id: String,
    name: String,
    slug: String,
    links: Option<String>,
    first: usize, // its projects, projects[first..first + count]
    count: usize,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Project {
    id: String,
    name: String,
    color: Option<String>,
    #[serde(rename = "archivedAt", deserialize_with = "de_iso_or_null", serialize_with = "iso_or_null")]
    archived: Option<i64>,
    has_entries: bool,
    team_ids: Vec<String>,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Settings {
    time_zone: String,
    week_start: String,
    locale: String,
    theme: String,
    timer_layout: String,
    show_summary: bool,
    compact_rows: bool,
    wide_timer: bool,
    timer_view: String,
    calendar_weekend: bool,
    app_icon: String,
    scene_collection: String,
    scene_pin: Option<String>,
    scene_background: bool,
    scene_strength: String,
    surfaces: String,
    scene_weather: bool,
    scene_intro: bool,
    scene_tagline: bool,
    duration_format: String,
    date_format: String,
    time_format: String,
    copy_duration_pattern: String,
    copy_duration_control: String,
    country: Option<String>,
}

#[derive(Deserialize, Serialize)]
struct LastDay {
    date: String,
    filled: bool,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Fill {
    date: String,
    timer_started_at: Option<i64>,
    today: String,
    last_working_day: Option<LastDay>,
    last_week: Option<bool>,
    last_month: Option<bool>,
    caught_up: bool,
    empty_days: i64,
    streak: i64,
}

#[derive(Deserialize)]
struct MemberFile {
    id: String,
    role: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PersonFile {
    id: String,
    name: String,
    email: String,
    image: Option<String>,
    token: String,
    #[serde(deserialize_with = "de_iso_or_null")]
    signed_in_at: Option<i64>,
    organizations: Vec<MemberFile>,
    active_organization_id: String,
    team_ids: Vec<String>,
    settings: Settings,
    fill: Fill,
}

struct Member {
    org: usize,
    role: String,
}

struct Person {
    id: String,
    name: String,
    email: String,
    image: Option<String>,
    token: String,
    signed_in: Option<i64>,
    orgs: Vec<Member>, // as the session lists them
    active: usize,
    teams: Vec<String>, // in the active organization
    settings: Settings,
    fill: Fill,
    first: usize, // the person's entries, entries[first..first + count]
    count: usize,
    running: Option<usize>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct EntryFile {
    id: String,
    organization_id: String,
    user_id: String,
    project_id: Option<String>,
    description: String,
    ticket: Option<String>,
    #[serde(deserialize_with = "de_iso")]
    started_at: i64,
    #[serde(deserialize_with = "de_iso_or_null")]
    stopped_at: Option<i64>,
}

struct Entry {
    id: String,
    user: usize,
    org: usize,
    project: Option<usize>,
    description: String,
    ticket: Option<String>,
    started: i64,
    stopped: Option<i64>,
}

// An entry's prebuilt JSON, and where its description's value starts and
// ends, for a PATCH to put another there.
struct EntryJson {
    json: Vec<u8>,
    desc: usize,
    tail: usize,
}

#[derive(Default)]
pub struct Snow {
    orgs: Vec<Org>,
    projects: Vec<Project>,
    people: Vec<Person>,
    entries: Vec<Entry>,        // by person, then by start
    by_token: Vec<usize>,       // people, by token
    by_person_id: Vec<usize>,   // people, by id
    by_entry_id: Vec<usize>,    // entries, by id
    // JSON=template's: each session, each running timer as GET /timer
    // answers it, each project, and each entry.
    session_json: Vec<Vec<u8>>,
    timer_json: Vec<Vec<u8>>,
    project_json: Vec<Vec<u8>>,
    entry_json: Vec<EntryJson>,
}

#[derive(Serialize)]
struct UserOut<'a> {
    id: &'a str,
    name: &'a str,
    email: &'a str,
    image: &'a Option<String>,
}

#[derive(Serialize)]
struct OrgOut<'a> {
    id: &'a str,
    name: &'a str,
    slug: &'a str,
    #[serde(rename = "issueLinks")]
    links: &'a Option<String>,
    role: &'a str,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SessionOut<'a, O> {
    user: UserOut<'a>,
    #[serde(serialize_with = "iso_or_null")]
    signed_in_at: Option<i64>,
    organizations: O,
    active_organization_id: &'a str,
    settings: &'a Settings,
    fill: &'a Fill,
    invitation_id: Option<()>,
    app_url: &'static str,
}

#[derive(Serialize)]
struct ProjectRef<'a> {
    id: &'a str,
    name: &'a str,
    color: &'a Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct EntryOut<'a> {
    id: &'a str,
    organization_id: &'a str,
    user_id: &'a str,
    project_id: Option<&'a str>,
    description: &'a str,
    ticket: Option<&'a str>,
    #[serde(serialize_with = "iso")]
    started_at: i64,
    #[serde(serialize_with = "iso_or_null")]
    stopped_at: Option<i64>,
    // GET /timer's: the running entry's project, or null.
    #[serde(skip_serializing_if = "Option::is_none")]
    project: Option<Option<ProjectRef<'a>>>,
}

#[derive(Serialize)]
struct StartOut<'a> {
    started: EntryOut<'a>,
    stopped: Option<EntryOut<'a>>,
}

#[derive(Deserialize)]
struct PatchBody {
    #[serde(default, deserialize_with = "de_string")]
    description: Option<String>,
}

#[derive(Deserialize)]
struct StartBody {
    #[serde(default, deserialize_with = "de_string")]
    id: Option<String>,
    #[serde(default, deserialize_with = "de_string")]
    description: Option<String>,
    #[serde(default)]
    ticket: Option<String>,
    #[serde(default, rename = "projectId")]
    project_id: Option<String>,
}

#[derive(Deserialize)]
struct StopBody {
    #[serde(default, deserialize_with = "de_string")]
    id: Option<String>,
}

fn is_lower_hex(c: u8) -> bool {
    c.is_ascii_digit() || (b'a'..=b'f').contains(&c)
}

// snowtime's Uuidv7: 8-4-4-4-12 lower-case hex digits, version 7, variant 8
// to b.
fn is_uuid7(s: &[u8]) -> bool {
    s.len() == 36 && s[14] == b'7' && matches!(s[19], b'8' | b'9' | b'a' | b'b')
        && s.iter().enumerate().all(|(i, &c)| if matches!(i, 8 | 13 | 18 | 23) { c == b'-' } else { is_lower_hex(c) })
}

// The time a uuidv7 was made, from its first 48 bits.
fn uuid_ms(s: &[u8]) -> i64 {
    s[..13].iter().filter(|&&c| c != b'-')
        .fold(0, |v, &c| v * 16 + i64::from(if c <= b'9' { c - b'0' } else { c - b'a' + 10 }))
}

// snowtime's ticket key: [A-Z][A-Z0-9]{1,9}-[1-9][0-9]{0,6}.
fn is_ticket(s: &str) -> bool {
    let s = s.as_bytes();
    let Some(dash) = s.iter().position(|&c| c == b'-') else { return false };
    if !((2..=10).contains(&dash) && s[0].is_ascii_uppercase()) {
        return false;
    }
    if !s[1..dash].iter().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit()) {
        return false;
    }
    let n = &s[dash + 1..];
    (1..=7).contains(&n.len()) && (b'1'..=b'9').contains(&n[0]) && n.iter().all(u8::is_ascii_digit)
}

// Trimmed of the whitespace JSON allows, as the Goose server's trim.
fn trim(s: &str) -> &str {
    s.trim_matches(|c| matches!(c, ' ' | '\t' | '\n' | '\r'))
}

fn is_admin(m: &Member) -> bool {
    m.role == "owner" || m.role == "admin"
}

fn coded(status: u16, code: &str, key: &str) -> Reply {
    Reply::json(status, format!("{{\"error\":{{\"code\":\"{code}\",\"key\":\"{key}\"}}}}"))
}

// A query or body that doesn't validate.
pub fn invalid() -> Reply {
    Reply::json(400, "{\"error\":{\"message\":\"Invalid input.\"}}")
}

fn not_json() -> Reply {
    Reply::json(400, "{\"error\":{\"message\":\"The body is not JSON.\"}}")
}

// A path or method under /api/v1 that no route takes.
pub fn not_found() -> Reply {
    Reply::json(404, "{\"error\":{\"message\":\"No such call.\"}}")
}

// A write whose Origin isn't APP_URL.
pub fn cross_origin() -> Reply {
    Reply::json(403, "{\"error\":{\"message\":\"Cross-origin request refused.\"}}")
}

pub fn sign_in_required() -> Reply {
    coded(401, "UNAUTHENTICATED", "sign_in_required")
}

// The person the session cookie's value names: a 64-character token, a '.',
// and its signature, which isn't checked.
pub fn person(cookie: &[u8]) -> Option<usize> {
    let s = &data().snow;
    if !(cookie.len() > 65 && cookie[64] == b'.') {
        return None;
    }
    let token = &cookie[..64];
    s.by_token.binary_search_by(|&i| s.people[i].token.as_bytes().cmp(token)).ok().map(|k| s.by_token[k])
}

// A signed-in person's membership of the organization a path names.
pub struct Membership {
    person: usize,
    member: usize, // of the person's orgs
}

// The membership of person u in the organization of id org, or 403.
pub fn member(u: usize, org: &str) -> Result<Membership, Reply> {
    let s = &data().snow;
    match s.people[u].orgs.iter().position(|m| s.orgs[m.org].id == org) {
        Some(member) => Ok(Membership { person: u, member }),
        None => Err(coded(403, "FORBIDDEN", "not_organization_member")),
    }
}

// GET /api/v1/session, of the person the cookie names, if any.
pub fn session(u: Option<usize>) -> Reply {
    let d = data();
    let mut buf = Vec::new();
    match u {
        None => buf.extend_from_slice(b"null"),
        Some(u) if d.template => buf.extend_from_slice(&d.snow.session_json[u]),
        Some(u) => serde_json::to_writer(&mut buf, &d.snow.session_out(u)).unwrap(),
    }
    json(buf)
}

// GET /api/v1/timer.
pub fn timer(u: usize) -> Reply {
    let d = data();
    let s = &d.snow;
    let mut buf = Vec::new();
    match s.people[u].running {
        _ if d.template => buf.extend_from_slice(&s.timer_json[u]),
        Some(i) => serde_json::to_writer(&mut buf, &s.timer_out(i)).unwrap(),
        None => buf.extend_from_slice(b"null"),
    }
    json(buf)
}

// POST /api/v1/timer/stop.
pub fn stop_timer(u: usize, body: &[u8]) -> Reply {
    let d = data();
    d.snow.stop_timer(d.template, body, u, Vec::new())
}

// GET /api/v1/organizations/:org/entries, with the query's values decoded.
pub fn list_entries(m: &Membership, from: Option<&str>, to: Option<&str>, user_id: Option<&str>) -> Reply {
    let d = data();
    let p = &d.snow.people[m.person];
    d.snow.list_entries(d.template, from, to, user_id, p, &p.orgs[m.member], Vec::new())
}

// GET /api/v1/organizations/:org/projects, with includeArchived's value.
pub fn list_projects(m: &Membership, include_archived: Option<&str>) -> Reply {
    let d = data();
    let p = &d.snow.people[m.person];
    d.snow.list_projects(d.template, include_archived, p, &p.orgs[m.member], Vec::new())
}

// PATCH /api/v1/organizations/:org/entries/:id.
pub fn patch_entry(m: &Membership, id: &str, body: &[u8]) -> Reply {
    let d = data();
    let p = &d.snow.people[m.person];
    d.snow.patch_entry(d.template, id.as_bytes(), body, p, &p.orgs[m.member], Vec::new())
}

// POST /api/v1/organizations/:org/timer/start.
pub fn start_timer(m: &Membership, body: &[u8]) -> Reply {
    let d = data();
    let p = &d.snow.people[m.person];
    d.snow.start_timer(d.template, body, m.person, &p.orgs[m.member], Vec::new())
}

impl Snow {
    pub fn records(&self) -> usize {
        self.entries.len()
    }

    pub fn load(dir: &str, template: bool) -> Snow {
        let mut s = Snow::default();
        let orgs: Vec<OrgFile> = serde_json::from_slice(&read_file(dir, "snow-orgs.json")).expect("snow-orgs.json");
        for o in orgs {
            let first = s.projects.len();
            let count = o.projects.len();
            s.projects.extend(o.projects);
            s.orgs.push(Org { id: o.id, name: o.name, slug: o.slug, links: o.links, first, count });
        }
        let people: Vec<PersonFile> =
            serde_json::from_slice(&read_file(dir, "snow-users.json")).expect("snow-users.json");
        for p in people {
            let orgs = p.organizations.into_iter()
                .map(|m| Member {
                    org: s.org_index(&m.id).expect("a member of an organization snow-orgs.json lacks"),
                    role: m.role,
                })
                .collect();
            let active = s.org_index(&p.active_organization_id).expect("a user without an organization");
            assert!(p.token.len() == 64, "a user without a token");
            s.people.push(Person {
                id: p.id,
                name: p.name,
                email: p.email,
                image: p.image,
                token: p.token,
                signed_in: p.signed_in_at,
                orgs,
                active,
                teams: p.team_ids,
                settings: p.settings,
                fill: p.fill,
                first: 0,
                count: 0,
                running: None,
            });
        }
        s.by_token = (0..s.people.len()).collect();
        s.by_token.sort_by(|&a, &b| s.people[a].token.cmp(&s.people[b].token));
        s.by_person_id = (0..s.people.len()).collect();
        s.by_person_id.sort_by(|&a, &b| s.people[a].id.cmp(&s.people[b].id));
        let entries: Vec<EntryFile> =
            serde_json::from_slice(&read_file(dir, "snow-entries.json")).expect("snow-entries.json");
        for e in entries {
            let org = s.org_index(&e.organization_id).expect("an entry of an organization snow-orgs.json lacks");
            let user = s.person_index(e.user_id.as_bytes()).expect("an entry of a user snow-users.json lacks");
            let project = e.project_id.map(|id| s.project_index(id.as_bytes(), org)
                .expect("an entry of a project snow-orgs.json lacks"));
            let n = s.entries.len();
            let p = &mut s.people[user];
            if p.count == 0 {
                p.first = n;
            }
            assert!(p.first + p.count == n, "snow-entries.json doesn't have each user's entries together");
            assert!(p.count == 0 || s.entries[n - 1].started < e.started_at, "a user's entries out of order");
            p.count += 1;
            if e.stopped_at.is_none() {
                p.running = Some(n);
            }
            s.entries.push(Entry {
                id: e.id,
                user,
                org,
                project,
                description: e.description,
                ticket: e.ticket,
                started: e.started_at,
                stopped: e.stopped_at,
            });
        }
        s.by_entry_id = (0..s.entries.len()).collect();
        s.by_entry_id.sort_by(|&a, &b| s.entries[a].id.cmp(&s.entries[b].id));
        if template {
            s.prebuild();
        }
        s
    }

    fn prebuild(&mut self) {
        let session_json = (0..self.people.len()).map(|u| serde_json::to_vec(&self.session_out(u)).unwrap()).collect();
        let timer_json = self.people.iter().map(|p| match p.running {
            Some(i) => serde_json::to_vec(&self.timer_out(i)).unwrap(),
            None => b"null".to_vec(),
        }).collect();
        let project_json = self.projects.iter().map(|p| serde_json::to_vec(p).unwrap()).collect();
        let entry_json = (0..self.entries.len()).map(|i| {
            let e = &self.entries[i];
            let json = serde_json::to_vec(&self.entry_out(i, &e.description, e.stopped)).unwrap();
            // A string's quotes are escaped, so these members' keys are the
            // first such bytes.
            let find = |at: usize, key: &[u8]| json[at..].windows(key.len()).position(|w| w == key).unwrap() + at;
            let desc = find(0, b",\"description\":") + 15;
            let tail = find(desc, b",\"ticket\":");
            EntryJson { json, desc, tail }
        }).collect();
        self.session_json = session_json;
        self.timer_json = timer_json;
        self.project_json = project_json;
        self.entry_json = entry_json;
    }

    fn org_index(&self, id: &str) -> Option<usize> {
        self.orgs.iter().position(|o| o.id == id)
    }

    fn project_index(&self, id: &[u8], org: usize) -> Option<usize> {
        let o = &self.orgs[org];
        (o.first..o.first + o.count).find(|&i| self.projects[i].id.as_bytes() == id)
    }

    fn person_index(&self, id: &[u8]) -> Option<usize> {
        self.by_person_id.binary_search_by(|&i| self.people[i].id.as_bytes().cmp(id)).ok().map(|k| self.by_person_id[k])
    }

    fn entry_index(&self, id: &[u8]) -> Option<usize> {
        self.by_entry_id.binary_search_by(|&i| self.entries[i].id.as_bytes().cmp(id)).ok().map(|k| self.by_entry_id[k])
    }

    fn session_out(&self, u: usize) -> SessionOut<'_, impl Serialize + '_> {
        let p = &self.people[u];
        SessionOut {
            user: UserOut { id: &p.id, name: &p.name, email: &p.email, image: &p.image },
            signed_in_at: p.signed_in,
            organizations: seq_of(&p.orgs, move |m| {
                let o = &self.orgs[m.org];
                OrgOut { id: &o.id, name: &o.name, slug: &o.slug, links: &o.links, role: &m.role }
            }),
            active_organization_id: &self.orgs[p.active].id,
            settings: &p.settings,
            fill: &p.fill,
            invitation_id: None,
            app_url: APP_URL,
        }
    }

    fn entry_out<'a>(&'a self, i: usize, description: &'a str, stopped: Option<i64>) -> EntryOut<'a> {
        let e = &self.entries[i];
        EntryOut {
            id: &e.id,
            organization_id: &self.orgs[e.org].id,
            user_id: &self.people[e.user].id,
            project_id: e.project.map(|j| self.projects[j].id.as_str()),
            description,
            ticket: e.ticket.as_deref(),
            started_at: e.started,
            stopped_at: stopped,
            project: None,
        }
    }

    // GET /timer's answer for a running entry: the entry and its project.
    fn timer_out(&self, i: usize) -> EntryOut<'_> {
        let e = &self.entries[i];
        let mut out = self.entry_out(i, &e.description, None);
        out.project = Some(e.project.map(|j| {
            let p = &self.projects[j];
            ProjectRef { id: &p.id, name: &p.name, color: &p.color }
        }));
        out
    }

    fn entry_into(&self, template: bool, out: &mut Vec<u8>, i: usize) {
        if template {
            out.extend_from_slice(&self.entry_json[i].json);
        } else {
            let e = &self.entries[i];
            serde_json::to_writer(&mut *out, &self.entry_out(i, &e.description, e.stopped)).unwrap();
        }
    }

    // Running entry i stopped at now, as stopRunning stops it: after it
    // started, and at most a day after.
    fn stopped_at(&self, i: usize, now: i64) -> i64 {
        let started = self.entries[i].started;
        now.max(started + 1).min(started + DAY)
    }

    fn stopped_into(&self, template: bool, out: &mut Vec<u8>, i: usize, now: i64) {
        let at = self.stopped_at(i, now);
        if template {
            // A running entry's JSON ends in "null}".
            let json = &self.entry_json[i].json;
            out.extend_from_slice(&json[..json.len() - 5]);
            push_iso(out, at);
            out.push(b'}');
        } else {
            serde_json::to_writer(&mut *out, &self.entry_out(i, &self.entries[i].description, Some(at))).unwrap();
        }
    }

    // listProjects's visibility: an admin sees every project, a member those
    // with no team and those of a team of theirs.
    fn sees(&self, p: &Person, m: &Member, j: &Project) -> bool {
        if is_admin(m) || j.team_ids.is_empty() {
            return true;
        }
        m.org == p.active && j.team_ids.iter().any(|t| p.teams.contains(t))
    }

    // GET .../entries: the entries of userId, or of the caller, that overlap
    // [from, to), newest first, as listEntries selects them.
    #[allow(clippy::too_many_arguments)]
    fn list_entries(&self, template: bool, from: Option<&str>, to: Option<&str>, user_id: Option<&str>, p: &Person,
                    m: &Member, mut buf: Vec<u8>) -> Reply {
        let from = from.and_then(|s| parse_iso(s.as_bytes()));
        let to = to.and_then(|s| parse_iso(s.as_bytes()));
        let (Some(from), Some(to)) = (from, to) else { return invalid() };
        if !(to > from && to - from <= 93 * DAY) {
            return invalid();
        }
        let mut who = self.person_index(p.id.as_bytes());
        if let Some(uid) = user_id.map(str::as_bytes) {
            if !is_uuid7(uid) {
                return invalid();
            }
            if uid != p.id.as_bytes() {
                if !is_admin(m) {
                    return coded(403, "FORBIDDEN", "entries_forbidden");
                }
                who = self.person_index(uid);
            }
        }
        let mut listed = Vec::new();
        if let Some(w) = who.filter(|&w| self.people[w].active == m.org) {
            let u = &self.people[w];
            let mine = &self.entries[u.first..u.first + u.count];
            let mut i = mine.partition_point(|e| e.started < to);
            while i > 0 && mine[i - 1].started > from - DAY {
                i -= 1;
                if mine[i].stopped.map_or(true, |s| s > from) {
                    listed.push(u.first + i);
                }
            }
        }
        if template {
            join(&mut buf, b"[", listed.iter().map(|&i| &self.entry_json[i].json[..]), b"]");
        } else {
            let out = seq_of(&listed, |&i| {
                let e = &self.entries[i];
                self.entry_out(i, &e.description, e.stopped)
            });
            serde_json::to_writer(&mut buf, &out).unwrap();
        }
        json(buf)
    }

    fn list_projects(&self, template: bool, v: Option<&str>, p: &Person, m: &Member, mut buf: Vec<u8>) -> Reply {
        if !matches!(v, None | Some("true") | Some("false")) {
            return invalid();
        }
        let archived = v == Some("true");
        let o = &self.orgs[m.org];
        let listed: Vec<usize> = (o.first..o.first + o.count)
            .filter(|&i| {
                let j = &self.projects[i];
                (archived || j.archived.is_none()) && self.sees(p, m, j)
            })
            .collect();
        if template {
            join(&mut buf, b"[", listed.iter().map(|&i| &self.project_json[i][..]), b"]");
        } else {
            serde_json::to_writer(&mut buf, &seq_of(&listed, |&i| &self.projects[i])).unwrap();
        }
        json(buf)
    }

    fn patch_entry(&self, template: bool, id: &[u8], body: &[u8], p: &Person, m: &Member, mut buf: Vec<u8>) -> Reply {
        if !is_uuid7(id) {
            return invalid();
        }
        if !is_json(body) {
            return not_json();
        }
        let Some(patch) = is_object(body).then(|| serde_json::from_slice::<PatchBody>(body).ok()).flatten() else {
            return invalid();
        };
        let description = patch.description.as_deref().map(trim);
        if description.is_some_and(|d| d.len() > 500) {
            return invalid();
        }
        let Some(i) = self.entry_index(id).filter(|&i| self.entries[i].org == m.org) else {
            return coded(404, "NOT_FOUND", "entry_not_found");
        };
        let e = &self.entries[i];
        if self.people[e.user].id != p.id && !is_admin(m) {
            return coded(403, "FORBIDDEN", "entry_forbidden");
        }
        match description {
            None => self.entry_into(template, &mut buf, i),
            Some(d) if template => {
                let t = &self.entry_json[i];
                buf.extend_from_slice(&t.json[..t.desc]);
                serde_json::to_writer(&mut buf, d).unwrap();
                buf.extend_from_slice(&t.json[t.tail..]);
            }
            Some(d) => serde_json::to_writer(&mut buf, &self.entry_out(i, d, e.stopped)).unwrap(),
        }
        json(buf)
    }

    // POST .../timer/start: the new entry, started now, and the timer it
    // stopped, the caller's running one, or null.
    fn start_timer(&self, template: bool, body: &[u8], u: usize, m: &Member, mut buf: Vec<u8>) -> Reply {
        if !is_json(body) {
            return not_json();
        }
        let Some(start) = is_object(body).then(|| serde_json::from_slice::<StartBody>(body).ok()).flatten() else {
            return invalid();
        };
        let description = start.description.as_deref().map_or("", trim);
        let ok = description.len() <= 500
            && start.id.as_deref().is_some_and(|id| is_uuid7(id.as_bytes()))
            && start.ticket.as_deref().map_or(true, |t| t.len() <= 18 && is_ticket(t))
            && start.project_id.as_deref().map_or(true, |j| is_uuid7(j.as_bytes()));
        if !ok {
            return invalid();
        }
        let id = start.id.as_deref().unwrap();
        let p = &self.people[u];
        if let Some(project) = &start.project_id {
            let j = self.project_index(project.as_bytes(), m.org).filter(|&j| self.sees(p, m, &self.projects[j]));
            let Some(j) = j else { return coded(404, "NOT_FOUND", "project_not_found") };
            if self.projects[j].archived.is_some() {
                return coded(409, "CONFLICT", "project_archived");
            }
        }
        if self.entry_index(id.as_bytes()).is_some() {
            return coded(409, "CONFLICT", "entry_id_taken");
        }
        let now = now_ms();
        let started = EntryOut {
            id,
            organization_id: &self.orgs[m.org].id,
            user_id: &p.id,
            project_id: start.project_id.as_deref(),
            description,
            ticket: start.ticket.as_deref(),
            started_at: now,
            stopped_at: None,
            project: None,
        };
        if template {
            buf.extend_from_slice(b"{\"started\":");
            serde_json::to_writer(&mut buf, &started).unwrap();
            buf.extend_from_slice(b",\"stopped\":");
            match p.running {
                Some(i) => self.stopped_into(true, &mut buf, i, now),
                None => buf.extend_from_slice(b"null"),
            }
            buf.push(b'}');
        } else {
            let stopped = p.running.map(|i| self.entry_out(i, &self.entries[i].description, Some(self.stopped_at(i, now))));
            serde_json::to_writer(&mut buf, &StartOut { started, stopped }).unwrap();
        }
        json(buf)
    }

    // POST /timer/stop: the caller's running entry, stopped now. An id the
    // dataset doesn't have is taken for a timer started with it, as timer start
    // answered it: a uuidv7 made in the last day.
    fn stop_timer(&self, template: bool, body: &[u8], u: usize, mut buf: Vec<u8>) -> Reply {
        if !is_json(body) {
            return not_json();
        }
        let stop = is_object(body).then(|| serde_json::from_slice::<StopBody>(body).ok()).flatten();
        let Some(id) = stop.and_then(|s| s.id).filter(|id| is_uuid7(id.as_bytes())) else { return invalid() };
        let p = &self.people[u];
        let now = now_ms();
        match p.running {
            Some(i) if self.entries[i].id == id => self.stopped_into(template, &mut buf, i, now),
            _ => {
                let started = uuid_ms(id.as_bytes());
                if !(started > now - DAY && started <= now + MINUTE && self.entry_index(id.as_bytes()).is_none()) {
                    return coded(404, "NOT_FOUND", "timer_not_running");
                }
                let out = EntryOut {
                    id: &id,
                    organization_id: &self.orgs[p.active].id,
                    user_id: &p.id,
                    project_id: None,
                    description: "",
                    ticket: None,
                    started_at: started,
                    stopped_at: Some(now.max(started + 1).min(started + DAY)),
                    project: None,
                };
                serde_json::to_writer(&mut buf, &out).unwrap();
            }
        }
        json(buf)
    }
}
