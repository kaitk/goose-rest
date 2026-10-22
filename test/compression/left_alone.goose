// The answers rest::compressed leaves alone: no coding taken, HEAD, a short
// body, an error, a type not worth compressing, a coding already, and no
// body.
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "../../";
import rest.compression;
import expect from "../";
import common;

fn main() {
    let t = records();
    // Vary only: no Accept-Encoding, HEAD, a short body, an error.
    expect::same(served(expect::request("GET", "/big")),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    expect::same(served(expect::request("GET", "/big", "Accept-Encoding: br, identity\r\n")),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n", t));
    expect::same(served(expect::request("HEAD", "/big", GZIP)),
                 str("HTTP/1.1 200 OK\r\n", JSON_HEAD, "Content-Length: ", t.len, "\r\n\r\n"));
    expect::same(served(expect::request("GET", "/small", GZIP)),
                 str("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nVary: Accept-Encoding\r\n",
                     "Content-Length: 2\r\n\r\nok"));
    expect::same(served(expect::request("GET", "/missing", GZIP)),
                 str("HTTP/1.1 404 Not Found\r\n", JSON_HEAD, "Content-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    // As F wrote them: a type not worth compressing, a coding already, no body.
    expect::same(served(expect::request("GET", "/png", GZIP)),
                 str("HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ", t.len, "\r\n\r\n", t));
    expect::same(served(expect::request("GET", "/done", GZIP)),
                 str("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Type: application/json\r\nContent-Length: ",
                     t.len, "\r\n\r\n", t));
    expect::same(served(expect::request("GET", "/empty", GZIP)), "HTTP/1.1 204 No Content\r\n\r\n");
    print("answers left alone: ok");
}
