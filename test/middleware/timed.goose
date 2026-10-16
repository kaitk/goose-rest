// rest::timed: the Server-Timing field, its value padded to a fixed width,
// and nothing added when nothing was written.
import std;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let out = answer(expect::request("GET", "/")) { cx => rest::timed(cx, false) { rest::text(cx, 200, "ok"); }; };
    let head = "HTTP/1.1 200 OK\r\nServer-Timing: app;dur=";
    expect::same(out[..head.len], head);
    let rest_at = find(out, "\r\nContent-Type");
    // The value, padded with spaces to a fixed width.
    assert(rest_at - head.len == 12);
    let padded = out[head.len..rest_at];
    let dur = padded[..find(padded, " ")];
    for c in padded[dur.len..] { assert(c == ' '); }
    let dot = find(dur, ".");
    assert(dot >= 1 && dur.len == dot + 4);
    for c, i in dur { assert(i == dot || c >= '0' && c <= '9'); }
    expect::same(out[rest_at + 2..], OK);
    // Nothing written, nothing added.
    expect::same(answer(expect::request("GET", "/")) { cx => rest::timed(cx, false) {}; }, "");
    print("rest::timed: ok");
}
