import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Embedder-Policy", "", "");
    print("security headers embedder policy: ok");
}
