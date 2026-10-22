import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    print("at: ", problems::member(problems::body(400, "", 0), "at"));
    print("negative at omitted: ", problems::member(problems::body(404), "at").len == 0);
}
