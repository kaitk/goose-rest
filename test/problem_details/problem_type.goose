import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let body = problems::body(404);
    print("type: ", problems::member(body, "type"));
    print("instance omitted: ", problems::member(body, "instance").len == 0);
}
