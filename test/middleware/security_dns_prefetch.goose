import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-DNS-Prefetch-Control", "off", "");
    print("security headers DNS prefetch: ok");
}
