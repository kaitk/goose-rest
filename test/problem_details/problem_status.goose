import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
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
