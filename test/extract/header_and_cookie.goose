// plod::header and plod::cookie, by name in any case for a header and in
// its own for a cookie, plod::int_of, and each failure's answer.
import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let f = "X-Request-Id: r-1\r\nX-Count: 12\r\nCookie: a=1; sid=\"s 2\"\r\n";
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let id, has_id = plod::header(cx, "x-request-id");
        let n, has_n = plod::header(cx, "X-Count");
        let sid, has_sid = plod::cookie(cx, "sid");
        let no, has_no = plod::cookie(cx, "SID");
        str(id, "|", plod::int_of(cx, n, "X-Count") + 1, "|", sid, "|", has_no)
    }), "r-1|13|s 2|false");
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let v, has = plod::header(cx, "X-Request-Id");
        plod::int_of(cx, v, "X-Request-Id")
    }), bad("X-Request-Id: integer"));
    let out = says(get("/", f)) { cx => let v, has = plod::header(cx, "X-Api-Key"); plod::require(cx, "X-Api-Key", has); v };
    expect::same(out, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 60\r\n\r\n",
                          bad("X-Api-Key: required")));
    expect::same(expect::body_of(says(get("/", f)) { cx =>
        let v, has = plod::cookie(cx, "session");
        plod::require(cx, "session", has);
        v
    }), bad("session: required"));
    print("headers and cookies: ok");
}
