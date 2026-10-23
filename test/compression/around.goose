// plod::timed outside fills its field in the head compressed copies, and
// plod::cors inside adds its fields to the answer compressed.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import compress from "github.com/kaitk/goose-compress@v0.1.4";
import plod from "../../";
import plod.compression;
import expect from "../";
import common;

fn main() {
    let out = plod::serve_one(expect::request("GET", "/big", str(GZIP, "Origin: https://a.example\r\n"))) { cx =>
        plod::timed(cx, false) {
            plod::compressed(cx) { cx =>
                plod::cors(cx, plod::Cors { origins: "https://a.example", .. }) {
                    plod::json_bytes(cx, 200, records());
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
    print("plod::compressed between plod::timed and plod::cors: ok");
}
