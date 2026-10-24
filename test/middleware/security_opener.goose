import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Opener-Policy", "same-origin", "");
    print("security headers opener policy: ok");
}
