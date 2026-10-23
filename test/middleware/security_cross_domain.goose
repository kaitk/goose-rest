import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-Permitted-Cross-Domain-Policies", "none", "none");
    print("security headers cross-domain policy: ok");
}
