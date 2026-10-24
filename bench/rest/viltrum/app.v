// goose-http's REST benchmark tiers on viltrum: the records, the answers, and
// the helpers the tiers share, ported from bench/rest/rust-app's lib.rs, and
// the answer type each route writes through viltrum's Ctx.
//
//   arena.v      tier A, HttpArena's production-stack application layer
//   snow.v       tier B, snowtime's k6 hot path, under /api/v1
//   heavy.v      tier C, a clinic's schedule and records, under /api/v2
//   writes.v     tier D, writes with large bodies, under /api/v3, beside C
//   framework.v  Plod's tiers F, R, and M (bench/rest/tiers)
//
// Each tier's file holds its records and answers, and its routes on
// viltrum's App, groups, and middleware.
module main

import os
import strings
import time
import viltrum
import x.json2

// A response: its status, whether its body is JSON, and whether the server
// closes the connection after it, rather than read the rest of a body.
struct Reply {
	status int = 200
	json   bool
	close  bool
	body   []u8
}

fn empty(status int) Reply {
	return Reply{
		status: status
	}
}

fn json_with(status int, body []u8) Reply {
	return Reply{
		status: status
		json:   true
		body:   body
	}
}

fn json_ok(body []u8) Reply {
	return json_with(200, body)
}

// A constant JSON answer.
fn json_str(status int, s string) Reply {
	return json_with(status, s.bytes())
}

// answer writes r through c.
fn answer(mut c viltrum.Ctx, r Reply) {
	if r.close {
		c.close()
	}
	if r.json {
		c.bytes(r.status, 'application/json', r.body)
	} else if r.body.len > 0 {
		c.bytes(r.status, 'text/plain; charset=utf-8', r.body)
	} else {
		c.no_content(r.status)
	}
}

enum Tier {
	a
	b
	c
	d
	f
	r
	m
}

struct Config {
	tier      Tier
	tier_name string
	workers   int
	port      int
	// JSON=template: answers from each record's JSON, written once at
	// startup, with the per-request values added.
	template bool
	dir      string
	routes   string
}

// config reads TIER, REST_DATA, JSON, WORKERS, and ROUTES, and the port from
// the first argument.
fn config() Config {
	name := env('TIER', 'a')
	tier := match name {
		'a' { Tier.a }
		'b' { Tier.b }
		'c' { Tier.c }
		'd' { Tier.d }
		'f' { Tier.f }
		'r' { Tier.r }
		'm' { Tier.m }
		else { stop('TIER is a, b, c, d, f, r, or m') }
	}

	// 0 leaves the count to viltrum: the CPUs in the affinity mask.
	workers := parse_uint(os.getenv('WORKERS')) or { u64(0) }
	mut port := 8080
	if os.args.len > 1 {
		if p := parse_uint(os.args[1]) {
			if p <= 65535 {
				port = int(p)
			}
		}
	}
	return Config{
		tier:      tier
		tier_name: name
		workers:   int(workers)
		port:      port
		template:  os.getenv('JSON') == 'template'
		dir:       env('REST_DATA', 'build/rest')
		routes:    env('ROUTES', 'bench/rest/tiers/github.txt')
	}
}

fn env(name string, fallback string) string {
	v := os.getenv(name)
	return if v == '' { fallback } else { v }
}

@[noreturn]
fn stop(what string) {
	eprintln('rest-viltrum: ${what}')
	exit(1)
}

const day = i64(86_400_000)
const minute = i64(60_000)

// The time in seconds, and in ms, since the epoch.
fn now_s() i64 {
	return time.now().unix()
}

fn now_ms() i64 {
	return time.now().unix_milli()
}

// dir/name whole, or a stop that says to run goose-http's gen.goose.
fn read_file(dir string, name string) string {
	path := '${dir}/${name}'
	return os.read_file(path) or {
		stop('${path}: can\'t read; run goose-http\'s bench/rest/gen.goose')
	}
}

// The records of a JSON array in dir/name.
fn parse_file[T](dir string, name string) []T {
	return json2.decode[[]T](read_file(dir, name)) or { stop('${name}: ${err}') }
}

// A view of b as a string, valid while b is.
fn view(b []u8) string {
	return unsafe { tos(b.data, b.len) }
}

// id as a record's index, if it's one of n.
fn index_of(id u64, n int) ?int {
	if id >= 1 && id <= u64(n) {
		return int(id - 1)
	}
	return none
}

// A decimal integer as Rust's str::parse reads one: an optional sign, then
// digits only, within range.
fn parse_int(s string) ?i64 {
	mut i := 0
	mut negative := false
	if s.len > 0 && (s[0] == `+` || s[0] == `-`) {
		negative = s[0] == `-`
		i = 1
	}
	if i == s.len {
		return none
	}
	mut v := u64(0)
	for k in i .. s.len {
		c := s[k]
		if c < `0` || c > `9` {
			return none
		}
		d := u64(c - `0`)
		if v > (max_u64 - d) / 10 {
			return none
		}
		v = v * 10 + d
	}
	limit := u64(max_i64)
	if negative {
		if v > limit + 1 {
			return none
		}
		return i64(u64(0) - v)
	}
	if v > limit {
		return none
	}
	return i64(v)
}

fn parse_uint(s string) ?u64 {
	mut i := 0
	if s.len > 0 && s[0] == `+` {
		i = 1
	}
	if i == s.len {
		return none
	}
	mut v := u64(0)
	for k in i .. s.len {
		c := s[k]
		if c < `0` || c > `9` {
			return none
		}
		d := u64(c - `0`)
		if v > (max_u64 - d) / 10 {
			return none
		}
		v = v * 10 + d
	}
	return v
}

fn is_base64url(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !(c.is_letter() || c.is_digit() || c == `-` || c == `_`) {
			return false
		}
	}
	return true
}

// Whether an Authorization value is a bearer token of three base64url
// segments, as tiers C and D require; the token isn't verified.
fn has_bearer(authorization ?string) bool {
	a := authorization or { return false }
	if !a.starts_with('Bearer ') {
		return false
	}
	parts := a[7..].split('.')
	return parts.len == 3 && is_base64url(parts[0]) && is_base64url(parts[1])
		&& is_base64url(parts[2])
}

// Whether an Authorization value is a bearer token, as tier M requires.
fn is_bearer(authorization ?string) bool {
	a := authorization or { return false }
	return a.starts_with('Bearer ') && a.len > 7
}

fn hex(c u8) int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a`) + 10
	}
	if c >= `A` && c <= `F` {
		return int(c - `A`) + 10
	}
	return -1
}

// A form's key or value decoded: '+' as a space, and percent-escapes, or none
// for a '%' without two hex digits after it.
fn decode_form(s string) ?string {
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
			out.write_u8(if s[i] == `+` { ` ` } else { s[i] })
			i++
		}
	}
	return out.str()
}

// Whether body's JSON value, if any, is an object.
fn is_object(body string) bool {
	for c in body {
		if c == ` ` || c == `\t` || c == `\r` || c == `\n` || c == `\f` {
			continue
		}
		return c == `{`
	}
	return false
}

// Whether body is one JSON value.
fn is_json(body string) bool {
	json2.decode[json2.Any](body) or { return false }
	return true
}

fn digits(mut b []u8, at int, n int, value i64) {
	mut v := value
	for i := n - 1; i >= 0; i-- {
		b[at + i] = u8(`0` + v % 10)
		v /= 10
	}
}

fn number_at(s string, at int, n int) i64 {
	mut v := i64(0)
	for i in at .. at + n {
		if s[i] < `0` || s[i] > `9` {
			return -1
		}
		v = v * 10 + i64(s[i] - `0`)
	}
	return v
}

fn div_floor(a i64, b i64) i64 {
	q := a / b
	return if a % b != 0 && (a < 0) != (b < 0) { q - 1 } else { q }
}

// ms since the epoch as JavaScript's toISOString writes it.
fn iso(ms i64) string {
	d := div_floor(ms, day)
	t := ms - d * day
	z := d + 719_468
	era := (if z >= 0 { z } else { z - 146_096 }) / 146_097
	doe := z - era * 146_097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	m := if mp < 10 { mp + 3 } else { mp - 9 }
	mut b := '0000-00-00T00:00:00.000Z'.bytes()
	digits(mut b, 0, 4, yoe + era * 400 + (if m <= 2 { 1 } else { 0 }))
	digits(mut b, 5, 2, m)
	digits(mut b, 8, 2, doy - (153 * mp + 2) / 5 + 1)
	digits(mut b, 11, 2, t / 3_600_000)
	digits(mut b, 14, 2, t / minute % 60)
	digits(mut b, 17, 2, t / 1000 % 60)
	digits(mut b, 20, 3, t % 1000)
	return b.bytestr()
}

// A time as a JSON string, for a template's splice.
fn push_iso(mut out strings.Builder, ms i64) {
	out.write_u8(`"`)
	out.write_string(iso(ms))
	out.write_u8(`"`)
}

// Howard Hinnant's days_from_civil.
fn days_from(y i64, m i64, d i64) i64 {
	yy := if m <= 2 { y - 1 } else { y }
	era := (if yy >= 0 { yy } else { yy - 399 }) / 400
	yoe := yy - era * 400
	doy := (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1
	return era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
}

// "YYYY-MM-DDTHH:MM:SS.sssZ", or without the milliseconds, as ms since the
// epoch.
fn parse_iso(s string) ?i64 {
	n := s.len
	if !((n == 24 || n == 20) && s[4] == `-` && s[7] == `-` && s[10] == `T` && s[13] == `:`
		&& s[16] == `:` && s[n - 1] == `Z`) {
		return none
	}
	y, m, d := number_at(s, 0, 4), number_at(s, 5, 2), number_at(s, 8, 2)
	h, mi, sec := number_at(s, 11, 2), number_at(s, 14, 2), number_at(s, 17, 2)
	ms := if n == 24 && s[19] == `.` {
		number_at(s, 20, 3)
	} else if n == 20 {
		i64(0)
	} else {
		i64(-1)
	}
	ok := y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31 && h >= 0 && h < 24 && mi >= 0 && mi < 60
		&& sec >= 0 && sec < 60 && ms >= 0
	if !ok {
		return none
	}
	return days_from(y, m, d) * day + ((h * 60 + mi) * 60 + sec) * 1000 + ms
}

// "YYYY-MM-DD" as ms since the epoch at its midnight in UTC.
fn parse_day(s string) ?i64 {
	if !(s.len == 10 && s[4] == `-` && s[7] == `-`) {
		return none
	}
	y, m, d := number_at(s, 0, 4), number_at(s, 5, 2), number_at(s, 8, 2)
	if !(y >= 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
		return none
	}
	return days_from(y, m, d) * day
}

// Writes n as decimal digits onto out.
fn push_int(mut out strings.Builder, n i64) {
	out.write_string(n.str())
}

const hexdigits = '0123456789abcdef'

// A JSON string literal of s, escaped as serde_json escapes it.
fn push_string(mut out strings.Builder, s string) {
	out.write_u8(`"`)
	for c in s {
		match c {
			`"` {
				out.write_string('\\"')
			}
			`\\` {
				out.write_string('\\\\')
			}
			0x08 {
				out.write_string('\\b')
			}
			0x0c {
				out.write_string('\\f')
			}
			`\n` {
				out.write_string('\\n')
			}
			`\r` {
				out.write_string('\\r')
			}
			`\t` {
				out.write_string('\\t')
			}
			else {
				if c < 0x20 {
					out.write_string('\\u00')
					out.write_u8(hexdigits[c >> 4])
					out.write_u8(hexdigits[c & 0xf])
				} else {
					out.write_u8(c)
				}
			}
		}
	}
	out.write_u8(`"`)
}

// value written as JSON by V's x.json2, which writes the members' keys their
// json attributes name, and null for an option marked json_null.
fn written[T](value T) []u8 {
	return json2.encode(value).bytes()
}
