import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Embedder-Policy", "", "");
    print("security headers embedder policy: ok");
}
