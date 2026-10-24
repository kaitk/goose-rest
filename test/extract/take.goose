// plod::take, through a program's own from_request and through the one the
// generator writes for api::Project, which reads the JSON body: its media
// type, a body the reader refuses, and trailing input.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

// A program's own extractor, declared into rest so that plod::take finds it.
struct Page { n: i64, size: i64 }

fn plod::from_request(cx, v: const Page?) -> Page {
    let n, has_n = plod::query_int(cx, "page");
    let size, has_size = plod::query_int(cx, "size");
    if has_size && (size < 1 || size > 100) { plod::fail_param(cx, "size: maximum"); }
    return Page { n: if has_n { n } else { 1 }, size: if has_size { size } else { 20 } };
}

let PROJECT = """{"id": 7, "name": "goose", "status": "active", "owner": {"id": 1, "email": "ada@a.example"}, "tags": ["a"], "createdAt": "2026-10-13T00:00:00Z"}""";

fn main() {
    expect::same(expect::body_of(says(get("/?page=2")) { cx => let p = plod::take<Page>(cx); str(p.n, " ", p.size) }),
                 "2 20");
    expect::same(expect::body_of(says(get("/?size=500")) { cx => let p = plod::take<Page>(cx); p.n }),
                 bad("size: maximum"));
    let json = "Content-Type: application/json; charset=utf-8\r\n";
    expect::same(expect::body_of(says(post(json, PROJECT)) { cx =>
        let p = plod::take<api::Project>(cx);
        str(p.id, " ", p.name)
    }), "7 goose");
    let out = says(post("Content-Type: text/plain\r\n", PROJECT)) { cx => plod::take<api::Project>(cx).id };
    expect::same(out, str("HTTP/1.1 415 Unsupported Media Type\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                          "{\"error\":\"unsupported_media_type\"}"));
    expect::same(expect::status_of(says(post("", PROJECT)) { cx => plod::take<api::Project>(cx).id }),
                 "HTTP/1.1 415 Unsupported Media Type");
    expect::same(expect::body_of(says(post(json, "{\"id\": 7}")) { cx => plod::take<api::Project>(cx).id }),
                 "{\"error\":\"invalid_body\",\"detail\":\"name: required\",\"at\":9}");
    expect::same(expect::body_of(says(post(json, str(PROJECT, " 1"))) { cx => plod::take<api::Project>(cx).id }),
                 str("{\"error\":\"invalid_body\",\"detail\":\"trailing input\",\"at\":", PROJECT.len + 1, "}"));
    print("plod::take: ok");
}
