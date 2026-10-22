import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-DNS-Prefetch-Control", "off", "");
    print("security headers DNS prefetch: ok");
}
