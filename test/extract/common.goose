// What the extractors' tests share: a context to call a route with, the
// route that answers with what an extractor read, and the requests.
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";
import expect from "../";

struct St { calls: i64 = 0, user: rest::Once<i64> = rest::Once<i64> { .. } }

// Calls H with a context for text, a whole request, and returns what it
// wrote.
fn answer<H>(text: const u8[:]) -> u8[>..] {
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = St { .. };
    var scratch: u8[>..] = [];
    var app = rest::NoState { .. };
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<St, rest::NoState, rest::NoRouter> { req: req, body: text[req.len..], out: http::Reply {
                            buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: st }, state: state,
                            app: app, scratch: scratch, router: none };
    H(cx);
    return out;
}

fn get(target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str("GET ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

fn post(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    str("POST /p HTTP/1.1\r\nHost: x\r\n", content_type, "Content-Length: ", body.len, "\r\n\r\n", body)
}

// What a route answers that writes the text of what F extracted.
fn says<F>(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx => rest::route(cx) { rest::text(cx, 200, str(F(cx))); }; };
}

fn bad(detail: const u8[:]) -> u8[>..] { str("{\"error\":\"invalid_parameter\",\"detail\":\"", detail, "\"}") }
