import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    print("detail: ", problems::member(problems::body(400, "name: \"required\"\n\\"), "detail"));
    print("empty detail omitted: ", problems::member(problems::body(404), "detail").len == 0);
}
