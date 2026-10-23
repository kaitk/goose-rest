import std;
import json;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    var app = plod::NoState { .. };
    let request = expect::request("POST", "/projects", "Content-Length: 16\r\n");
    let out = plod::serve_one(str(request, "{\"name\":\"goose\"}"), app, problems::St { .. }) { cx =>
        var r = json::reader(plod::body(cx));
        var scratch: u8[>..] = [];
        let project = api::read_project(r, scratch);
        if !json::finish(r) { plod::fail_body(cx, r); }
        plod::json(cx, 200, project);
    };
    print(expect::status_of(out));
    print(expect::body_of(out));
}
