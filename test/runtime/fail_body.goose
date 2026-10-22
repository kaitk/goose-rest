// rest::fail_body: a body a generated reader refused, with the reader's
// detail and offset.
import std;
import json;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    let post = "POST /p HTTP/1.1\r\nHost: x\r\nContent-Length: 17\r\n\r\n{\"name\": \"goose\"}";
    answers(post, "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 56\r\n\r\n",
                  "{\"error\":\"invalid_body\",\"detail\":\"id: required\",\"at\":17}") { cx =>
        rest::route(cx) {
            var r = json::reader(cx.body);
            var scratch: u8[>..] = [];
            let p = api::read_project(r, scratch);
            if !json::finish(r) { rest::fail_body(cx, r); }
            rest::json(cx, 200, p);
        };
    };
    print("rest::fail_body: ok");
}
