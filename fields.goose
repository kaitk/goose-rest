// A JSON writer from a struct's fields, for a program's format overload:
//
//   fn format(out: u8[>..]&, p: const Project&) { rest::format_fields(out, p); }
//
// docs/reference.md lists what each field type becomes.
namespace rest;

import std;
import json;
import http from "github.com/kaitk/goose-http@v0.3.6";

// Writes v as a JSON object: each field in declaration order, keyed by its
// name.
fn format_fields<T>(out: u8[>..]&, v: const T&) {
    out.push('{');
    var first = true;
    let rank: i32 = 0;
    const for <N, A> in fields<T> {
        if !first { out.push(','); }
        first = false;
        // A field's name is an identifier: nothing in it to escape.
        out.push('"');
        out.append(N);
        out.append("\":");
        field_json(out, v.A, rank);
    }
    out.push('}');
}

// The field writers, chosen by the field's type. Each takes rank, an i32,
// whose parameter here is an i32 but the catch-all's an f64: an integer
// converted to a float is overload resolution's last resort (§7.1), so the
// catch-all loses to every other writer, also to a slice reached by
// coercion, which it would otherwise tie.
// One per integer type, since one integer type widening to another is a
// coercion, which would tie with an integer's conversion to f64 for u64 and
// with a slice's for the rest.
fn field_json(out: u8[>..]&, v: i8, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: i16, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: i32, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: i64, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: u8, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: u16, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: u32, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: u64, rank: i32) { format(out, v); }
fn field_json(out: u8[>..]&, v: f64, rank: i32) { json::format_number(out, v); }
fn field_json<T>(out: u8[>..]&, v: const T[:], rank: i32) { elements_json(out, v, rank); }
// bool, an optional, and a struct or enum through the program's format
// overload, which Goose finds in the namespace that declares the type. No
// writer takes T?: any value reaches one by coercion, which ties with i64's
// and the slice's.
fn field_json(out: u8[>..]&, v, rank: f64) { format(out, v); }

// A u8 slice is a string; a slice of anything else, an array.
fn elements_json(out: u8[>..]&, v: const u8[:], rank: i32) { http::json_string(out, v); }
fn elements_json<T>(out: u8[>..]&, v: const T[:], rank: i32) {
    out.push('[');
    for e, i in v {
        if i > 0 { out.push(','); }
        field_json(out, e, rank);
    }
    out.push(']');
}
