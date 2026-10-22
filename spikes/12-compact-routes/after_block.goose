// Design A's rest::get, from the package on branch short-routes, inside
// middleware that works after its block, inside rest::routes. rest::get
// leaves through return from routes, past that work: timed's Server-Timing
// stays blank, and compressed's answer never leaves its buffer, so
// serve_one answers 500. cors answers right here, and skips only keeping its
// fields for an answer at a later call. A failure inside a scope's cors,
// /f/x, is answered after cors has unwound, without its fields. Run it from
// this folder with goose.
import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest.compression;
import .compact;

fn handle(cx) {
    rest::routes(cx) { cx =>
        if compact::scope(cx, "/t") {
            rest::timed(cx, false) { rest::get(cx, "/x") { rest::text(cx, 200, "timed"); }; };
        } else if compact::scope(cx, "/c") {
            rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
                rest::get(cx, "/x") { rest::text(cx, 200, "cors"); };
            };
        } else if compact::scope(cx, "/f") {
            rest::cors(cx, rest::Cors { origins: "https://a.example", .. }) {
                rest::get(cx, "/x") { rest::fail(cx, 404, "not_found"); };
            };
        } else if compact::scope(cx, "/z") {
            rest::compressed(cx) { cx => rest::get(cx, "/x") { rest::text(cx, 200, "zipped"); }; };
        }
    };
}

fn main() {
    for t in ["/t/x", "/c/x", "/f/x", "/z/x"] {
        let out = rest::serve_one(str("GET ", t, " HTTP/1.1\r\nOrigin: https://a.example\r\nAccept-Encoding: gzip\r\n\r\n")) { cx => handle(cx) };
        print(t, " -> [", out, "]");
    }
}
