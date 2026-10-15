// goose-http's REST benchmark tiers apart from any framework,
// for the framework servers beside it: goose-http's bench/rest/rust routes and
// answers, byte for byte, without their routing. A server routes each request
// on its framework's router, takes the path parameters, query, headers,
// cookies, and body with the framework's extractors, and calls the route's
// function here, which answers a Reply:
//
//   arena    tier A, HttpArena's production-stack application layer
//   snow     tier B, snowtime's k6 hot path, under /api/v1
//   heavy    tier C, a clinic's schedule and records, under /api/v2
//   writes   tier D, writes with large bodies, under /api/v3, served beside C
//
// Tiers F, R, and M (bench/rest/tiers) are framework tiers, whose handlers
// are each server's own; this crate gives R its routes and M tier A's.
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       <server> [port]
//
// TIER picks the dataset to load, tier A's by default. JSON=template answers
// from each record's JSON, written once at startup, with the per-request
// values added; the default serializes each response with serde_json. Tier
// D's answers are written the one way.

pub mod arena;
pub mod heavy;
pub mod snow;
pub mod writes;

use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Deserializer, Serialize, Serializer};

// A response: its status, whether its body is JSON, and whether the server
// closes the connection after it, rather than read the rest of a body.
pub struct Reply {
    pub status: u16,
    pub json: bool,
    pub close: bool,
    pub body: Vec<u8>,
}

impl Reply {
    pub fn empty(status: u16) -> Reply {
        Reply { status, json: false, close: false, body: Vec::new() }
    }

    fn json(status: u16, body: impl Into<Vec<u8>>) -> Reply {
        Reply { status, json: true, close: false, body: body.into() }
    }
}

fn json(body: Vec<u8>) -> Reply {
    Reply::json(200, body)
}

// goose-http's tiers A to D, and goose-rest's own (bench/rest/tiers): F, a
// framework micro tier; R, the GitHub API's routes; and M, tier A behind a
// middleware stack.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Tier {
    A,
    B,
    C,
    D,
    F,
    R,
    M,
}

struct Data {
    arena: arena::Arena,
    snow: snow::Snow,
    heavy: heavy::Heavy,
    template: bool,
}

static DATA: OnceLock<Data> = OnceLock::new();

const DAY: i64 = 86_400_000;
const MINUTE: i64 = 60_000;

// The tier, the worker count, and the port, from TIER, WORKERS, and the first
// argument.
pub struct Config {
    pub tier: Tier,
    pub workers: usize,
    pub port: u16,
}

// Loads TIER's dataset from REST_DATA, and says so as server.
pub fn init(server: &str) -> Config {
    let dir = std::env::var("REST_DATA").unwrap_or_else(|_| "build/rest".into());
    let name = std::env::var("TIER").unwrap_or_else(|_| "a".into());
    let tier = match name.as_str() {
        "a" => Tier::A,
        "b" => Tier::B,
        "c" => Tier::C,
        "d" => Tier::D,
        "f" => Tier::F,
        "r" => Tier::R,
        "m" => Tier::M,
        _ => panic!("TIER is a, b, c, d, f, r, or m"),
    };
    let template = std::env::var("JSON").as_deref() == Ok("template");
    let data = DATA.get_or_init(|| load(&dir, tier, template));
    let workers = std::env::var("WORKERS").ok().and_then(|v| v.parse().ok())
        .unwrap_or_else(|| std::thread::available_parallelism().map_or(1, |n| n.get()));
    let port: u16 = std::env::args().nth(1).and_then(|p| p.parse().ok()).unwrap_or(8080);
    let records = data.arena.records() + data.snow.records() + data.heavy.records();
    println!("{server}: tier {name}, {records} records, {workers} workers on port {port}, {}",
             if data.template { "template" } else { "serialize" });
    Config { tier, workers, port }
}

fn data() -> &'static Data {
    DATA.get().expect("rest_app::init first")
}

fn load(dir: &str, tier: Tier, template: bool) -> Data {
    let mut data = Data {
        arena: arena::Arena::default(),
        snow: snow::Snow::default(),
        heavy: heavy::Heavy::default(),
        template,
    };
    match tier {
        Tier::A | Tier::M => data.arena = arena::Arena::load(dir, template),
        Tier::B => data.snow = snow::Snow::load(dir, template),
        Tier::C | Tier::D => data.heavy = heavy::Heavy::load(dir, template),
        Tier::F | Tier::R => {}
    }
    data
}

// Tier R's routes: each line of ROUTES (bench/rest/tiers/github.txt by
// default), "METHOD /path/:param", as its method and its path with each
// ":param" written "{param}", as axum's and actix-web's routers take them.
pub fn github_routes() -> Vec<(String, String)> {
    let file = std::env::var("ROUTES").unwrap_or_else(|_| "bench/rest/tiers/github.txt".into());
    let text = std::fs::read_to_string(&file).unwrap_or_else(|e| panic!("{file}: {e}"));
    text.lines().filter(|l| !l.is_empty()).map(|line| {
        let (method, pattern) = line.split_once(' ').unwrap_or_else(|| panic!("{file}: {line}"));
        let path = pattern.split('/').map(|seg| match seg.strip_prefix(':') {
            Some(name) => format!("{{{name}}}"),
            None => seg.to_string(),
        }).collect::<Vec<_>>().join("/");
        (method.to_string(), path)
    }).collect()
}

// Tier R's answer for route n: n, then its parameters' values, by spaces.
pub fn numbered<'a>(n: usize, values: impl IntoIterator<Item = &'a str>) -> String {
    let mut out = n.to_string();
    for v in values {
        out.push(' ');
        out.push_str(v);
    }
    out
}

// Whether an Authorization value is a bearer token, as tier M requires; the
// token isn't verified.
pub fn is_bearer(authorization: Option<&[u8]>) -> bool {
    authorization.and_then(|v| v.strip_prefix(b"Bearer ")).is_some_and(|t| !t.is_empty())
}

// Tier M's CORS origin.
pub const CORS_ORIGIN: &str = "https://app.example";

// The time in seconds, which a coarse clock gives as cheaply.
fn now_s() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs())
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_millis() as i64)
}

fn read_file(dir: &str, name: &str) -> Vec<u8> {
    std::fs::read(format!("{dir}/{name}"))
        .unwrap_or_else(|e| panic!("{dir}/{name}: {e}; run goose-http's bench/rest/gen.goose"))
}

// id as a record's index, if it's one of n.
fn index_of(id: usize, n: usize) -> Option<usize> {
    (id >= 1 && id <= n).then(|| id - 1)
}

fn is_base64url(s: &[u8]) -> bool {
    !s.is_empty() && s.iter().all(|&c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_')
}

// Whether an Authorization value is a bearer token of three base64url
// segments, as tiers C and D require; the token isn't verified.
pub fn has_bearer(authorization: Option<&[u8]>) -> bool {
    let Some(t) = authorization.and_then(|v| v.strip_prefix(b"Bearer ")) else {
        return false;
    };
    let mut parts = t.splitn(3, |&c| c == b'.');
    let (Some(a), Some(b), Some(c)) = (parts.next(), parts.next(), parts.next()) else { return false };
    is_base64url(a) && is_base64url(b) && is_base64url(c)
}

// A form's key or value decoded: '+' as a space, and percent-escapes, or None
// for a '%' without two hex digits after it.
fn decode_form(s: &[u8]) -> Option<Vec<u8>> {
    let hex = |c: u8| (c as char).to_digit(16);
    let mut out = Vec::with_capacity(s.len());
    let mut i = 0;
    while i < s.len() {
        match s[i] {
            b'%' => {
                let (Some(a), Some(b)) = (s.get(i + 1).and_then(|&c| hex(c)), s.get(i + 2).and_then(|&c| hex(c)))
                else {
                    return None;
                };
                out.push((a * 16 + b) as u8);
                i += 3;
            }
            c => {
                out.push(if c == b'+' { b' ' } else { c });
                i += 1;
            }
        }
    }
    Some(out)
}

fn parse_int(s: &[u8]) -> Option<i64> {
    std::str::from_utf8(s).ok()?.parse().ok()
}

// Whether body's JSON value, if any, is an object, which a struct's
// Deserialize would otherwise take from an array too.
fn is_object(body: &[u8]) -> bool {
    body.trim_ascii_start().first() == Some(&b'{')
}

fn is_json(body: &[u8]) -> bool {
    serde_json::from_slice::<serde::de::IgnoredAny>(body).is_ok()
}

// A present member that must be a string: null is refused, where an Option
// would take it for absent.
fn de_string<'de, D: Deserializer<'de>>(d: D) -> Result<Option<String>, D::Error> {
    String::deserialize(d).map(Some)
}

// ms since the epoch as JavaScript's toISOString writes it, from Howard
// Hinnant's civil_from_days.
struct Iso([u8; 24]);

impl Iso {
    fn new(ms: i64) -> Iso {
        fn digits(b: &mut [u8], v: i64) {
            let mut v = v;
            for c in b.iter_mut().rev() {
                *c = b'0' + (v % 10) as u8;
                v /= 10;
            }
        }
        let day = ms.div_euclid(DAY);
        let t = ms.rem_euclid(DAY);
        let z = day + 719_468;
        let era = (if z >= 0 { z } else { z - 146_096 }) / 146_097;
        let doe = z - era * 146_097;
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        let mp = (5 * doy + 2) / 153;
        let m = if mp < 10 { mp + 3 } else { mp - 9 };
        let mut b = *b"0000-00-00T00:00:00.000Z";
        digits(&mut b[0..4], yoe + era * 400 + i64::from(m <= 2));
        digits(&mut b[5..7], m);
        digits(&mut b[8..10], doy - (153 * mp + 2) / 5 + 1);
        digits(&mut b[11..13], t / 3_600_000);
        digits(&mut b[14..16], t / MINUTE % 60);
        digits(&mut b[17..19], t / 1000 % 60);
        digits(&mut b[20..23], t % 1000);
        Iso(b)
    }

    fn as_str(&self) -> &str {
        std::str::from_utf8(&self.0).unwrap()
    }
}

fn iso<S: Serializer>(ms: &i64, s: S) -> Result<S::Ok, S::Error> {
    s.serialize_str(Iso::new(*ms).as_str())
}

fn iso_or_null<S: Serializer>(ms: &Option<i64>, s: S) -> Result<S::Ok, S::Error> {
    match ms {
        Some(v) => iso(v, s),
        None => s.serialize_none(),
    }
}

// A time as a JSON string, for a template's splice.
fn push_iso(out: &mut Vec<u8>, ms: i64) {
    out.push(b'"');
    out.extend_from_slice(&Iso::new(ms).0);
    out.push(b'"');
}

fn number_at(s: &[u8], at: usize, n: usize) -> i64 {
    let mut v = 0;
    for &c in &s[at..at + n] {
        if !c.is_ascii_digit() {
            return -1;
        }
        v = v * 10 + i64::from(c - b'0');
    }
    v
}

// Howard Hinnant's days_from_civil.
fn days_from(y: i64, m: i64, d: i64) -> i64 {
    let yy = if m <= 2 { y - 1 } else { y };
    let era = (if yy >= 0 { yy } else { yy - 399 }) / 400;
    let yoe = yy - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
}

// "YYYY-MM-DDTHH:MM:SS.sssZ", or without the milliseconds, as ms since the
// epoch.
fn parse_iso(s: &[u8]) -> Option<i64> {
    let n = s.len();
    if !((n == 24 || n == 20) && s[4] == b'-' && s[7] == b'-' && s[10] == b'T' && s[13] == b':' && s[16] == b':'
        && s[n - 1] == b'Z')
    {
        return None;
    }
    let (y, m, d) = (number_at(s, 0, 4), number_at(s, 5, 2), number_at(s, 8, 2));
    let (h, mi, sec) = (number_at(s, 11, 2), number_at(s, 14, 2), number_at(s, 17, 2));
    let ms = if n == 24 && s[19] == b'.' { number_at(s, 20, 3) } else if n == 20 { 0 } else { -1 };
    let ok = y >= 0 && (1..=12).contains(&m) && (1..=31).contains(&d) && (0..24).contains(&h)
        && (0..60).contains(&mi) && (0..60).contains(&sec) && ms >= 0;
    ok.then(|| days_from(y, m, d) * DAY + ((h * 60 + mi) * 60 + sec) * 1000 + ms)
}

// "YYYY-MM-DD" as ms since the epoch at its midnight in UTC.
fn parse_day(s: &[u8]) -> Option<i64> {
    if !(s.len() == 10 && s[4] == b'-' && s[7] == b'-') {
        return None;
    }
    let (y, m, d) = (number_at(s, 0, 4), number_at(s, 5, 2), number_at(s, 8, 2));
    (y >= 0 && (1..=12).contains(&m) && (1..=31).contains(&d)).then(|| days_from(y, m, d) * DAY)
}

fn de_iso<'de, D: Deserializer<'de>>(d: D) -> Result<i64, D::Error> {
    parse_iso(String::deserialize(d)?.as_bytes()).ok_or_else(|| serde::de::Error::custom("a time that isn't toISOString's"))
}

fn de_iso_or_null<'de, D: Deserializer<'de>>(d: D) -> Result<Option<i64>, D::Error> {
    match Option::<String>::deserialize(d)? {
        None => Ok(None),
        Some(s) => parse_iso(s.as_bytes()).map(Some)
            .ok_or_else(|| serde::de::Error::custom("a time that isn't toISOString's")),
    }
}

// A JSON array of what F makes of each of a slice's elements, serialized
// without collecting them first.
struct SeqOf<'a, T, F>(&'a [T], F);

// The bound gives the closure its signature, so that what it makes may borrow
// the element.
fn seq_of<'a, T, F, O>(items: &'a [T], f: F) -> SeqOf<'a, T, F>
where
    F: Fn(&'a T) -> O,
    O: Serialize,
{
    SeqOf(items, f)
}

impl<'a, T, F, O> Serialize for SeqOf<'a, T, F>
where
    F: Fn(&'a T) -> O,
    O: Serialize,
{
    fn serialize<S: Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.collect_seq(self.0.iter().map(&self.1))
    }
}

// Prebuilt records joined with ',' between "[" and "]", or other ends.
fn join<'a>(out: &mut Vec<u8>, open: &[u8], parts: impl Iterator<Item = &'a [u8]>, close: &[u8]) {
    out.extend_from_slice(open);
    for (k, p) in parts.enumerate() {
        if k > 0 {
            out.push(b',');
        }
        out.extend_from_slice(p);
    }
    out.extend_from_slice(close);
}
