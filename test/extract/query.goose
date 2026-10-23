// Query parameters: plod::query, plod::query_int, and plod::query_bool,
// decoded, missing, and each failure's answer, and plod::require.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let t = "/p?q=a+b%26c&page=3&on=true&off=false&empty&bad=x&big=99999999999999999999";
    expect::same(expect::body_of(says(get(t)) { cx =>
        let q, has_q = plod::query(cx, "q");
        let page, has_page = plod::query_int(cx, "page");
        let on, has_on = plod::query_bool(cx, "on");
        let off, has_off = plod::query_bool(cx, "off");
        let e, has_e = plod::query(cx, "empty");
        let n, has_n = plod::query_int(cx, "none");
        str(q, "|", page, "|", on, has_on, "|", off, has_off, "|", e, has_e, "|", n, has_n)
    }), "a b&c|3|truetrue|falsetrue|true|0false");
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = plod::query_int(cx, "bad"); v }), bad("bad: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = plod::query_int(cx, "big"); v }), bad("big: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = plod::query_int(cx, "empty"); v }),
                 bad("empty: integer"));
    expect::same(expect::body_of(says(get(t)) { cx => let v, has = plod::query_bool(cx, "page"); v }),
                 bad("page: boolean"));
    expect::same(expect::body_of(says(get(t)) { cx =>
        let v, has = plod::query(cx, "none");
        plod::require(cx, "none", has);
        v
    }), bad("none: required"));
    print("query parameters: ok");
}
