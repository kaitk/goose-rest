// Tier D, writes with large bodies, under /api/v3, behind tier C's token,
// answered from the body alone as goose-http's bench/rest/hyper answers them:
//
//   POST  /api/v3/imports                        a CSV: its rows, and each column's count and sum
//   POST  /api/v3/attachments                    multipart: the fields, the file's size and Adler-32
//   POST  /api/v3/bookings/batch                 JSON: each booking's id, or 422 with the errors
//   POST  /api/v3/forms                          a form: its fields, decoded
//
// viltrum reads a body whole, up to the server's 16 MB, before a route runs,
// so a route's own limit is checked on a body already read. Each route checks
// its media type first, then its limit on the declared length and on the
// body, and reads: the CSV in one piece through a port of Goose's reader, the
// multipart body through viltrum's form_parts, and the batch through x.json2's
// Any.
module main

import strings
import viltrum
import x.json2

const import_limit = 16 << 20
const attachment_limit = 16 << 20
const batch_limit = 1 << 20
const form_limit = 64 << 10
const max_text = 1024
const max_texts = 8

fn unsupported_media_type() Reply {
	return json_str(415, '{"error":"unsupported_media_type","status":415}')
}

// 413, and the connection closed after it.
fn too_large() Reply {
	return Reply{
		status: 413
		close:  true
	}
}

// Whether a Content-Type's media type is want, ignoring case and parameters.
fn has_type(content_type ?string, want string) bool {
	v := content_type or { return false }
	return v.all_before(';').trim(' \t').to_lower() == want
}

// The route's media type, then its limit on the declared length and on the
// body read: the refusal, if any.
fn refused(c &viltrum.Ctx, media string, limit int) ?Reply {
	if !has_type(c.header('content-type'), media) {
		return unsupported_media_type()
	}
	if length := c.header('content-length') {
		if n := parse_uint(length) {
			if n > u64(limit) {
				return too_large()
			}
		}
	}
	if c.body().len > limit {
		return too_large()
	}
	return none
}

// A JSON string of s, its bytes that aren't UTF-8 replaced with U+FFFD, as
// Rust's from_utf8_lossy reads them.
fn push_lossy(mut out strings.Builder, s string) {
	mut clean := strings.new_builder(s.len)
	mut i := 0
	for i < s.len {
		c := s[i]
		n := if c < 0x80 {
			1
		} else if c >> 5 == 6 {
			2
		} else if c >> 4 == 14 {
			3
		} else if c >> 3 == 30 {
			4
		} else {
			0
		}
		mut ok := n > 0 && i + n <= s.len
		for k := 1; ok && k < n; k++ {
			ok = s[i + k] & 0xc0 == 0x80
		}
		if ok && n == 2 {
			ok = c >= 0xc2
		}
		if ok && n == 3 {
			d := s[i + 1]
			ok = !(c == 0xe0 && d < 0xa0) && !(c == 0xed && d >= 0xa0)
		}
		if ok && n == 4 {
			d := s[i + 1]
			ok = c <= 0xf4 && !(c == 0xf0 && d < 0x90) && !(c == 0xf4 && d >= 0x90)
		}
		if ok {
			clean.write_string(s[i..i + n])
			i += n
		} else {
			clean.write_string('\xef\xbf\xbd')
			i++
		}
	}
	push_string(mut out, clean.str())
}

// An import's columns, of three kinds.
enum Kind {
	text
	int
	dec
}

struct Column {
	name string
	kind Kind
}

const columns = [Column{'id', .int}, Column{'date', .text}, Column{'account', .text},
	Column{'description', .text}, Column{'quantity', .int}, Column{'amount', .dec}]

enum Quote {
	outside
	inside
	after
}

// A CSV body (RFC 4180, with LF or CRLF line ends) read piece by piece, as
// rest.goose's Csv: where the reader is, the field it's in, and each column's
// count of non-empty cells and its sum, or its bytes for text.
struct Csv {
mut:
	record i64 = 1
	column int
	quote  Quote
	closed bool
	cr     bool
	len    int
	value  i64
	neg    bool
	digits i64
	point  i64  = -1
	number bool = true
	header string
	counts [6]i64
	sums   [6]i64
	bad    i64
}

fn (mut c Csv) fail() {
	if c.bad == 0 {
		c.bad = c.record
	}
}

fn (mut c Csv) text(s string) {
	before := c.len
	c.len += s.len
	if c.record == 1 {
		if c.header.len + s.len <= 16 {
			c.header += s
		}
		return
	}
	if c.column >= columns.len {
		return
	}
	kind := columns[c.column].kind
	if kind == .text {
		return
	}
	for i in 0 .. s.len {
		ch := s[i]
		if ch >= `0` && ch <= `9` {
			if c.digits < 18 {
				c.value = c.value * 10 + i64(ch - `0`)
			} else {
				c.number = false
			}
			c.digits++
			if c.point >= 0 {
				c.point++
			}
		} else if ch == `-` && before + i == 0 {
			c.neg = true
		} else if ch == `.` && kind == .dec && c.point < 0 && c.digits > 0 {
			c.point = 0
		} else {
			c.number = false
		}
	}
}

fn (mut c Csv) field_end() {
	k := c.column
	if k >= columns.len {
		c.fail()
	} else if c.record == 1 {
		if c.len > 16 || c.header != columns[k].name {
			c.fail()
		}
	} else if c.len > 0 {
		kind := columns[k].kind
		if kind == .text {
			c.counts[k]++
			c.sums[k] += c.len
		} else if c.number && c.digits > 0 && (if kind == .dec {
			c.point == 2
		} else {
			c.point < 0
		}) {
			c.counts[k]++
			c.sums[k] += if c.neg { -c.value } else { c.value }
		} else {
			c.fail()
		}
	}
	c.column++
	c.len = 0
	c.value = 0
	c.neg = false
	c.digits = 0
	c.point = -1
	c.number = true
	c.closed = false
	c.header = ''
}

fn (mut c Csv) record_end() {
	c.field_end()
	if c.column != columns.len {
		c.fail()
	}
	c.record++
	c.column = 0
}

// The index of the first comma, quote, CR, or LF in p at or after from, or
// p.len.
fn field_stop(p string, from int) int {
	for j in from .. p.len {
		ch := p[j]
		if ch == `,` || ch == `\n` || ch == `\r` || ch == `"` {
			return j
		}
	}
	return p.len
}

fn (mut c Csv) piece(p string) {
	mut i := 0
	for i < p.len && c.bad == 0 {
		ch := p[i]
		if c.quote == .inside {
			q := p.index_after_('"', i)
			if q < 0 {
				c.text(p[i..])
				return
			}
			c.text(p[i..q])
			c.quote = .after
			i = q + 1
			continue
		}
		if c.quote == .after {
			c.quote = .outside
			if ch == `"` {
				c.text(p[i..i + 1])
				c.quote = .inside
				i++
				continue
			}
			c.closed = true
		}
		if c.cr {
			c.cr = false
			if ch != `\n` {
				c.fail()
				return
			}
		}
		if ch == `,` {
			c.field_end()
			i++
		} else if ch == `\n` {
			c.record_end()
			i++
		} else if ch == `\r` {
			c.cr = true
			i++
		} else if c.closed || (ch == `"` && c.len > 0) {
			c.fail()
		} else if ch == `"` {
			c.quote = .inside
			i++
		} else {
			j := field_stop(p, i + 1)
			c.text(p[i..j])
			i = j
		}
	}
}

fn (mut c Csv) end() {
	if c.bad != 0 {
		return
	}
	if c.quote == .inside || c.cr {
		c.fail()
		return
	}
	if c.quote == .after || c.closed || c.column > 0 || c.len > 0 {
		c.record_end()
	}
	if c.record == 1 {
		c.fail()
	}
}

fn push_cents(mut out strings.Builder, v i64) {
	a := if v < 0 { u64(0) - u64(v) } else { u64(v) }
	if v < 0 {
		out.write_u8(`-`)
	}
	out.write_string((a / 100).str())
	out.write_u8(`.`)
	out.write_u8(u8(`0` + a % 100 / 10))
	out.write_u8(u8(`0` + a % 10))
}

fn import_csv(body string) Reply {
	mut c := &Csv{}
	c.piece(body)
	c.end()
	if c.bad != 0 {
		mut b := strings.new_builder(48)
		b.write_string('{"error":"bad_csv","record":')
		push_int(mut b, c.bad)
		b.write_u8(`}`)
		return json_with(400, b)
	}
	mut b := strings.new_builder(512)
	b.write_string('{"rows":')
	push_int(mut b, c.record - 2)
	b.write_string(',"columns":[')
	for k, col in columns {
		if k > 0 {
			b.write_u8(`,`)
		}
		b.write_string('{"name":"')
		b.write_string(col.name)
		b.write_string('","count":')
		push_int(mut b, c.counts[k])
		match col.kind {
			.text {
				b.write_string(',"bytes":')
				push_int(mut b, c.sums[k])
			}
			.int {
				b.write_string(',"sum":')
				push_int(mut b, c.sums[k])
			}
			.dec {
				b.write_string(',"sum":')
				push_cents(mut b, c.sums[k])
			}
		}

		b.write_u8(`}`)
	}
	b.write_string(']}')
	return json_with(201, b)
}

// Adler-32 (RFC 1950), deferring the modulo as zlib does.
@[direct_array_access]
fn adler32(data []u8) u32 {
	mut a, mut b := u32(1), u32(0)
	mut at := 0
	for at < data.len {
		end := if at + 5552 < data.len { at + 5552 } else { data.len }
		for k in at .. end {
			a += data[k]
			b += a
		}
		a %= 65521
		b %= 65521
		at = end
	}
	return (b << 16) | a
}

// POST /api/v3/attachments: a multipart body of text fields and one file,
// as viltrum's form_parts hands over its parts, checked as the Rust servers
// check them: a part needs a name, and is the file if it has a filename
// that isn't empty.
fn attachment(c &viltrum.Ctx) Reply {
	mut parts := c.form_parts()
	mut fields := strings.new_builder(256)
	mut texts := 0
	mut file := ?viltrum.FormPart(none)
	for {
		p := parts.next() or { break }
		if p.name.len == 0 || p.name.len > 64 {
			return bad_request()
		}
		if p.filename.len > 0 {
			if file != none || p.filename.len > 256 || p.content_type.len > 128 {
				return bad_request()
			}
			file = p
		} else {
			if texts == max_texts || p.data.len > max_text {
				return bad_request()
			}
			if texts > 0 {
				fields.write_u8(`,`)
			}
			push_lossy(mut fields, p.name)
			fields.write_u8(`:`)
			push_lossy(mut fields, view(p.data))
			texts++
		}
	}
	if parts.malformed() {
		return bad_request()
	}
	f := file or {
		return json_str(422,
			'{"error":"invalid","errors":[{"field":"file","message":"is required"}]}')
	}

	mut b := strings.new_builder(fields.len + 256)
	b.write_string('{"fields":{')
	b.write(fields) or {}
	b.write_string('},"file":{"field":')
	push_lossy(mut b, f.name)
	b.write_string(',"filename":')
	push_lossy(mut b, f.filename)
	b.write_string(',"contentType":')
	push_lossy(mut b, if f.content_type.len > 0 {
		f.content_type
	} else {
		'application/octet-stream'
	})
	b.write_string(',"size":')
	push_int(mut b, f.data.len)
	b.write_string(',"adler32":')
	push_int(mut b, adler32(f.data))
	b.write_string('}}')
	return json_with(201, b)
}

// How a booking's member read: absent, wrong, or fine.
enum How {
	absent
	wrong
	fine
}

// An integer from lo to hi: a JSON number with no fraction.
fn int_member(x map[string]json2.Any, key string, lo f64, hi f64) How {
	v := x[key] or { return .absent }
	if v is f64 {
		return if v >= lo && v <= hi && v == f64(i64(v)) { .fine } else { .wrong }
	}
	return .wrong
}

fn is_service(s string) bool {
	d := s.index_u8(`-`)
	if d < 2 || d > 4 || s.len != d + 3 {
		return false
	}
	for i in 0 .. d {
		if s[i] < `A` || s[i] > `Z` {
			return false
		}
	}
	return s[d + 1] >= `0` && s[d + 1] <= `9` && s[d + 2] >= `0` && s[d + 2] <= `9`
}

fn time_member(x map[string]json2.Any, key string) (How, i64) {
	v := x[key] or { return How.absent, i64(0) }
	if v is string {
		if t := parse_iso(v) {
			return How.fine, t
		}
	}
	return How.wrong, i64(0)
}

fn booking_error(mut errors strings.Builder, k int, field string, message string) {
	if errors.len > 0 {
		errors.write_u8(`,`)
	}
	errors.write_string('{"index":')
	push_int(mut errors, k)
	errors.write_string(',"field":"')
	errors.write_string(field)
	errors.write_string('","message":"')
	errors.write_string(message)
	errors.write_string('"}')
}

fn check_field(mut errors strings.Builder, k int, how How, field string, message string) {
	if how == .absent {
		booking_error(mut errors, k, field, 'is required')
	}
	if how == .wrong {
		booking_error(mut errors, k, field, message)
	}
}

// POST /bookings/batch: each booking's id, the batch's id and its number,
// and their minutes, or 422 with each field that doesn't validate.
fn batch(body string) Reply {
	if !is_object(body) {
		return bad_request()
	}
	doc := json2.decode[json2.Any](body) or { return bad_request() }
	if doc !is map[string]json2.Any {
		return bad_request()
	}
	m := doc as map[string]json2.Any
	id := m['batchId'] or { return bad_request() }
	if id !is string || (id as string).len == 0 || (id as string).len > 64 {
		return bad_request()
	}
	batch_id := id as string
	list_any := m['bookings'] or { return bad_request() }
	if list_any !is []json2.Any {
		return bad_request()
	}
	list := list_any as []json2.Any
	mut errors := strings.new_builder(0)
	mut minutes := i64(0)
	for k, item in list {
		if item !is map[string]json2.Any {
			booking_error(mut errors, k, 'booking', 'must be an object')
			continue
		}
		x := item as map[string]json2.Any
		check_field(mut errors, k, int_member(x, 'clientId', 1, 1_000_000), 'clientId',
			'must be an integer from 1 to 1000000')
		check_field(mut errors, k, int_member(x, 'staffId', 1, 10), 'staffId',
			'must be an integer from 1 to 10')
		mut service := How.absent
		if s := x['service'] {
			service = if s is string && is_service(s) { How.fine } else { How.wrong }
		}
		check_field(mut errors, k, service, 'service', 'must be a service code')
		start, from := time_member(x, 'start')
		end, to := time_member(x, 'end')
		check_field(mut errors, k, start, 'start', 'must be an ISO 8601 time')
		check_field(mut errors, k, end, 'end', 'must be an ISO 8601 time')
		if start == .fine && end == .fine && (to <= from || to - from > 8 * 3_600_000) {
			booking_error(mut errors, k, 'end', 'must be after start, by at most 8 hours')
		}
		check_field(mut errors, k, int_member(x, 'room', 1, 6), 'room',
			'must be an integer from 1 to 6')
		mut note := How.fine
		if n := x['note'] {
			if n !is json2.Null {
				note = if n is string && n.len <= 500 { How.fine } else { How.wrong }
			}
		}
		check_field(mut errors, k, note, 'note', 'must be a string of at most 500 bytes')
		minutes += (to - from) / minute
	}
	if errors.len > 0 {
		mut b := strings.new_builder(errors.len + 40)
		b.write_string('{"error":"invalid","errors":[')
		b.write(errors) or {}
		b.write_string(']}')
		return json_with(422, b)
	}
	mut out := strings.new_builder(64 + list.len * (batch_id.len + 8))
	out.write_string('{"batchId":')
	push_string(mut out, batch_id)
	out.write_string(',"count":')
	push_int(mut out, list.len)
	out.write_string(',"minutes":')
	push_int(mut out, minutes)
	out.write_string(',"ids":[')
	for k in 0 .. list.len {
		if k > 0 {
			out.write_u8(`,`)
		}
		push_string(mut out, '${batch_id}-${k + 1}')
	}
	out.write_string(']}')
	return json_with(201, out)
}

// POST /forms: the form's fields, decoded, in order.
fn form(body string) Reply {
	mut b := strings.new_builder(body.len + 64)
	b.write_string('{"fields":{')
	mut n := 0
	for pair in body.split('&') {
		if pair.len == 0 {
			continue
		}
		k := decode_form(pair.all_before('=')) or { return bad_request() }
		v := decode_form(if pair.contains_u8(`=`) { pair.all_after_first('=') } else { '' }) or {
			return bad_request()
		}
		if n > 0 {
			b.write_u8(`,`)
		}
		push_lossy(mut b, k)
		b.write_u8(`:`)
		push_lossy(mut b, v)
		n++
	}
	b.write_string('},"count":')
	push_int(mut b, n)
	b.write_u8(`}`)
	return json_ok(b)
}

fn writes_routes(mut app viltrum.App) {
	mut v3 := app.group('/api/v3', heavy_bearer)
	v3.post('/imports', fn (mut c viltrum.Ctx) {
		answer(mut c, refused(c, 'text/csv', import_limit) or { import_csv(view(c.body())) })
	})
	v3.post('/attachments', fn (mut c viltrum.Ctx) {
		answer(mut c, refused(c, 'multipart/form-data', attachment_limit) or { attachment(c) })
	})
	v3.post('/bookings/batch', fn (mut c viltrum.Ctx) {
		answer(mut c, refused(c, 'application/json', batch_limit) or { batch(view(c.body())) })
	})
	v3.post('/forms', fn (mut c viltrum.Ctx) {
		answer(mut c, refused(c, 'application/x-www-form-urlencoded', form_limit) or {
			form(view(c.body()))
		})
	})
}
