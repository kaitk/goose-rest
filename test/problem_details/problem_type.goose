import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let body = problems::body(404);
    print("type: ", problems::member(body, "type"));
    print("instance omitted: ", problems::member(body, "instance").len == 0);
}
