import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let body = problems::body(404);
    print("type: ", problems::member(body, "type"));
    print("instance omitted: ", problems::member(body, "instance").len == 0);
}
