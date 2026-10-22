import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Permissions-Policy", "", "");
    print("security headers permissions policy: ok");
}
