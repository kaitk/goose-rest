// Tier D, writes with large bodies, under /api/v3, behind tier C's token,
// answered from the body alone as goose-http's bench/rest/hyper answers them:
//
//   POST  /api/v3/imports                        a CSV: its rows, and each column's count and sum
//   POST  /api/v3/attachments                    multipart: the fields, the file's size and Adler-32
//   POST  /api/v3/bookings/batch                 JSON: each booking's id, or 422 with the errors
//   POST  /api/v3/forms                          a form: its fields, decoded
//
// A server answers an unknown path or method with heavy::not_found, a
// request without a bearer token with heavy::unauthorized, one of another
// media type than the route's (has_type) with unsupported_media_type, and a
// body over the route's limit, declared or read, with too_large. The CSV is
// read by a port of Goose's reader as the server's body arrives (Csv), the
// multipart body by the server's framework's multipart parser feeding an
// Attachment, and the batch and the form whole.

use std::borrow::Cow;

use serde::Deserialize;
use serde_json::value::RawValue;

use crate::{decode_form, parse_iso, Reply, MINUTE};

pub use crate::heavy::{bad_request, not_found, unauthorized};

pub const IMPORT_LIMIT: usize = 16 << 20;
pub const ATTACHMENT_LIMIT: usize = 16 << 20;
pub const BATCH_LIMIT: usize = 1 << 20;
pub const FORM_LIMIT: usize = 64 << 10;
const MAX_TEXT: usize = 1024;
const MAX_TEXTS: usize = 8;

// Each route's media type.
pub const CSV: &str = "text/csv";
pub const MULTIPART: &str = "multipart/form-data";
pub const JSON: &str = "application/json";
pub const FORM: &str = "application/x-www-form-urlencoded";

pub fn unsupported_media_type() -> Reply {
    Reply::json(415, "{\"error\":\"unsupported_media_type\",\"status\":415}")
}

// 413, closing the connection rather than reading the rest.
pub fn too_large() -> Reply {
    Reply { status: 413, json: false, close: true, body: Vec::new() }
}

// Whether a Content-Type's media type is want, ignoring case and parameters.
pub fn has_type(content_type: Option<&[u8]>, want: &str) -> bool {
    content_type.and_then(|v| std::str::from_utf8(v).ok())
        .is_some_and(|v| v.split(';').next().unwrap_or("").trim().eq_ignore_ascii_case(want))
}

// Whether a declared Content-Length is over limit.
pub fn declared_over(content_length: Option<&[u8]>, limit: usize) -> bool {
    content_length.and_then(|v| std::str::from_utf8(v).ok()?.parse::<usize>().ok()).is_some_and(|n| n > limit)
}

// POST /api/v3/imports: a CSV read as it arrives, within IMPORT_LIMIT.
pub struct Import {
    csv: Csv,
    taken: usize,
}

impl Default for Import {
    fn default() -> Import {
        Import { csv: Csv::new(), taken: 0 }
    }
}

impl Import {
    // Takes the body's next piece, or answers 413 past the limit.
    pub fn push(&mut self, data: &[u8]) -> Result<(), Reply> {
        self.taken += data.len();
        if self.taken > IMPORT_LIMIT {
            return Err(too_large());
        }
        self.csv.piece(data);
        Ok(())
    }

    // The answer at the body's end.
    pub fn finish(self) -> Reply {
        import(self.csv)
    }
}

// An import's columns, of three kinds.
#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Text,
    Int,
    Dec,
}

const COLUMNS: [(&str, Kind); 6] = [("id", Kind::Int), ("date", Kind::Text), ("account", Kind::Text),
                                    ("description", Kind::Text), ("quantity", Kind::Int), ("amount", Kind::Dec)];

#[derive(PartialEq)]
enum Quote {
    Outside,
    Inside,
    After,
}

// A CSV body (RFC 4180, with LF or CRLF line ends) read piece by piece, as
// rest.goose's Csv: where the reader is, the field it's in, and each column's
// count of non-empty cells and its sum, or its bytes for text.
struct Csv {
    record: i64,
    column: usize,
    quote: Quote,
    closed: bool,
    cr: bool,
    len: usize,
    value: i64,
    neg: bool,
    digits: i64,
    point: i64,
    number: bool,
    header: Vec<u8>,
    counts: [i64; 6],
    sums: [i64; 6],
    bad: i64,
}

impl Csv {
    fn new() -> Csv {
        Csv { record: 1, column: 0, quote: Quote::Outside, closed: false, cr: false, len: 0, value: 0, neg: false,
              digits: 0, point: -1, number: true, header: Vec::new(), counts: [0; 6], sums: [0; 6], bad: 0 }
    }

    fn fail(&mut self) {
        if self.bad == 0 {
            self.bad = self.record;
        }
    }

    fn text(&mut self, s: &[u8]) {
        let before = self.len;
        self.len += s.len();
        if self.record == 1 {
            if self.header.len() + s.len() <= 16 {
                self.header.extend_from_slice(s);
            }
            return;
        }
        let Some(&(_, kind)) = COLUMNS.get(self.column) else { return };
        if kind == Kind::Text {
            return;
        }
        for (i, &ch) in s.iter().enumerate() {
            if ch.is_ascii_digit() {
                if self.digits < 18 {
                    self.value = self.value * 10 + i64::from(ch - b'0');
                } else {
                    self.number = false;
                }
                self.digits += 1;
                if self.point >= 0 {
                    self.point += 1;
                }
            } else if ch == b'-' && before + i == 0 {
                self.neg = true;
            } else if ch == b'.' && kind == Kind::Dec && self.point < 0 && self.digits > 0 {
                self.point = 0;
            } else {
                self.number = false;
            }
        }
    }

    fn field_end(&mut self) {
        let k = self.column;
        if k >= COLUMNS.len() {
            self.fail();
        } else if self.record == 1 {
            if self.len > 16 || self.header != COLUMNS[k].0.as_bytes() {
                self.fail();
            }
        } else if self.len > 0 {
            let kind = COLUMNS[k].1;
            if kind == Kind::Text {
                self.counts[k] += 1;
                self.sums[k] += self.len as i64;
            } else if self.number && self.digits > 0 && (if kind == Kind::Dec { self.point == 2 } else { self.point < 0 }) {
                self.counts[k] += 1;
                self.sums[k] += if self.neg { -self.value } else { self.value };
            } else {
                self.fail();
            }
        }
        self.column += 1;
        self.len = 0;
        self.value = 0;
        self.neg = false;
        self.digits = 0;
        self.point = -1;
        self.number = true;
        self.closed = false;
        self.header.clear();
    }

    fn record_end(&mut self) {
        self.field_end();
        if self.column != COLUMNS.len() {
            self.fail();
        }
        self.record += 1;
        self.column = 0;
    }

    fn piece(&mut self, p: &[u8]) {
        let mut i = 0;
        while i < p.len() && self.bad == 0 {
            let ch = p[i];
            if self.quote == Quote::Inside {
                let Some(q) = memchr(b'"', &p[i..]) else {
                    self.text(&p[i..]);
                    return;
                };
                self.text(&p[i..i + q]);
                self.quote = Quote::After;
                i += q + 1;
                continue;
            }
            if self.quote == Quote::After {
                self.quote = Quote::Outside;
                if ch == b'"' {
                    self.text(&p[i..i + 1]);
                    self.quote = Quote::Inside;
                    i += 1;
                    continue;
                }
                self.closed = true;
            }
            if self.cr {
                self.cr = false;
                if ch != b'\n' {
                    self.fail();
                    return;
                }
            }
            if ch == b',' {
                self.field_end();
                i += 1;
            } else if ch == b'\n' {
                self.record_end();
                i += 1;
            } else if ch == b'\r' {
                self.cr = true;
                i += 1;
            } else if self.closed || ch == b'"' && self.len > 0 {
                self.fail();
            } else if ch == b'"' {
                self.quote = Quote::Inside;
                i += 1;
            } else {
                let j = p[i + 1..].iter().position(|&c| c == b',' || c == b'\n' || c == b'\r' || c == b'"')
                    .map_or(p.len(), |k| i + 1 + k);
                self.text(&p[i..j]);
                i = j;
            }
        }
    }

    fn end(&mut self) {
        if self.bad != 0 {
            return;
        }
        if self.quote == Quote::Inside || self.cr {
            self.fail();
            return;
        }
        if self.quote == Quote::After || self.closed || self.column > 0 || self.len > 0 {
            self.record_end();
        }
        if self.record == 1 {
            self.fail();
        }
    }
}

fn memchr(c: u8, s: &[u8]) -> Option<usize> {
    s.iter().position(|&b| b == c)
}

fn push_cents(out: &mut Vec<u8>, v: i64) {
    let a = v.unsigned_abs();
    out.extend_from_slice(format!("{}{}.{:02}", if v < 0 { "-" } else { "" }, a / 100, a % 100).as_bytes());
}

fn import(mut c: Csv) -> Reply {
    c.end();
    if c.bad != 0 {
        return Reply::json(400, format!("{{\"error\":\"bad_csv\",\"record\":{}}}", c.bad));
    }
    let mut buf = format!("{{\"rows\":{},\"columns\":[", c.record - 2).into_bytes();
    for (k, &(name, kind)) in COLUMNS.iter().enumerate() {
        if k > 0 {
            buf.push(b',');
        }
        buf.extend_from_slice(format!("{{\"name\":\"{name}\",\"count\":{}", c.counts[k]).as_bytes());
        match kind {
            Kind::Text => buf.extend_from_slice(format!(",\"bytes\":{}", c.sums[k]).as_bytes()),
            Kind::Int => buf.extend_from_slice(format!(",\"sum\":{}", c.sums[k]).as_bytes()),
            Kind::Dec => {
                buf.extend_from_slice(b",\"sum\":");
                push_cents(&mut buf, c.sums[k]);
            }
        }
        buf.push(b'}');
    }
    buf.extend_from_slice(b"]}");
    Reply::json(201, buf)
}

// Adler-32 (RFC 1950), deferring the modulo as zlib does.
fn adler(a: &mut u32, b: &mut u32, data: &[u8]) {
    for block in data.chunks(5552) {
        for &c in block {
            *a += u32::from(c);
            *b += *a;
        }
        *a %= 65521;
        *b %= 65521;
    }
}

fn push_string(out: &mut Vec<u8>, s: &str) {
    serde_json::to_writer(&mut *out, s).unwrap();
}

// The file part's name, filename, media type, size, and Adler-32 so far.
struct File {
    field: String,
    filename: String,
    content_type: String,
    size: usize,
    a: u32,
    b: u32,
}

// POST /api/v3/attachments: a multipart body of text fields and one file,
// as a server's multipart parser hands over its parts. Each part is begun
// with its head's values, then takes its content in pieces. Any Err answers
// the request; a parser's own error is the server's to answer, with
// bad_request, or too_large past ATTACHMENT_LIMIT.
#[derive(Default)]
pub struct Attachment {
    fields: Vec<u8>,
    texts: usize,
    file: Option<File>,
    text: Option<(String, Vec<u8>)>, // the text part being read
    in_file: bool,
}

impl Attachment {
    // A part of the field name, and the filename and media type its head
    // gives: a file part if it has a filename that isn't empty.
    pub fn begin(&mut self, name: Option<&str>, filename: Option<&str>, content_type: Option<&str>)
                 -> Result<(), Reply> {
        self.end_part();
        let name = name.unwrap_or("");
        if name.is_empty() || name.len() > 64 {
            return Err(bad_request());
        }
        match filename.filter(|f| !f.is_empty()) {
            Some(filename) => {
                let ctype = content_type.unwrap_or("application/octet-stream");
                if self.file.is_some() || filename.len() > 256 || ctype.len() > 128 {
                    return Err(bad_request());
                }
                self.file = Some(File { field: name.into(), filename: filename.into(), content_type: ctype.into(),
                                        size: 0, a: 1, b: 0 });
                self.in_file = true;
            }
            None => {
                if self.texts == MAX_TEXTS {
                    return Err(bad_request());
                }
                self.text = Some((name.into(), Vec::new()));
            }
        }
        Ok(())
    }

    // The current part's next piece of content.
    pub fn push(&mut self, data: &[u8]) -> Result<(), Reply> {
        if self.in_file {
            let f = self.file.as_mut().unwrap();
            f.size += data.len();
            adler(&mut f.a, &mut f.b, data);
        } else if let Some((_, value)) = &mut self.text {
            if value.len() + data.len() > MAX_TEXT {
                return Err(bad_request());
            }
            value.extend_from_slice(data);
        }
        Ok(())
    }

    fn end_part(&mut self) {
        self.in_file = false;
        let Some((name, value)) = self.text.take() else { return };
        if self.texts > 0 {
            self.fields.push(b',');
        }
        push_string(&mut self.fields, &name);
        self.fields.push(b':');
        push_string(&mut self.fields, &String::from_utf8_lossy(&value));
        self.texts += 1;
    }

    // The answer after the close delimiter.
    pub fn finish(mut self) -> Reply {
        self.end_part();
        let Some(f) = self.file else {
            return Reply::json(422,
                               "{\"error\":\"invalid\",\"errors\":[{\"field\":\"file\",\"message\":\"is required\"}]}");
        };
        let mut buf = b"{\"fields\":{".to_vec();
        buf.extend_from_slice(&self.fields);
        buf.extend_from_slice(b"},\"file\":{\"field\":");
        push_string(&mut buf, &f.field);
        buf.extend_from_slice(b",\"filename\":");
        push_string(&mut buf, &f.filename);
        buf.extend_from_slice(b",\"contentType\":");
        push_string(&mut buf, &f.content_type);
        buf.extend_from_slice(format!(",\"size\":{},\"adler32\":{}}}}}", f.size, (f.b << 16) | f.a).as_bytes());
        Reply::json(201, buf)
    }
}

#[derive(Deserialize)]
struct Batch<'a> {
    #[serde(borrow, rename = "batchId")]
    batch_id: Option<&'a RawValue>,
    #[serde(borrow)]
    bookings: Option<&'a RawValue>,
}

// A booking's members, each kept as its JSON text and checked by hand, so
// that each wrong one is a field error rather than a failed parse.
#[derive(Deserialize)]
struct BookingIn<'a> {
    #[serde(borrow, rename = "clientId")]
    client: Option<&'a RawValue>,
    #[serde(borrow, rename = "staffId")]
    staff: Option<&'a RawValue>,
    #[serde(borrow)]
    service: Option<&'a RawValue>,
    #[serde(borrow)]
    start: Option<&'a RawValue>,
    #[serde(borrow)]
    end: Option<&'a RawValue>,
    #[serde(borrow)]
    room: Option<&'a RawValue>,
    #[serde(borrow)]
    note: Option<&'a RawValue>,
}

// How a booking's member read: absent, wrong, or fine.
#[derive(PartialEq, Clone, Copy)]
enum How {
    Absent,
    Wrong,
    Fine,
}

// An integer from lo to hi: a JSON number with no fraction.
fn int_member(v: Option<&RawValue>, lo: f64, hi: f64) -> How {
    let Some(v) = v else { return How::Absent };
    let t = v.get();
    if !t.starts_with(|c: char| c == '-' || c.is_ascii_digit()) {
        return How::Wrong;
    }
    match t.parse::<f64>() {
        Ok(n) if n >= lo && n <= hi && n == n.trunc() => How::Fine,
        _ => How::Wrong,
    }
}

fn string_member(v: &RawValue) -> Option<Cow<'_, str>> {
    if !v.get().starts_with('"') {
        return None;
    }
    serde_json::from_str::<Cow<str>>(v.get()).ok()
}

fn is_service(s: &str) -> bool {
    let b = s.as_bytes();
    let Some(d) = memchr(b'-', b) else { return false };
    (2..=4).contains(&d) && b.len() == d + 3 && b[..d].iter().all(u8::is_ascii_uppercase)
        && b[d + 1].is_ascii_digit() && b[d + 2].is_ascii_digit()
}

fn time_member(v: Option<&RawValue>) -> (How, i64) {
    let Some(v) = v else { return (How::Absent, 0) };
    match string_member(v).and_then(|s| parse_iso(s.as_bytes())) {
        Some(t) => (How::Fine, t),
        None => (How::Wrong, 0),
    }
}

fn booking_error(errors: &mut Vec<u8>, k: usize, field: &str, message: &str) {
    if !errors.is_empty() {
        errors.push(b',');
    }
    errors.extend_from_slice(format!("{{\"index\":{k},\"field\":\"{field}\",\"message\":\"{message}\"}}").as_bytes());
}

fn check_field(errors: &mut Vec<u8>, k: usize, how: How, field: &str, message: &str) {
    match how {
        How::Absent => booking_error(errors, k, field, "is required"),
        How::Wrong => booking_error(errors, k, field, message),
        How::Fine => {}
    }
}

// POST /bookings/batch: each booking's id, the batch's id and its number,
// and their minutes, or 422 with each field that doesn't validate.
pub fn batch(body: &[u8]) -> Reply {
    let bad = bad_request;
    if body.trim_ascii_start().first() != Some(&b'{') {
        return bad();
    }
    let Ok(b) = serde_json::from_slice::<Batch>(body) else { return bad() };
    let Some(id) = b.batch_id.and_then(string_member).filter(|s| !s.is_empty() && s.len() <= 64) else {
        return bad();
    };
    let Some(list) = b.bookings.filter(|v| v.get().starts_with('[')) else { return bad() };
    let Ok(list) = serde_json::from_str::<Vec<&RawValue>>(list.get()) else { return bad() };
    let mut errors = Vec::new();
    let mut minutes = 0;
    for (k, raw) in list.iter().enumerate() {
        let x = if raw.get().starts_with('{') { serde_json::from_str::<BookingIn>(raw.get()).ok() } else { None };
        let Some(x) = x else {
            booking_error(&mut errors, k, "booking", "must be an object");
            continue;
        };
        check_field(&mut errors, k, int_member(x.client, 1.0, 1_000_000.0), "clientId",
                    "must be an integer from 1 to 1000000");
        check_field(&mut errors, k, int_member(x.staff, 1.0, 10.0), "staffId", "must be an integer from 1 to 10");
        let service = match x.service {
            None => How::Absent,
            Some(v) => if string_member(v).is_some_and(|s| is_service(&s)) { How::Fine } else { How::Wrong },
        };
        check_field(&mut errors, k, service, "service", "must be a service code");
        let (start, from) = time_member(x.start);
        let (end, to) = time_member(x.end);
        check_field(&mut errors, k, start, "start", "must be an ISO 8601 time");
        check_field(&mut errors, k, end, "end", "must be an ISO 8601 time");
        if start == How::Fine && end == How::Fine && (to <= from || to - from > 8 * 3_600_000) {
            booking_error(&mut errors, k, "end", "must be after start, by at most 8 hours");
        }
        check_field(&mut errors, k, int_member(x.room, 1.0, 6.0), "room", "must be an integer from 1 to 6");
        let note = match x.note {
            None => How::Fine,
            Some(v) if v.get() == "null" => How::Fine,
            Some(v) => if string_member(v).is_some_and(|s| s.len() <= 500) { How::Fine } else { How::Wrong },
        };
        check_field(&mut errors, k, note, "note", "must be a string of at most 500 bytes");
        minutes += (to - from) / MINUTE;
    }
    if !errors.is_empty() {
        let mut buf = b"{\"error\":\"invalid\",\"errors\":[".to_vec();
        buf.extend_from_slice(&errors);
        buf.extend_from_slice(b"]}");
        return Reply::json(422, buf);
    }
    let mut buf = b"{\"batchId\":".to_vec();
    push_string(&mut buf, &id);
    buf.extend_from_slice(format!(",\"count\":{},\"minutes\":{minutes},\"ids\":[", list.len()).as_bytes());
    for k in 0..list.len() {
        if k > 0 {
            buf.push(b',');
        }
        push_string(&mut buf, &format!("{id}-{}", k + 1));
    }
    buf.extend_from_slice(b"]}");
    Reply::json(201, buf)
}

// POST /forms: the form's fields, decoded, in order.
pub fn form(body: &[u8]) -> Reply {
    let mut buf = b"{\"fields\":{".to_vec();
    let mut n = 0;
    for pair in body.split(|&c| c == b'&').filter(|p| !p.is_empty()) {
        let eq = memchr(b'=', pair).unwrap_or(pair.len());
        let (Some(k), Some(v)) = (decode_form(&pair[..eq]), decode_form(pair.get(eq + 1..).unwrap_or(b""))) else {
            return bad_request();
        };
        if n > 0 {
            buf.push(b',');
        }
        push_string(&mut buf, &String::from_utf8_lossy(&k));
        buf.push(b':');
        push_string(&mut buf, &String::from_utf8_lossy(&v));
        n += 1;
    }
    buf.extend_from_slice(format!("}},\"count\":{n}}}").as_bytes());
    Reply::json(200, buf)
}
