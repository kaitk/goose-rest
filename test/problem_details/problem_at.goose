import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    print("at: ", problems::member(problems::body(400, "", 0), "at"));
    print("negative at omitted: ", problems::member(problems::body(404), "at").len == 0);
}
