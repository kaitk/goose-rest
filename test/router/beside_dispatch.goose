// Hand-written routes before api::dispatch, one on a path of its own and
// one on a path the schema has, which dispatch answers with their Allow.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.4.2";
import rest from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;
import common;

fn beside(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "PUT", "/uploads/:name") {
            rest::route(cx) { t(cx, str("upload ", rest::param(cx, "name"))); };
        } else if rest::on(cx, "POST", "/v1/files/:id/content") {
            t(cx, "post_file_content");
        } else {
            api::dispatch(cx);
        }
    };
}

fn answer_beside(text: const u8[:]) -> u8[>..] {
    return rest::serve_one(text) { cx => beside(cx) };
}

fn main() {
    let not_allowed = "HTTP/1.1 405 Method Not Allowed\r\nAllow: ";
    let json = "\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}";
    expect::same(expect::body_of(answer_beside(request("PUT", "/uploads/logo.png"))), "upload logo.png", "PUT");
    expect::same(answer_beside(request("GET", "/uploads/logo.png")), str(not_allowed, "PUT", json), "GET");
    expect::same(answer_beside(request("OPTIONS", "/uploads/logo.png")), "HTTP/1.1 204 No Content\r\nAllow: PUT\r\n\r\n",
                 "OPTIONS");
    expect::same(expect::body_of(answer_beside(request("POST", "/v1/files/7/content"))), "post_file_content", "POST");
    expect::same(expect::body_of(answer_beside(request("GET", "/v1/files/7/content"))), "get_file_content 7",
                 "generated GET");
    expect::same(answer_beside(request("DELETE", "/v1/files/7/content")), str(not_allowed, "POST, GET, HEAD, PUT", json),
                 "DELETE");
    expect::same(answer_beside(request("OPTIONS", "/v1/files/7/content")),
                 "HTTP/1.1 204 No Content\r\nAllow: POST, GET, HEAD, PUT\r\n\r\n", "OPTIONS of both");
    // Without hand-written routes on the path, dispatch answers alone.
    expect::same(answer_beside(request("DELETE", "/health")), str(not_allowed, "GET, HEAD", json), "generated only");
    expect::same(expect::status_of(answer_beside(request("GET", "/uploads"))), "HTTP/1.1 404 Not Found", "404");
    print("hand-written routes beside api::dispatch: ok");
}
