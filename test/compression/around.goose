// rest::timed outside fills its field in the head compressed copies, and
// rest::cors inside adds its fields to the answer compressed.
import std;
import http from "github.com/kaitk/goose-http@v0.3.3";
import compress from "github.com/kaitk/goose-compress@v0.1.0";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    let out = rest::serve_one(expect::request("GET", "/big", str(GZIP, "Origin: https://a.example\r\n"))) { cx =>
        rest::timed(cx, false) {
            rest::compressed(cx) { cx =>
                rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
                    rest::json_bytes(cx, 200, records());
                };
            };
        };
    };
    let gz = coded(compress::GZIP, 1);
    let head = "HTTP/1.1 200 OK\r\nServer-Timing: app;dur=";
    expect::same(out[..head.len], head);
    assert(out[head.len] >= '0' && out[head.len] <= '9');
    expect::same(out[head.len + 14..],
                 str("Access-Control-Allow-Origin: https://a.example\r\nVary: Origin\r\n", JSON_HEAD,
                     "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
    print("rest::compressed between rest::timed and rest::cors: ok");
}
