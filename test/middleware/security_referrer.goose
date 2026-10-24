import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Referrer-Policy", "strict-origin-when-cross-origin", "");
    print("security headers referrer policy: ok");
}
