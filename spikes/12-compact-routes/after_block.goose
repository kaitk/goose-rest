// Design A's plod::get, from the package on branch short-routes, inside
// middleware that works after its block, inside plod::routes. plod::get
// leaves through return from routes, past that work: timed's Server-Timing
// stays blank, and compressed's answer never leaves its buffer, so
// serve_one answers 500. cors answers right here, and skips only keeping its
// fields for an answer at a later call. A failure inside a scope's cors,
// /f/x, is answered after cors has unwound, without its fields. Run it from
// this folder with goose.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import compress from "github.com/kaitk/goose-compress@v0.1.4";
import plod.compression;
import .compact;

fn handle(cx) {
    plod::routes(cx) { cx =>
        if compact::scope(cx, "/t") {
            plod::timed(cx, false) { plod::get(cx, "/x") { plod::text(cx, 200, "timed"); }; };
        } else if compact::scope(cx, "/c") {
            plod::cors(cx, plod::Cors { origins: "https://a.example", .. }) {
                plod::get(cx, "/x") { plod::text(cx, 200, "cors"); };
            };
        } else if compact::scope(cx, "/f") {
            plod::cors(cx, plod::Cors { origins: "https://a.example", .. }) {
                plod::get(cx, "/x") { plod::fail(cx, 404, "not_found"); };
            };
        } else if compact::scope(cx, "/z") {
            plod::compressed(cx) { cx => plod::get(cx, "/x") { plod::text(cx, 200, "zipped"); }; };
        }
    };
}

fn main() {
    for t in ["/t/x", "/c/x", "/f/x", "/z/x"] {
        let out = plod::serve_one(str("GET ", t, " HTTP/1.1\r\nOrigin: https://a.example\r\nAccept-Encoding: gzip\r\n\r\n")) { cx => handle(cx) };
        print(t, " -> [", out, "]");
    }
}
