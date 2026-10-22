import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import expect from "../";
import common;

enum Jobs { Read }

fn main() {
    let box, e = http::mail_open(4, 256);
    http::exit_on_error(e);
    var lane = rest::lane_of<Jobs>(box, 1 as u8);
    let wakes = [rest::Wake { timeout: true, .. }];
    let out = rest::serve_one(expect::request("GET", "/slow"), lane, problems::St { .. }, wakes) { cx =>
        rest::ask(cx, cx.app, Jobs.Read);
    };
    assert(find(out, "Content-Type: application/problem+json\r\n") >= 0);
    print(expect::status_of(out));
    print("Content-Type: application/problem+json");
    print(expect::body_of(out));
    http::mail_close(box);
}
