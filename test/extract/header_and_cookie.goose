// rest::header and rest::cookie, by name in any case for a header and in
// its own for a cookie, rest::int_of, and each failure's answer.
import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let f = "X-Request-Id: r-1\r\nX-Count: 12\r\nCookie: a=1; sid=\"s 2\"\r\n";
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let id, has_id = rest::header(cx, "x-request-id");
        let n, has_n = rest::header(cx, "X-Count");
        let sid, has_sid = rest::cookie(cx, "sid");
        let no, has_no = rest::cookie(cx, "SID");
        str(id, "|", rest::int_of(cx, n, "X-Count") + 1, "|", sid, "|", has_no)
    }), "r-1|13|s 2|false");
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let v, has = rest::header(cx, "X-Request-Id");
        rest::int_of(cx, v, "X-Request-Id")
    }), bad("X-Request-Id: integer"));
    let out = says(get("/", f)) { cx => let v, has = rest::header(cx, "X-Api-Key"); rest::require(cx, "X-Api-Key", has); v };
    expect::same(out, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 60\r\n\r\n",
                          bad("X-Api-Key: required")));
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let v, has = rest::cookie(cx, "session");
        rest::require(cx, "session", has);
        v
    }), bad("session: required"));
    print("headers and cookies: ok");
}
