// plod::files: a file with its type, a directory's index.html, a directory
// without one, paths that leave the directory, precompressed copies by
// Accept-Encoding, HEAD, and a range. Writes test_files/ in the working
// directory.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import common;

// The response to a request for target under /static/, with fields.
fn fetch(target: const u8[:], fields: const u8[:] = "", method: const u8[:] = "GET") -> u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    return plod::serve_one(str(method, " ", target, " HTTP/1.1\r\n", fields, "\r\n"), app, St { .. }) { cx =>
        if plod::resumed(cx) {
            resume(cx.state.use, cx);
        } else {
            plod::routes(cx) { cx =>
                plod::get(cx, "/static/*name") { plod::files(cx, "test_files", "name", cx.state.file, Use.Download); };
            };
        }
    };
}

// The value of the response field name, or "-" for none.
fn field_of(out: const u8[:], name: const u8[:]) -> const u8[:] {
    let at = find(out, str("\r\n", name, ": "));
    guard at >= 0 && at < find(out, "\r\n\r\n") else { return "-"; }
    let from = at + name.len + 4;
    return out[from..from + find(out[from..], "\r\n")];
}

fn show(what: const u8[:], out: const u8[:]) {
    print(what, ": ", expect::status_of(out), " | ", field_of(out, "Content-Type"), " | ",
          field_of(out, "Content-Encoding"), " | ", field_of(out, "Vary"), " | ", expect::body_of(out));
}

fn main() {
    assert(make_dir("test_files"));
    assert(make_dir("test_files/docs"));
    assert(make_dir("test_files/empty"));
    assert(write_file("test_files/app.js", "let plain = 1;\n"));
    assert(write_file("test_files/app.js.gz", "gzip bytes"));
    assert(write_file("test_files/app.js.br", "brotli bytes"));
    assert(write_file("test_files/style.css", "body {}\n"));
    assert(write_file("test_files/docs/index.html", "<h1>docs</h1>\n"));
    assert(write_file("secret.txt", "secret\n"));

    show("file", fetch("/static/style.css"));
    // Without its '/', a directory is 404: its index's relative links would miss.
    show("directory without /", fetch("/static/docs"));
    show("directory/", fetch("/static/docs/"));
    show("root without index", fetch("/static/"));
    show("no index", fetch("/static/empty/"));
    show("no file", fetch("/static/none.js"));
    // The router refuses dot segments, escaped or not, before any route.
    show("..", fetch("/static/../secret.txt"));
    show("%2e%2e", fetch("/static/%2e%2e/secret.txt"));
    // An escaped slash or backslash reaches plod::files, which refuses them.
    show("%2f..", fetch("/static/docs%2f..%2f..%2fsecret.txt"));
    show("%5c", fetch("/static/docs%5c..%5c..%5csecret.txt"));
    show("plain", fetch("/static/app.js"));
    show("gzip", fetch("/static/app.js", "Accept-Encoding: gzip\r\n"));
    show("br", fetch("/static/app.js", "Accept-Encoding: gzip, br\r\n"));
    show("identity", fetch("/static/app.js", "Accept-Encoding: identity\r\n"));
    let head = fetch("/static/app.js", "Accept-Encoding: gzip\r\n", "HEAD");
    show("HEAD", head);
    print("HEAD length: ", field_of(head, "Content-Length"));
    let part = fetch("/static/app.js", "Range: bytes=4-8\r\n");
    show("range", part);
    print("range: ", field_of(part, "Content-Range"));
    assert(field_of(part, "ETag") != "-" && field_of(part, "Last-Modified") != "-");

    for name in ["app.js", "app.js.gz", "app.js.br", "style.css", "docs/index.html"] {
        assert(delete_file(str("test_files/", name)));
    }
    assert(delete_dir("test_files/docs") && delete_dir("test_files/empty") && delete_dir("test_files"));
    assert(delete_file("secret.txt"));
}
