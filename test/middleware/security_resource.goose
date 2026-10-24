import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Resource-Policy", "same-origin", "");
    print("security headers resource policy: ok");
}
