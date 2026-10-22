import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let statuses: i32[13] = [400, 401, 403, 404, 405, 413, 415, 500, 501, 502, 503, 504, 499];
    for status in statuses {
        print(status, ": ", problems::member(problems::body(status), "title"));
    }
}
