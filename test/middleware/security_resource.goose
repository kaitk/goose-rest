import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Resource-Policy", "same-origin", "");
    print("security headers resource policy: ok");
}
