// Checks the generated JSON readers call: a string's length in code points,
// and the string formats the generator supports.
namespace plod;

import std;

// The code points in s, or -1 when s isn't UTF-8 (RFC 3629). JSON Schema's
// minLength and maxLength count code points, and a string that passes a
// maxLength of n fits a u8[..4n].
fn code_points(s: const u8[:]) -> i64 {
    var n = 0;
    var i = 0;
    while i < s.len {
        let c = s[i];
        if c < 0x80 { i++; n++; continue; }
        var need = 0;
        var lo: u8 = 0x80;
        var hi: u8 = 0xBF;
        if c >= 0xC2 && c <= 0xDF { need = 1; }
        else if c == 0xE0 { need = 2; lo = 0xA0; }
        else if c == 0xED { need = 2; hi = 0x9F; }
        else if c >= 0xE1 && c <= 0xEF { need = 2; }
        else if c == 0xF0 { need = 3; lo = 0x90; }
        else if c >= 0xF1 && c <= 0xF3 { need = 3; }
        else if c == 0xF4 { need = 3; hi = 0x8F; }
        else { return -1; }
        guard i + need < s.len else { return -1; }
        guard s[i + 1] >= lo && s[i + 1] <= hi else { return -1; }
        for k in 2..need + 1 {
            guard s[i + k] >= 0x80 && s[i + k] <= 0xBF else { return -1; }
        }
        i += need + 1;
        n++;
    }
    return n;
}

// The number written by s[at..at + n] in decimal digits, or -1 if any isn't one.
fn digits_at(s: const u8[:], at: i64, n: i64) -> i64 {
    guard at + n <= s.len else { return -1; }
    var v = 0;
    for i in at..at + n {
        let c = s[i];
        guard c >= '0' && c <= '9' else { return -1; }
        v = v * 10 + (c - '0');
    }
    return v;
}

// RFC 3339's full-date, YYYY-MM-DD, with a day that exists in its month.
fn is_date(s: const u8[:]) -> bool {
    guard s.len == 10 && s[4] == '-' && s[7] == '-' else { return false; }
    let y = digits_at(s, 0, 4);
    let m = digits_at(s, 5, 2);
    let d = digits_at(s, 8, 2);
    guard y >= 0 && m >= 1 && m <= 12 && d >= 1 else { return false; }
    let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    let days = match m {
        2 => if leap { 29 } else { 28 },
        4, 6, 9, 11 => 30,
        _ => 31,
    };
    return d <= days;
}

// RFC 3339's date-time: a full-date, T, hh:mm:ss with an optional fraction,
// then Z or an offset. A leap second, :60, is allowed, as RFC 3339 allows it.
fn is_date_time(s: const u8[:]) -> bool {
    guard s.len >= 20 && is_date(s[..10]) && (s[10] == 'T' || s[10] == 't') else { return false; }
    guard s[13] == ':' && s[16] == ':' else { return false; }
    let h = digits_at(s, 11, 2);
    let mi = digits_at(s, 14, 2);
    let sec = digits_at(s, 17, 2);
    guard h >= 0 && h <= 23 && mi >= 0 && mi <= 59 && sec >= 0 && sec <= 60 else { return false; }
    var i = 19;
    if s[i] == '.' {
        i++;
        let from = i;
        while i < s.len && s[i] >= '0' && s[i] <= '9' { i++; }
        guard i > from else { return false; }
    }
    guard i < s.len else { return false; }
    if s[i] == 'Z' || s[i] == 'z' { return i + 1 == s.len; }
    guard (s[i] == '+' || s[i] == '-') && i + 6 == s.len && s[i + 3] == ':' else { return false; }
    let oh = digits_at(s, i + 1, 2);
    let om = digits_at(s, i + 4, 2);
    return oh >= 0 && oh <= 23 && om >= 0 && om <= 59;
}

// Whether every byte of s is below 0x80, for format ascii.
fn is_ascii(s: const u8[:]) -> bool {
    for c in s { guard c < 0x80 else { return false; } }
    return true;
}

// A UUID in RFC 9562's text form: 8-4-4-4-12 hex digits, either case.
fn is_uuid(s: const u8[:]) -> bool {
    guard s.len == 36 else { return false; }
    for c, i in s {
        if i == 8 || i == 13 || i == 18 || i == 23 {
            guard c == '-' else { return false; }
        } else {
            guard (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') else { return false; }
        }
    }
    return true;
}

// An address of the form RFC 5321 delivers to, simplified: a local part of 1
// to 64 bytes with no space, control character, '"', '@', '(', ')', ',',
// ':', ';', '<', '>', '[', '\' or ']', then '@', then a domain of two or more
// dot-separated labels of letters, digits and inner hyphens, each 1 to 63
// bytes. Quoted local parts and address literals are refused.
fn is_email(s: const u8[:]) -> bool {
    let at = position(s, '@');
    guard at >= 1 && at <= 64 && s.len <= 254 else { return false; }
    for c in s[..at] {
        guard c > ' ' && c < 0x7F && c != '"' && c != '(' && c != ')' && c != ',' && c != ':' &&
            c != ';' && c != '<' && c != '>' && c != '[' && c != '\\' && c != ']' else { return false; }
    }
    guard s[0] != '.' && s[at - 1] != '.' else { return false; }
    let domain = s[at + 1..];
    var labels = 0;
    var start = 0;
    for i in 0..domain.len + 1 {
        if i == domain.len || domain[i] == '.' {
            let n = i - start;
            guard n >= 1 && n <= 63 && domain[start] != '-' && domain[i - 1] != '-' else { return false; }
            labels++;
            start = i + 1;
        } else {
            let c = domain[i];
            guard (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' else { return false; }
        }
    }
    return labels >= 2;
}
