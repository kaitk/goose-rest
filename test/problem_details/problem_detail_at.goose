import std;
import json;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    var app = rest::NoState { .. };
    let request = expect::request("POST", "/projects", "Content-Length: 16\r\n");
    let out = rest::serve_one(str(request, "{\"name\":\"goose\"}"), app, problems::St { .. }) { cx =>
        var r = json::reader(rest::body(cx));
        var scratch: u8[>..] = [];
        let project = api::read_project(r, scratch);
        if !json::finish(r) { rest::fail_body(cx, r); }
        rest::json(cx, 200, project);
    };
    print(expect::status_of(out));
    print(expect::body_of(out));
}
