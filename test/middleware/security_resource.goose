import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import security_common;

fn main() {
    security_baseline_field("Cross-Origin-Resource-Policy", "same-origin", "");
    print("security headers resource policy: ok");
}
