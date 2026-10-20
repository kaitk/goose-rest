import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Referrer-Policy", "strict-origin-when-cross-origin", "");
    print("security headers referrer policy: ok");
}
