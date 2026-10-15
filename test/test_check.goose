// Unit tests for the checks the generated readers call (check.goose).
// scripts/test-unit.sh runs them through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "../";

fn test_code_points() {
    assert(rest::code_points("") == 0);
    assert(rest::code_points("goose") == 5);
    assert(rest::code_points("hané") == 4);
    assert(rest::code_points("€𝄞") == 2);
    assert(rest::code_points("\xF4\x8F\xBF\xBF") == 1);
    // A stray continuation byte, an overlong form, a truncated sequence, a
    // surrogate, a code point past U+10FFFF, and a lead byte no code point has.
    for b in ["\x80", "\xC0\x80", "\xC3", "\xE0\x80\x80", "\xED\xA0\x80", "\xF4\x90\x80\x80",
              "\xF5\x80\x80\x80", "\xE2\x82", "a\xE2\x82\x28"] {
        if rest::code_points(b) != -1 { print("code_points took ", b); assert(false); }
    }
}

fn test_date() {
    for s in ["2026-10-13", "2024-02-29", "2000-02-29", "0001-01-01", "2026-12-31"] {
        if !rest::is_date(s) { print("is_date refused ", s); assert(false); }
    }
    for s in ["2026-10-1", "2026-13-01", "2026-00-10", "2026-04-31", "2023-02-29", "1900-02-29",
              "2026/10/13", "2026-10-13T", "20261013", "abcd-10-13", ""] {
        if rest::is_date(s) { print("is_date took ", s); assert(false); }
    }
}

fn test_date_time() {
    for s in ["2026-10-13T18:28:00Z", "2026-10-13t18:28:00z", "2026-10-13T18:28:00.123456Z",
              "2026-10-13T23:59:60+02:00", "2026-10-13T00:00:00-11:30"] {
        if !rest::is_date_time(s) { print("is_date_time refused ", s); assert(false); }
    }
    for s in ["2026-10-13T18:28:00", "2026-10-13 18:28:00Z", "2026-10-13T24:00:00Z",
              "2026-10-13T18:60:00Z", "2026-10-13T18:28:61Z", "2026-10-13T18:28:00.Z",
              "2026-10-13T18:28:00+0200", "2026-10-13T18:28:00+02:00x", "2026-02-30T00:00:00Z"] {
        if rest::is_date_time(s) { print("is_date_time took ", s); assert(false); }
    }
}

fn test_ascii() {
    assert(rest::is_ascii(""));
    assert(rest::is_ascii("#ff0000 ~\x7F"));
    assert(!rest::is_ascii("hané"));
    assert(!rest::is_ascii("\x80"));
    assert(!rest::is_ascii("😀"));
}

fn test_uuid() {
    assert(rest::is_uuid("123e4567-e89b-12d3-a456-426614174000"));
    assert(rest::is_uuid("123E4567-E89B-12D3-A456-426614174000"));
    assert(!rest::is_uuid("123e4567e89b12d3a456426614174000"));
    assert(!rest::is_uuid("123e4567-e89b-12d3-a456-42661417400g"));
    assert(!rest::is_uuid("{123e4567-e89b-12d3-a456-426614174000}"));
}

fn test_email() {
    for s in ["a@b.co", "first.last+tag@example.com", "x_y@sub.do-main.org", "1@2.3"] {
        if !rest::is_email(s) { print("is_email refused ", s); assert(false); }
    }
    for s in ["", "@b.co", "a@", "a@b", "a@.b.co", "a@b.co.", "a@-b.co", "a@b-.co", "a b@c.de",
              "a@b@c.de", ".a@b.co", "a.@b.co", "\"a\"@b.co", "a@[1.2.3.4]", "a@b_c.de"] {
        if rest::is_email(s) { print("is_email took ", s); assert(false); }
    }
}

fn main() {
    test_code_points();
    test_date();
    test_date_time();
    test_ascii();
    test_uuid();
    test_email();
    print("test_check: ok");
}
