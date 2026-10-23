import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let statuses: i32[13] = [400, 401, 403, 404, 405, 413, 415, 500, 501, 502, 503, 504, 499];
    for status in statuses {
        print(status, ": ", problems::member(problems::body(status), "title"));
    }
}
