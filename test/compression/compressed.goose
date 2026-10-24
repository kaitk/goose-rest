// plod::compressed: a large answer compressed in each coding the client
// takes, at the default level and at a level of the program's.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import compress from "github.com/kaitk/goose-compress@v0.1.4";
import plod from "../../";
import plod.compression;
import expect from "../";
import common;

fn main() {
    let t = records();
    let gz = coded(compress::GZIP, 1);
    assert(gz.len < t.len / 4);
    expect::same(served(expect::request("GET", "/big", GZIP)),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz.len, "\r\n\r\n", gz));
    let zs = coded(compress::ZSTD, 1);
    expect::same(served(expect::request("GET", "/big", "Accept-Encoding: gzip, deflate, br, zstd\r\n")),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: zstd\r\nContent-Length: ", zs.len, "\r\n\r\n", zs));
    let zl = coded(compress::ZLIB, 1);
    expect::same(served(expect::request("GET", "/big", "Accept-Encoding: deflate\r\n")),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: deflate\r\nContent-Length: ", zl.len, "\r\n\r\n", zl));
    // A level of the program's.
    let gz9 = coded(compress::GZIP, 9);
    let nine = plod::serve_one(expect::request("GET", "/big", GZIP)) { cx =>
        plod::compressed(cx, http::Compression { level: 9, .. }) { cx => plod::json_bytes(cx, 200, records()); };
    };
    expect::same(nine, str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Encoding: gzip\r\nContent-Length: ", gz9.len,
                           "\r\n\r\n", gz9));
    print("answers compressed: ok");
}
