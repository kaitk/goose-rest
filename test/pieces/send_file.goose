// rest::file: a file whole in pieces of 64 KB, a range, a 304 for its ETag,
// HEAD, and no file. Writes test_pieces.tmp in the working directory.
import std;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import rest from "../../";
import expect from "../";
import common;

// The file at path, by a GET with fields, the request's own.
fn download(path: const u8[:], fields: const u8[:] = "", method: const u8[:] = "GET") -> u8[>..], u8[>..] {
    var log: u8[>..] = [];
    var app = App { log: log };
    let out = rest::serve_one(str(method, " /f HTTP/1.1\r\n", fields, "\r\n"), app, St { .. }) { cx =>
        if rest::resumed(cx) {
            resume(cx.state.waiting, cx);
        } else {
            rest::file(cx, path, cx.state.file, Waiting.Download);
        }
    };
    return out, log;
}

fn main() {
    let path = "test_pieces.tmp";
    var data: u8[>..] = [];
    for i in 150000 { data.push('a' + (i % 26) as u8); }
    assert(write_file(path, data));
    // In pieces of 64 KB, a MORE each.
    let whole, l1 = download(path);
    expect::same(expect::status_of(whole), "HTTP/1.1 200 OK", "file");
    assert(expect::body_of(whole) == data);
    expect::same(l1, "M M M ", "file's calls");
    // A range: 206, and those bytes.
    let part, l2 = download(path, "Range: bytes=26-30\r\n");
    expect::same(expect::status_of(part), "HTTP/1.1 206 Partial Content", "range");
    expect::same(expect::body_of(part), "abcde", "range's bytes");
    // The ETag it gave: 304, with no calls.
    let at = find(whole, "ETag: ") + 6;
    let tag = whole[at..at + find(whole[at..], "\r\n")];
    let same_tag, l3 = download(path, str("If-None-Match: ", tag, "\r\n"));
    expect::same(expect::status_of(same_tag), "HTTP/1.1 304 Not Modified", "If-None-Match");
    expect::same(l3, "", "304's calls");
    let head, l4 = download(path, "", "HEAD");
    expect::same(expect::body_of(head), "", "HEAD");
    expect::same(l4, "", "HEAD's calls");
    let missing, l5 = download("no-such-file.tmp");
    expect::same(expect::body_of(missing), "{\"error\":\"file_not_found\"}", "no file");
    assert(delete_file(path));
    print("rest::file: ok");
}
