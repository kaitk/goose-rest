// The generated router's JSON body: read and given its handler, its media
// type, and the reader's errors.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;
import common;

fn post(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    let text = str("POST /v1/projects HTTP/1.1\r\nHost: x\r\nCookie: session=1\r\n", content_type,
                   "Content-Length: ", body.len, "\r\n\r\n", body);
    return answer(text, true);
}

fn main() {
    expect::same(expect::status_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\"}")),
                 "HTTP/1.1 201 Created", "201");
    expect::same(expect::body_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\"}")),
                 "create_project goose", "201");
    expect::same(expect::body_of(post("", "{\"name\": \"goose\"}")), "{\"error\":\"unsupported_media_type\"}", "415");
    expect::same(expect::body_of(post("Content-Type: application/json\r\n", "{\"name\": \"\"}")),
                 "{\"error\":\"invalid_body\",\"detail\":\"name: minLength\",\"at\":12}", "minLength");
    expect::same(expect::body_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\", \"x\": 1}")),
                 "{\"error\":\"invalid_body\",\"detail\":\"unknown member\",\"at\":22}", "unknown member");
    print("the generated router's JSON body: ok");
}
