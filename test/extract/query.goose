// Query parameters: rest::query, rest::query_int, and rest::query_bool,
// decoded, missing, and each failure's answer, and rest::require.
import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let t = "/p?q=a+b%26c&page=3&on=true&off=false&empty&bad=x&big=99999999999999999999";
    expect::same(expect::body_of(says(get(t)) { cx =>
        let q, has_q = rest::query(cx, "q");
        let page, has_page = rest::query_int(cx, "page");
        let on, has_on = rest::query_bool(cx, "on");
        let off, has_off = rest::query_bool(cx, "off");
        let e, has_e = rest::query(cx, "empty");
        let n, has_n = rest::query_int(cx, "none");
        str(q, "|", page, "|", on, has_on, "|", off, has_off, "|", e, has_e, "|", n, has_n)
    }), "a b&c|3|truetrue|falsetrue|true|0false");
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "bad"); v }), bad("bad: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "big"); v }), bad("big: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "empty"); v }),
                 bad("empty: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = rest::query_bool(cx, "page"); v }),
                 bad("page: boolean"));
    expect::same(expect::body_of(says(get(t)) { cx =>
        let v, has = rest::query(cx, "none");
        rest::require(cx, "none", has);
        v
    }), bad("none: required"));
    print("query parameters: ok");
}
