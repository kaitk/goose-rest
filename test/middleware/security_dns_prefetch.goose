import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("X-DNS-Prefetch-Control", "off", "");
    print("security headers DNS prefetch: ok");
}
