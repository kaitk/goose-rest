// Multipart fields, rest::part, rest::part_int, rest::part_bool, and
// rest::file_part, through rest::serve_one: text, files with and without a
// content type, a quoted boundary, a field after a file, a missing field, and
// each failure's answer.
import std;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "../../";
import expect from "../";
import common;

let TYPE = "Content-Type: multipart/form-data; boundary=XyZ\r\n";

// A part's lines, in a body whose boundary is XyZ.
fn field(name: const u8[:], value: const u8[:]) -> u8[>..] {
    return str("--XyZ\r\nContent-Disposition: form-data; name=\"", name, "\"\r\n\r\n", value, "\r\n");
}

fn upload(name: const u8[:], filename: const u8[:], kind: const u8[:], data: const u8[:]) -> u8[>..] {
    var s = str("--XyZ\r\nContent-Disposition: form-data; name=\"", name, "\"; filename=\"", filename, "\"\r\n");
    if kind.len > 0 { s.append("Content-Type: "); s.append(kind); s.append("\r\n"); }
    s.append("\r\n");
    s.append(data);
    s.append("\r\n");
    return s;
}

fn says_of<F>(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    return rest::serve_one(post(content_type, body)) { cx => rest::text(cx, 200, str(F(cx))); };
}

fn main() {
    var b = str("preamble\r\n");
    b.append(field("name", "wild goose"));
    b.append(field("n", "3"));
    b.append(field("on", "true"));
    b.append(field("empty", ""));
    b.append(upload("pic", "a b.png", "image/png", "PNG\r\n--XyY\r\n!!"));
    b.append(upload("raw", "r.bin", "", "raw"));
    b.append(field("after", "last"));
    b.append(field("name", "second"));
    b.append("--XyZ--\r\nepilogue");
    expect::same(expect::body_of(says_of(TYPE, b) { cx =>
        let name, has_name = rest::part(cx, "name");
        let n, has_n = rest::part_int(cx, "n");
        let on, has_on = rest::part_bool(cx, "on");
        let e, has_e = rest::part(cx, "empty");
        let none, has_none = rest::part(cx, "none");
        str(name, "|", n, "|", on, has_on, "|", e.len, has_e, "|", none.len, has_none)
    }), "wild goose|3|truetrue|0true|0false");
    expect::same(expect::body_of(says_of(TYPE, b) { cx =>
        let data, filename, kind, has = rest::file_part(cx, "pic");
        str(data.len, "|", filename, "|", kind, "|", has)
    }), "14|a b.png|image/png|true");
    expect::same(expect::body_of(says_of(TYPE, b) { cx =>
        let data, filename, kind, has = rest::file_part(cx, "raw");
        str(data, "|", filename, "|", kind, "|", has)
    }), "raw|r.bin|application/octet-stream|true");
    expect::same(expect::body_of(says_of(TYPE, b) { cx =>
        let data, filename, kind, has = rest::file_part(cx, "name");
        let none, nf, nk, found = rest::file_part(cx, "none");
        str(data, "|", filename.len, "|", kind, "|", has, "|", found)
    }), "wild goose|0|application/octet-stream|true|false");
    expect::same(expect::body_of(says_of(TYPE, b) { cx => let v, has = rest::part(cx, "after"); v }), "last");
    expect::same(expect::body_of(says_of(TYPE, b) { cx => let v, has = rest::part_int(cx, "name"); v }),
                 bad("name: integer"));
    expect::same(expect::body_of(says_of(TYPE, b) { cx => let v, has = rest::part_bool(cx, "n"); v }),
                 bad("n: boolean"));
    expect::same(expect::body_of(says_of(TYPE, b) { cx =>
        let v, has = rest::part(cx, "none");
        rest::require(cx, "none", has);
        v
    }), bad("none: required"));

    // A quoted boundary, and the body starting at its first delimiter.
    let quoted = "Content-Type: multipart/form-data; boundary=\"XyZ\"\r\n";
    var q = field("a", "1");
    q.append("--XyZ--\r\n");
    expect::same(expect::body_of(says_of(quoted, q) { cx => let v, has = rest::part_int(cx, "a"); v }), "1");

    // Another media type, or no usable boundary: 415.
    let wrong = says_of("Content-Type: application/x-www-form-urlencoded\r\n", "a=1") { cx => let v, has = rest::part(cx, "a"); v };
    expect::same(wrong, str("HTTP/1.1 415 Unsupported Media Type\r\nContent-Type: application/json\r\nContent-Length: 34\r\n\r\n",
                            "{\"error\":\"unsupported_media_type\"}"));
    for t in ["", "Content-Type: multipart/form-data\r\n", "Content-Type: multipart/form-data; boundary=\r\n",
              "Content-Type: multipart/form-data; boundary=a\"b\r\n"] {
        expect::same(expect::status_of(says_of(t, q) { cx => let v, has = rest::part(cx, "a"); v }),
                     "HTTP/1.1 415 Unsupported Media Type");
    }

    // A body that isn't multipart: 400.
    let bodies = [
        "no delimiter at all",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1",                  // never closed
        "--XyZjunk\r\n",                                                                // a delimiter not followed by CRLF
        "--XyZ\r\nnot a field line\r\n\r\n1\r\n--XyZ--\r\n",
        "--XyZ\r\nContent-Type: text/plain\r\n\r\n1\r\n--XyZ--\r\n",                    // no Content-Disposition
    ];
    for m in bodies {
        let out = says_of(TYPE, m) { cx => let v, has = rest::part(cx, "a"); v };
        expect::same(expect::status_of(out), "HTTP/1.1 400 Bad Request");
        expect::same(expect::body_of(out), bad("body: multipart"));
    }
    // A part found before the damage is read; the rest isn't.
    var early = field("a", "1");
    early.append("--XyZ\r\nbroken");
    expect::same(expect::body_of(says_of(TYPE, early) { cx => let v, has = rest::part(cx, "a"); v }), "1");

    // A body past the read buffer is gathered, and the route runs again.
    var long = str("--XyZ\r\nContent-Disposition: form-data; name=\"pad\"\r\n\r\n");
    for i in 20000 { long.push('x'); }
    long.append("\r\n");
    long.append(field("name", "last"));
    long.append("--XyZ--\r\n");
    var runs = 0;
    expect::same(expect::body_of(says_of(TYPE, long) { cx =>
        runs++;
        let v, has = rest::part(cx, "name");
        v
    }), "last");
    assert(runs == 2);
    print("multipart fields: ok");
}
