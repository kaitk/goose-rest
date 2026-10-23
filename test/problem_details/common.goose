namespace problems;

import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import expect from "../";

struct St { use: u8 = 0 }

fn plod::error_body(body: u8[>..]&, st: const problems::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    plod::problem_body(body, status, code, detail, at);
}

fn plod::error_type(st: const problems::St&) {
    "Content-Type: application/problem+json\r\nContent-Length: "
}

fn body(status: i32, detail: const u8[:] = "", at: i64 = -1) -> u8[>..] {
    var out: u8[>..] = [];
    plod::problem_body(out, status, "custom_error", detail, at);
    return out;
}

// A member's JSON value as written, or empty for an absent member.
fn member(text: const u8[:], name: const u8[:]) -> u8[>..] {
    var r = json::reader(text);
    var value: u8[>..] = [];
    json::each_member(r) { key =>
        let from = r.pos;
        json::skip(r);
        if key == name { value.append(trim(text[from..r.pos])); }
    };
    assert(json::finish(r));
    return value;
}

fn answer(status: i32) -> u8[>..] {
    var app = plod::NoState { .. };
    return plod::serve_one(expect::request("GET", "/missing"), app, St { .. }) { cx =>
        plod::fail(cx, status, "custom_error");
    };
}
