// Outside rest::compressed, rest::begin's response goes as written, and
// inside it rest::file's does. Writes test_compression.tmp in the working
// directory.
import std;
import http from "github.com/kaitk/goose-http@2c5280c76ade5f70f69a80cd68f73b03d5b34252";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    var calls: u8[>..] = [];
    var app = App { calls: calls };
    let plain = rest::serve_one(str("GET /export HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        rest::compressed(cx) { cx => cx.state.sent = 1; };
        rest::begin(cx, 200, "text/csv", 2, Waiting.None);
        rest::send(cx, "ok");
        rest::end(cx);
    };
    expect::same(plain, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/csv\r\n\r\nok");
    let path = "test_compression.tmp";
    let data = records();
    assert(write_file(path, data));
    let file = rest::serve_one(str("GET /f HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::compressed(cx) { cx => rest::file(cx, path, cx.state.file, Waiting.Download, "application/json"); };
        }
    };
    assert(find(file, "Content-Encoding") < 0);
    expect::same(file[find(file, "\r\n\r\n") + 4..], data);
    assert(delete_file(path));
    print("responses outside rest::compressed, and files inside: ok");
}
