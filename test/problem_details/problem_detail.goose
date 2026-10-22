import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    print("detail: ", problems::member(problems::body(400, "name: \"required\"\n\\"), "detail"));
    print("empty detail omitted: ", problems::member(problems::body(404), "detail").len == 0);
}
