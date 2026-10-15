// rest::compressed, byte for byte: a large answer compressed in each coding,
// an error from the route inside it, and the answers it leaves alone.
// scripts/test-unit.sh runs this through TinyCC; scripts/test-examples.sh
// decompresses real answers of examples/plain.
import std;
import http from "github.com/kaitk/goose-http@v0.3.1";
import compress from "github.com/kaitk/goose-compress@2c7df270b88ed8a00e2d73b6f84d50908cf5a558";
import rest from "../";
import rest.compression;

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

// A body that compresses: 2,000 bytes of a repeating record.
fn records() -> u8[>..] {
    var t: u8[>..] = [];
    t.push('[');
    while t.len < 2000 { t.append("{\"id\":1,\"name\":\"Alpha Widget\"},"); }
    t.append("{}]");
    return t;
}

// A handler behind rest::compressed, around the route: /big answers
// records(), /small a short body, /missing fails 404, /png a large image,
// /done an answer that has a Content-Encoding, and /empty 204.
fn handle(cx) {
    rest::compressed(cx) { cx =>
        rest::route(cx) {
            let path = http::path_of(cx.req.target);
            if path == "/big" {
                rest::json_bytes(cx, 200, records());
            } else if path == "/small" {
                rest::text(cx, 200, "ok");
            } else if path == "/png" {
                http::respond(cx.out, 200, "image/png", records());
            } else if path == "/done" {
                http::start(cx.out, 200);
                http::field(cx.out, "Content-Encoding", "gzip");
                http::finish(cx.out, http::JSON, records());
            } else if path == "/empty" {
                rest::empty(cx, 204);
            } else {
                rest::fail(cx, 404, "not_found");
            }
        };
    };
}

fn served(text: const u8[:]) -> u8[>..] {
    return rest::serve_one(text) { cx => handle(cx) };
}

let GZIP = "Accept-Encoding: gzip, br\r\n";
let JSON_HEAD = "Content-Type: application/json\r\nVary: Accept-Encoding\r\n";

fn coded(format: i64, level: i64) -> u8[>..] {
    var z: u8[>..] = [];
    compress::compress(records(), z, format, level);
    return z;
}

fn test_compressed() {
    let t = records();
    let gz = coded(compress::GZIP, 1);
    assert(gz.len < t.len / 4);
    same(served(request("GET", "/big", GZIP)),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
    let zs = coded(compress::ZSTD, 1);
    same(served(request("GET", "/big", "Accept-Encoding: gzip, deflate, br, zstd\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: zstd\r\nContent-Length: ", zs.len, "\r\n\r\n", zs));
    let zl = coded(compress::ZLIB, 1);
    same(served(request("GET", "/big", "Accept-Encoding: deflate\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: deflate\r\nContent-Length: ", zl.len, "\r\n\r\n", zl));
    // A level of the program's.
    let gz9 = coded(compress::GZIP, 9);
    let nine = rest::serve_one(request("GET", "/big", GZIP)) { cx =>
        rest::compressed(cx, http::Compression { level: 9, .. }) { cx => rest::json_bytes(cx, 200, records()); };
    };
    same(nine, str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz9.len,
                   "\r\n\r\n", gz9));
}

fn test_left_alone() {
    let t = records();
    // Vary only: no Accept-Encoding, HEAD, a short body, an error.
    same(served(request("GET", "/big")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("GET", "/big", "Accept-Encoding: br, identity\r\n")),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("HEAD", "/big", GZIP)),
         str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n"));
    same(served(request("GET", "/small", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nVary: Accept-Encoding\r\n",
             "Content-Length: 2\r\n\r\nok"));
    same(served(request("GET", "/missing", GZIP)),
         str("HTTP/1.1 404 Not Found\r\n", JSON_HEAD, "Content-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    // As F wrote them: a type not worth compressing, a coding already, no body.
    same(served(request("GET", "/png", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ", t.len, "\r\n\r\n", t));
    same(served(request("GET", "/done", GZIP)),
         str("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Type: application/json\r\nContent-Length: ", t.len,
             "\r\n\r\n", t));
    same(served(request("GET", "/empty", GZIP)), "HTTP/1.1 204 No Content\r\n\r\n");
}

// rest::timed outside fills its field in the head compressed copies, and
// rest::cors inside adds its fields to the answer compressed.
fn test_around() {
    let out = rest::serve_one(request("GET", "/big", str(GZIP, "Origin: https://a.example\r\n"))) { cx =>
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
    same(out[..head.len], head);
    assert(out[head.len] >= '0' && out[head.len] <= '9');
    same(out[head.len + 14..],
         str("Access-Control-Allow-Origin: https://a.example\r\nVary: Origin\r\n", JSON_HEAD,
             "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
}

fn main() {
    test_compressed();
    test_left_alone();
    test_around();
    print("test_compression: ok");
}
