import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-DNS-Prefetch-Control", "off", "");
    print("security headers DNS prefetch: ok");
}
