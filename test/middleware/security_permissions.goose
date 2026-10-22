import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Permissions-Policy", "", "");
    print("security headers permissions policy: ok");
}
