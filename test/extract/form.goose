// Form fields, rest::form, rest::form_int, and rest::form_bool, through
// rest::serve_one: decoded, the first of a repeated field, each failure's
// answer, the media type, and a body past the read buffer, gathered.
import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";
import common;

let FORM = "Content-Type: application/x-www-form-urlencoded; charset=utf-8\r\n";

// What rest::serve_one answers to a form body with the text of what F
// extracted.
fn form_says<F>(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    return rest::serve_one(post(content_type, body)) { cx => rest::text(cx, 200, str(F(cx))); };
}

fn main() {
    let b = "name=wild+goose%21&n=3&on=true&n=4&empty&bad=x&esc=%zz";
    expect::same(expect::body_of(form_says(FORM, b) { cx =>
        let name, has_name = rest::form(cx, "name");
        let n, has_n = rest::form_int(cx, "n");
        let on, has_on = rest::form_bool(cx, "on");
        let e, has_e = rest::form(cx, "empty");
        let none, has_none = rest::form(cx, "none");
        str(name, "|", n, "|", on, has_on, "|", e, has_e, "|", none, has_none)
    }), "wild goose!|3|truetrue|true|false");
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = rest::form_int(cx, "bad"); v }),
                 bad("bad: integer"));
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = rest::form_bool(cx, "n"); v }),
                 bad("n: boolean"));
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = rest::form(cx, "esc"); v }),
                 bad("esc: encoding"));
    expect::same(expect::body_of(form_says(FORM, b) { cx =>
        let v, has = rest::form(cx, "none");
        rest::require(cx, "none", has);
        v
    }), bad("none: required"));
    expect::same(expect::body_of(form_says("Content-Type: application/x-www-form-urlencoded\r\n", "a=1") { cx =>
        let v, has = rest::form_int(cx, "a"); v
    }), "1");
    let out = form_says("Content-Type: application/json\r\n", "a=1") { cx => let v, has = rest::form(cx, "a"); v };
    expect::same(out, str("HTTP/1.1 415 Unsupported Media Type\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                          "{\"error\":\"unsupported_media_type\"}"));
    expect::same(expect::status_of(form_says("", "a=1") { cx => let v, has = rest::form(cx, "a"); v }),
                 "HTTP/1.1 415 Unsupported Media Type");
    // A body past the read buffer is gathered, and the route runs again.
    var long = str("pad=");
    for i in 20000 { long.push('x'); }
    long.append("&name=last");
    var runs = 0;
    expect::same(expect::body_of(form_says(FORM, long) { cx =>
        runs++;
        let v, has = rest::form(cx, "name");
        v
    }), "last");
    assert(runs == 2);
    print("form fields: ok");
}
