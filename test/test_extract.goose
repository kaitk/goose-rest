// The extractors, byte for byte: path, query, header, and cookie
// parameters, each failure's answer, rest::take through a program's own
// from_request and through the one the generator writes for api::Project,
// which reads the JSON body, and rest::once.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import json;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../";
import .gen.api_gen;

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

struct St { calls: i64 = 0, user: rest::Once<i64> = rest::Once<i64> { .. } }

// Calls H with a context for text, a whole request, and returns what it
// wrote.
fn answer<H>(text: const u8[:]) -> u8[>..] {
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = St { .. };
    var scratch: u8[>..] = [];
    var cx = rest::Cx<St> { req: req, body: text[req.len..], out: http::Reply { buf: out, common: "",
                            keep_alive: keep, minor: 1, head: false, stream: st }, state: state, scratch: scratch };
    H(cx);
    return out;
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn get(target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str("GET ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

// What a route answers that writes the text of what F extracted.
fn says<F>(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx => rest::route(cx) { rest::text(cx, 200, str(F(cx))); }; };
}

fn bad(detail: const u8[:]) -> u8[>..] { str("{\"error\":\"invalid_parameter\",\"detail\":\"", detail, "\"}") }

fn test_path() {
    let p = "/users/7/files/a%20b%2Fc";
    fn on(cx) -> http::Router {
        var r = http::router(cx.req);
        assert(http::on(r, "GET", "/users/:id/files/:name"));
        return r;
    }
    same(body_of(says(get(p)) { cx => let r = on(cx); str(rest::param_int(cx, r, "id"), " ", rest::param(cx, r, "name")) }),
         "7 a b/c");
    same(body_of(says(get("/users/%37/files/x")) { cx => let r = on(cx); rest::param_int(cx, r, "id") }), "7");
    let out = says(get("/users/x7/files/x")) { cx => let r = on(cx); rest::param_int(cx, r, "id") };
    same(out, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 52\r\n\r\n",
                  bad("id: integer")));
    same(body_of(says(get("/users/-/files/x")) { cx => let r = on(cx); rest::param_int(cx, r, "id") }), bad("id: integer"));
    same(body_of(says(get("/users/9223372036854775808/files/x")) { cx => let r = on(cx); rest::param_int(cx, r, "id") }),
         bad("id: integer"));
    same(body_of(says(get("/users/-9223372036854775807/files/x")) { cx => let r = on(cx); rest::param_int(cx, r, "id") }),
         "-9223372036854775807");
}

fn test_query() {
    let t = "/p?q=a+b%26c&page=3&on=true&off=false&empty&bad=x&big=99999999999999999999";
    same(body_of(says(get(t)) { cx =>
        let q, has_q = rest::query(cx, "q");
        let page, has_page = rest::query_int(cx, "page");
        let on, has_on = rest::query_bool(cx, "on");
        let off, has_off = rest::query_bool(cx, "off");
        let e, has_e = rest::query(cx, "empty");
        let n, has_n = rest::query_int(cx, "none");
        str(q, "|", page, "|", on, has_on, "|", off, has_off, "|", e, has_e, "|", n, has_n)
    }), "a b&c|3|truetrue|falsetrue|true|0false");
    same(body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "bad"); v }), bad("bad: integer"));
    same(body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "big"); v }), bad("big: integer"));
    same(body_of(says(get(t)) { cx => let v, has = rest::query_int(cx, "empty"); v }), bad("empty: integer"));
    same(body_of(says(get(t)) { cx => let v, has = rest::query_bool(cx, "page"); v }), bad("page: boolean"));
    same(body_of(says(get(t)) { cx => let v, has = rest::query(cx, "none"); rest::require(cx, "none", has); v }),
         bad("none: required"));
}

fn test_header_and_cookie() {
    let f = "X-Request-Id: r-1\r\nX-Count: 12\r\nCookie: a=1; sid=\"s 2\"\r\n";
    same(body_of(says(get("/", f)) { cx =>
        let id, has_id = rest::header(cx, "x-request-id");
        let n, has_n = rest::header(cx, "X-Count");
        let sid, has_sid = rest::cookie(cx, "sid");
        let no, has_no = rest::cookie(cx, "SID");
        str(id, "|", rest::int_of(cx, n, "X-Count") + 1, "|", sid, "|", has_no)
    }), "r-1|13|s 2|false");
    same(body_of(says(get("/", f)) { cx => let v, has = rest::header(cx, "X-Request-Id"); rest::int_of(cx, v, "X-Request-Id") }),
         bad("X-Request-Id: integer"));
    let out = says(get("/", f)) { cx => let v, has = rest::header(cx, "X-Api-Key"); rest::require(cx, "X-Api-Key", has); v };
    same(out, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 60\r\n\r\n",
                  bad("X-Api-Key: required")));
    same(body_of(says(get("/", f)) { cx => let v, has = rest::cookie(cx, "session"); rest::require(cx, "session", has); v }),
         bad("session: required"));
}

// A program's own extractor, declared into rest so that rest::take finds it.
struct Page { n: i64, size: i64 }

fn rest::from_request(cx, v: const Page?) -> Page {
    let n, has_n = rest::query_int(cx, "page");
    let size, has_size = rest::query_int(cx, "size");
    if has_size && (size < 1 || size > 100) { rest::fail_param(cx, "size: maximum"); }
    return Page { n: if has_n { n } else { 1 }, size: if has_size { size } else { 20 } };
}

fn post(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    str("POST /p HTTP/1.1\r\nHost: x\r\n", content_type, "Content-Length: ", body.len, "\r\n\r\n", body)
}

let PROJECT = """{"id": 7, "name": "goose", "status": "active", "owner": {"id": 1, "email": "ada@a.example"}, "tags": ["a"], "createdAt": "2026-10-13T00:00:00Z"}""";

fn test_take() {
    same(body_of(says(get("/?page=2")) { cx => let p = rest::take<Page>(cx); str(p.n, " ", p.size) }), "2 20");
    same(body_of(says(get("/?size=500")) { cx => let p = rest::take<Page>(cx); p.n }), bad("size: maximum"));
    let json = "Content-Type: application/json; charset=utf-8\r\n";
    same(body_of(says(post(json, PROJECT)) { cx => let p = rest::take<api::Project>(cx); str(p.id, " ", p.name) }),
         "7 goose");
    let out = says(post("Content-Type: text/plain\r\n", PROJECT)) { cx => rest::take<api::Project>(cx).id };
    same(out, str("HTTP/1.1 415 Unsupported Media Type\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                  "{\"error\":\"unsupported_media_type\"}"));
    same(status_of(says(post("", PROJECT)) { cx => rest::take<api::Project>(cx).id }),
         "HTTP/1.1 415 Unsupported Media Type");
    same(body_of(says(post(json, "{\"id\": 7}")) { cx => rest::take<api::Project>(cx).id }),
         "{\"error\":\"invalid_body\",\"detail\":\"name: required\",\"at\":9}");
    same(body_of(says(post(json, str(PROJECT, " 1"))) { cx => rest::take<api::Project>(cx).id }),
         str("{\"error\":\"invalid_body\",\"detail\":\"trailing input\",\"at\":", PROJECT.len + 1, "}"));
}

fn test_once() {
    same(body_of(says(get("/")) { cx =>
        var total = 0;
        for i in 3 {
            total += rest::once(cx.state.user) { cx.state.calls++; 41 };
        }
        str(total, " in ", cx.state.calls, " call")
    }), "123 in 1 call");
}

fn main() {
    test_path();
    test_query();
    test_header_and_cookie();
    test_take();
    test_once();
    print("test_extract: ok");
}
