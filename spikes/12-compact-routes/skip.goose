// Skip-based routing, from the package on branch short-routes-skip: a
// matched rest::get marks the router taken and returns as any block does.
// Each case prints its answer, or what the program's own middleware saw.
// Run it from this folder with goose.
import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest.compression;
import .compact;

let CORS = rest::Cors { origins: "https://a.example", .. };

var seen: u8[>..];

// A program's own middleware that works after its block, untyped.
inline fn audited<F>(cx) {
    F();
    seen.append(str("audit ", cx.out.stream.status, ";"));
}

// A program's own middleware that adds a field, without rest::scoped and
// with it.
inline fn branded<F>(cx) {
    let common = cx.out.common;
    cx.out.common = "X-Brand: acme\r\n";
    F();
    cx.out.common = common;
}

inline fn branded_scoped<F>(cx) {
    let common = cx.out.common;
    cx.out.common = "X-Brand: acme\r\n";
    rest::scoped(cx) { F(); };
    cx.out.common = common;
}

fn admin(cx) -> bool {
    let v, has = rest::header(cx, "X-Admin");
    return has;
}

fn handle(cx, sec: const rest::SecurityFields&) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        rest::get(cx, "/silent") {};
        if admin(cx) { rest::get(cx, "/admin") { rest::text(cx, 200, "admin"); }; }
        if compact::scope(cx, "/c") {
            rest::cors(cx, CORS) {
                rest::get(cx, "/x/:id") { rest::text(cx, 200, str("cors ", rest::param_int(cx, "id"))); };
                rest::post(cx, "/x/:id") { rest::text(cx, 201, "posted"); };
            };
        } else if compact::scope(cx, "/s") {
            rest::security_headers(cx, sec) { rest::get(cx, "/x") { rest::text(cx, 200, "secure"); }; };
        } else if compact::scope(cx, "/t") {
            rest::timed(cx, false) { rest::get(cx, "/x") { rest::text(cx, 200, "timed"); }; };
        } else if compact::scope(cx, "/z") {
            rest::compressed(cx) { cx =>
                rest::get(cx, "/x") { rest::text(cx, 200, str_repeat("zipped ", 200)); };
                rest::delete(cx, "/x") { rest::text(cx, 200, "deleted"); };
            };
        } else if compact::scope(cx, "/a") {
            audited(cx) { rest::get(cx, "/x") { rest::text(cx, 200, "audited"); }; };
        } else if compact::scope(cx, "/b") {
            branded(cx) { rest::get(cx, "/x") { rest::fail(cx, 409, "conflict"); }; };
        } else if compact::scope(cx, "/bs") {
            branded_scoped(cx) { rest::get(cx, "/x") { rest::fail(cx, 409, "conflict"); }; };
        } else if compact::scope(cx, "/p") {
            rest::get(cx, "/y") { rest::text(cx, 200, "plain"); };
        }
        // The block form owns its prefix.
        rest::scope(cx, "/q") {
            rest::get(cx, "/y") { rest::text(cx, 200, "block"); };
            rest::scope(cx, "/r") { rest::post(cx, "/y") { rest::text(cx, 201, "nested"); }; };
        };
        // After the scopes, against the path a scope narrowed: taken
        // requests skip it.
        rest::get(cx, "/x") { rest::text(cx, 200, "after the scopes"); };
        seen.append("end of block;");
    };
}

fn str_repeat(s: const u8[:], n: i64) -> u8[>..] {
    var out: u8[>..] = [];
    for i in n { out.append(s); }
    return out;
}

// The status line, the fields, and the body's length.
fn shown(out: const u8[:]) -> u8[>..] {
    let end = find(out, "\r\n\r\n");
    guard end >= 0 else { return str("[", out, "]"); }
    var s = str(out[..end]);
    s.append(str("\r\n  (body ", out.len - end - 4, " bytes)"));
    return s;
}

fn main() {
    let sec = rest::prepare_security_headers(rest::security_api());
    let origin = "Origin: https://a.example\r\n";
    let cases = [
        ["GET", "/health", ""], ["HEAD", "/health", ""], ["GET", "/silent", ""],
        ["GET", "/admin", ""], ["GET", "/admin", "X-Admin: 1\r\n"],
        ["GET", "/c/x/7", origin], ["GET", "/c/x/abc", origin], ["GET", "/c/nope", origin],
        ["DELETE", "/c/x/7", origin], ["GET", "/c/x/7", "Origin: https://evil.example\r\n"],
        ["GET", "/s/x", ""], ["GET", "/s/nope", ""], ["GET", "/t/nope", ""],
        ["GET", "/z/x", "Accept-Encoding: gzip\r\n"], ["POST", "/z/x", ""], ["GET", "/z/nope", ""],
        ["GET", "/a/x", ""], ["GET", "/a/nope", ""], ["GET", "/b/x", ""], ["GET", "/bs/x", ""], ["GET", "/bs/nope", ""],
        ["GET", "/p/y", ""], ["GET", "/p/x", ""], ["GET", "/q/y", ""], ["GET", "/q/x", ""],
        ["POST", "/q/r/y", ""], ["GET", "/q/r/y", ""], ["GET", "/q/r/x", ""], ["GET", "/x", ""], ["GET", "/nope", ""],
    ];
    for c in cases {
        seen.clear();
        let out = rest::serve_one(str(c[0], " ", c[1], " HTTP/1.1\r\n", c[2], "\r\n")) { cx => handle(cx, sec) };
        let with: u8[>..] = if c[2].len > 0 { str(" (", c[2][..c[2].len - 2], ")") } else { "" };
        print(c[0], " ", c[1], with, " -> ", shown(out), "\r\n  seen: ", seen);
    }
}
