import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    let statuses: i32[3] = [404, 422, 499];
    for status in statuses {
        let out = problems::answer(status);
        print(trim(expect::status_of(out)));
        print("status: ", problems::member(expect::body_of(out), "status"));
    }
}
