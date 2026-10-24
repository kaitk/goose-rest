// plod::fail_body: a body a generated reader refused, with the reader's
// detail and offset.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    let post = "POST /p HTTP/1.1\r\nHost: x\r\nContent-Length: 17\r\n\r\n{\"name\": \"goose\"}";
    answers(post, "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 56\r\n\r\n",
                  "{\"error\":\"invalid_body\",\"detail\":\"id: required\",\"at\":17}") { cx =>
        plod::route(cx) {
            var r = json::reader(cx.body);
            var scratch: u8[>..] = [];
            let p = api::read_project(r, scratch);
            if !json::finish(r) { plod::fail_body(cx, r); }
            plod::json(cx, 200, p);
        };
    };
    print("plod::fail_body: ok");
}
