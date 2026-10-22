import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Permissions-Policy", "", "");
    print("security headers permissions policy: ok");
}
