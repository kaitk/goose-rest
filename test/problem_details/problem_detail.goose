import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    print("detail: ", problems::member(problems::body(400, "name: \"required\"\n\\"), "detail"));
    print("empty detail omitted: ", problems::member(problems::body(404), "detail").len == 0);
}
