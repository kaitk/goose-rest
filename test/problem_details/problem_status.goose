import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
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
