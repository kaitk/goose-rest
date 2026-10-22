import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    let statuses: i32[13] = [400, 401, 403, 404, 405, 413, 415, 500, 501, 502, 503, 504, 499];
    for status in statuses {
        print(status, ": ", problems::member(problems::body(status), "title"));
    }
}
