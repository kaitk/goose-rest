// Form fields, plod::form, plod::form_int, and plod::form_bool, through
// plod::serve_one: decoded, the first of a repeated field, each failure's
// answer, the media type, and a body past the read buffer, gathered.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import common;

let FORM = "Content-Type: application/x-www-form-urlencoded; charset=utf-8\r\n";

// What plod::serve_one answers to a form body with the text of what F
// extracted.
fn form_says<F>(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    return plod::serve_one(post(content_type, body)) { cx => plod::text(cx, 200, str(F(cx))); };
}

fn main() {
    let b = "name=wild+goose%21&n=3&on=true&n=4&empty&bad=x&esc=%zz";
    expect::same(expect::body_of(form_says(FORM, b) { cx =>
        let name, has_name = plod::form(cx, "name");
        let n, has_n = plod::form_int(cx, "n");
        let on, has_on = plod::form_bool(cx, "on");
        let e, has_e = plod::form(cx, "empty");
        let none, has_none = plod::form(cx, "none");
        str(name, "|", n, "|", on, has_on, "|", e, has_e, "|", none, has_none)
    }), "wild goose!|3|truetrue|true|false");
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = plod::form_int(cx, "bad"); v }),
                 bad("bad: integer"));
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = plod::form_bool(cx, "n"); v }),
                 bad("n: boolean"));
    expect::same(expect::body_of(form_says(FORM, b) { cx => let v, has = plod::form(cx, "esc"); v }),
                 bad("esc: encoding"));
    expect::same(expect::body_of(form_says(FORM, b) { cx =>
        let v, has = plod::form(cx, "none");
        plod::require(cx, "none", has);
        v
    }), bad("none: required"));
    expect::same(expect::body_of(form_says("Content-Type: application/x-www-form-urlencoded\r\n", "a=1") { cx =>
        let v, has = plod::form_int(cx, "a"); v
    }), "1");
    let out = form_says("Content-Type: application/json\r\n", "a=1") { cx => let v, has = plod::form(cx, "a"); v };
    expect::same(out, str("HTTP/1.1 415 Unsupported Media Type\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                          "{\"error\":\"unsupported_media_type\"}"));
    expect::same(expect::status_of(form_says("", "a=1") { cx => let v, has = plod::form(cx, "a"); v }),
                 "HTTP/1.1 415 Unsupported Media Type");
    // A body past the read buffer is gathered, and the route runs again.
    var long = str("pad=");
    for i in 20000 { long.push('x'); }
    long.append("&name=last");
    var runs = 0;
    expect::same(expect::body_of(form_says(FORM, long) { cx =>
        runs++;
        let v, has = plod::form(cx, "name");
        v
    }), "last");
    assert(runs == 2);
    print("form fields: ok");
}
