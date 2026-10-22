import std;
import http from "github.com/kaitk/goose-http@v0.5.1";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-Permitted-Cross-Domain-Policies", "none", "none");
    print("security headers cross-domain policy: ok");
}
