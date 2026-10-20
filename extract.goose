// Extractors: the typed parts of a request. Each one that finds a part
// missing or malformed fails the enclosing route with 400
// {"error":"invalid_parameter","detail":"<name>: <check>"}
// (docs/reference.md, "Errors"), so every caller runs inside rest::route.
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@v0.4.2";

// The value of T the request holds, as T's from_request overload reads it.
// The generator writes one for each schema object, which reads the JSON
// body, and one for each operation's parameters. A program declares its own
// in this namespace, since a generic body finds names only where it's
// defined (spike 01):
//
//   fn rest::from_request(cx, v: const app::Session?) -> app::Session { ... }
//
// v is always null: its type picks the overload, and the result is built
// where the caller puts it, so T may hold u8[] fields.
fn take<T>(cx) -> T {
    let none: const T? = null;
    return from_request(cx, none);
}

// The functions here that fail are kept small, and their work is in leaves
// that return whether it succeeded. A function that fails and stays a call
// needs its route's frame, which keeps the route, the middleware around it,
// and the handler out of line (docs/architecture.md, "Middleware and inlining").

// s with its escapes decoded, and with '+' as a space when plus is set: s
// itself when it has neither, or else decoded onto cx.scratch, which the
// result then points into. A '%' without two hex digits fails the route
// with "<name>: encoding".
fn decoded(cx, s: const u8[:], plus: bool, name: const u8[:]) -> const u8[:] {
    let v, ok = unescaped(s, plus, cx.scratch);
    guard ok else { fail_param(cx, str(name, ": encoding")); }
    return v;
}

// s decoded as decoded does, onto scratch where it has escapes, and false for
// a bad escape.
fn unescaped(s: const u8[:], plus: bool, scratch: u8[>..]&) -> const u8[:], bool {
    var plain = true;
    for c in s { if c == '%' || plus && c == '+' { plain = false; } }
    if plain { return s, true; }
    let at = scratch.len;
    let ok = http::decode(s, scratch, plus);
    return scratch[at..], ok;
}

// s as a decimal integer, or a failure, "<name>: integer", for anything
// else: a sign other than a leading '-', another byte, no digits, or a value
// past i64.
fn int_of(cx, s: const u8[:], name: const u8[:]) -> i64 {
    let v, ok = decimal(s);
    guard ok else { fail_param(cx, str(name, ": integer")); }
    return v;
}

// s as int_of reads it, and whether it is one.
fn decimal(s: const u8[:]) -> i64, bool {
    let neg = s.len > 0 && s[0] == '-';
    var i = if neg { 1 } else { 0 };
    guard i < s.len else { return 0, false; }
    var v: i64 = 0;
    while i < s.len {
        let c = s[i];
        guard c >= '0' && c <= '9' else { return 0, false; }
        let digit: i64 = c - '0';
        guard v <= (9223372036854775807 - digit) / 10 else { return 0, false; }
        v = v * 10 + digit;
        i++;
    }
    return if neg { -v } else { v }, true;
}

// s as JSON's true or false, or a failure, "<name>: boolean".
fn bool_of(cx, s: const u8[:], name: const u8[:]) -> bool {
    if s == "true" { return true; }
    guard s == "false" else { fail_param(cx, str(name, ": boolean")); }
    return false;
}

// Fails the route with "<name>: required" unless found.
fn require(cx, name: const u8[:], found: bool) {
    guard found else { fail_param(cx, str(name, ": required")); }
}

// The path parameter name of the route rest::on matched, decoded.
fn param<S, A>(cx: Cx<S, A, http::Router>&, name: const u8[:]) -> const u8[:] {
    return decoded(cx, http::param(cx.router, name), false, name);
}

// The path parameter name of the route rest::on matched, as an integer.
fn param_int<S, A>(cx: Cx<S, A, http::Router>&, name: const u8[:]) -> i64 {
    return path_int(cx, http::param(cx.router, name), name);
}

// The path parameter name of the route r matched, decoded, for a program
// that builds its own http::router.
fn param(cx, r: const http::Router&, name: const u8[:]) -> const u8[:] {
    return decoded(cx, http::param(r, name), false, name);
}

// The path parameter name of the route r matched, as an integer.
fn param_int(cx, r: const http::Router&, name: const u8[:]) -> i64 {
    return path_int(cx, http::param(r, name), name);
}

// A path segment, still encoded, decoded.
fn path_str(cx, seg: const u8[:], name: const u8[:]) -> const u8[:] {
    return decoded(cx, seg, false, name);
}

// A path segment, still encoded, as an integer named name.
fn path_int(cx, seg: const u8[:], name: const u8[:]) -> i64 {
    return int_of(cx, decoded(cx, seg, false, name), name);
}

// The query parameter name, decoded with '+' as a space, and whether the
// query has it; the first, if it repeats. The key is compared as sent.
fn query(cx, name: const u8[:]) -> const u8[:], bool {
    let v, found = http::query_of(cx.req.target, name);
    guard found else { return v, false; }
    return decoded(cx, v, true, name), true;
}

// The query parameter name as an integer, and whether the query has it.
fn query_int(cx, name: const u8[:]) -> i64, bool {
    let v, found = query(cx, name);
    guard found else { return 0, false; }
    return int_of(cx, v, name), true;
}

// The query parameter name as true or false, and whether the query has it.
fn query_bool(cx, name: const u8[:]) -> bool, bool {
    let v, found = query(cx, name);
    guard found else { return false, false; }
    return bool_of(cx, v, name), true;
}

// The field name of an application/x-www-form-urlencoded body, decoded with
// '+' as a space, and whether the body has it; the first, if it repeats. The
// key is compared as sent. The body is read with rest::body, so a route runs
// twice up to its first form call when the body is gathered. 415 for a body
// of another media type. cx is a reference, since the value can be a slice of
// cx.body.
fn form<S, A, R>(cx: Cx<S, A, R>&, name: const u8[:]) -> const u8[:], bool {
    guard http::has_type(cx.req, "application/x-www-form-urlencoded") else { fail(cx, 415, "unsupported_media_type"); }
    let v, found = form_of(body(cx), name);
    guard found else { return v, false; }
    return decoded(cx, v, true, name), true;
}

// The value of body's first pair whose key is name, still encoded, and
// whether it has one, as http::query_of finds a query's. http::each_form
// can't hand a value out: it gives "" for a pair without '=', a static
// string, which a slice of the body can't be rebound to (spec §9.2).
fn form_of(body: const u8[:], name: const u8[:]) -> const u8[:], bool {
    var rest = body;
    loop {
        let amp = position(rest, '&');
        let pair = if amp >= 0 { rest[..amp] } else { rest };
        let eq = position(pair, '=');
        let k = if eq >= 0 { pair[..eq] } else { pair };
        if k == name && pair.len > 0 { return if eq >= 0 { pair[eq + 1..] } else { pair[pair.len..] }, true; }
        guard amp >= 0 else { return rest[..0], false; }
        rest = rest[amp + 1..];
    }
}

// The form field name as an integer, and whether the body has it.
fn form_int(cx, name: const u8[:]) -> i64, bool {
    let v, found = form(cx, name);
    guard found else { return 0, false; }
    return int_of(cx, v, name), true;
}

// The form field name as true or false, and whether the body has it.
fn form_bool(cx, name: const u8[:]) -> bool, bool {
    let v, found = form(cx, name);
    guard found else { return false, false; }
    return bool_of(cx, v, name), true;
}

// The text of the part name in a multipart/form-data body, as sent, and
// whether the body has it; the first, if it repeats. The body is read with
// rest::body, so a route runs twice up to its first part call when the body
// is gathered. The value is a slice of the body. 415 for a body of another
// media type or without a usable boundary, 400 for one that isn't multipart.
// Uploads read as they arrive are goose-http's http::each_part.
fn part<S, A, R>(cx: Cx<S, A, R>&, name: const u8[:]) -> const u8[:], bool {
    let v, filename, kind, found = file_part(cx, name);
    return v, found;
}

// The part name as an integer, and whether the body has it.
fn part_int(cx, name: const u8[:]) -> i64, bool {
    let v, found = part(cx, name);
    guard found else { return 0, false; }
    return int_of(cx, v, name), true;
}

// The part name as true or false, and whether the body has it.
fn part_bool(cx, name: const u8[:]) -> bool, bool {
    let v, found = part(cx, name);
    guard found else { return false, false; }
    return bool_of(cx, v, name), true;
}

// The part name of a multipart/form-data body as a file: its bytes, its
// filename ("" without one), its content type (application/octet-stream
// without one), and whether the body has it; the first, if it repeats. Failures
// and lifetime are part's; all three are slices of the body.
fn file_part<S, A, R>(cx: Cx<S, A, R>&, name: const u8[:]) -> const u8[:], const u8[:], const u8[:], bool {
    let v, fields, status = http::find_part(cx.req, body(cx), name);
    guard status != http::PART_TYPE else { fail(cx, 415, "unsupported_media_type"); }
    guard status != http::PART_BAD else { fail_param(cx, "body: multipart"); }
    guard status == http::PART_FOUND else { return v, v, v, false; }
    let n, filename, ok = http::disposition(fields);
    let t, typed = http::field_in(fields, "content-type");
    return v, filename, if typed { t } else { "application/octet-stream" }, true;
}

// The header field name's value, its name compared ignoring case, and
// whether the request has it; the first, if it repeats.
fn header(cx, name: const u8[:]) -> const u8[:], bool {
    return http::field_of(cx.req, name);
}

// The cookie name's value, compared as sent, and whether the request has
// it; the first, if it repeats.
fn cookie(cx, name: const u8[:]) -> const u8[:], bool {
    return http::cookie_of(cx.req, name);
}

// A value computed on first use and kept for the rest of the request. A
// field of the request state, which starts each request undone.
struct Once<T> { done: bool = false, value: T }

// slot's value, computed by F() the first time a request asks for it.
fn once<T, F>(slot: Once<T>&) -> T& {
    if !slot.done {
        slot.value = F();
        slot.done = true;
    }
    return slot.value;
}
