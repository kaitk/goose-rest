// Outside plod::compressed, plod::begin's response goes as written, and
// inside it plod::file's does. Writes test_compression.tmp in the working
// directory.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import compress from "github.com/kaitk/goose-compress@v0.1.2";
import plod from "../../";
import plod.compression;
import expect from "../";
import common;

fn main() {
    var calls: u8[>..] = [];
    var app = App { calls: calls };
    let plain = plod::serve_one(str("GET /export HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        plod::compressed(cx) { cx => cx.state.sent = 1; };
        plod::begin(cx, 200, "text/csv", 2, Use.None);
        plod::send(cx, "ok");
        plod::end(cx);
    };
    expect::same(plain, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/csv\r\n\r\nok");
    let path = "test_compression.tmp";
    let data = records();
    assert(write_file(path, data));
    let file = plod::serve_one(str("GET /f HTTP/1.1\r\n", GZIP, "\r\n"), app, St { .. }) { cx =>
        if plod::resumed(cx) {
            resume(cx.state.use, cx);
        } else {
            plod::compressed(cx) { cx => plod::file(cx, path, cx.state.file, Use.Download, "application/json"); };
        }
    };
    assert(find(file, "Content-Encoding") < 0);
    expect::same(file[find(file, "\r\n\r\n") + 4..], data);
    assert(delete_file(path));
    print("responses outside plod::compressed, and files inside: ok");
}
