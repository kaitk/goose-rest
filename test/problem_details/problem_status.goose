import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
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
