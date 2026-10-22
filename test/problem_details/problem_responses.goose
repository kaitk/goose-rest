import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";
import expect from "../";
import common;

fn show<H>(method: const u8[:], target: const u8[:]) {
    var app = rest::NoState { .. };
    let out = rest::serve_one(expect::request(method, target), app, problems::St { .. }) { cx => H(cx); };
    print(out);
}

fn main() {
    show("GET", "/missing") { cx =>
        rest::routes(cx) { cx => rest::get(cx, "/found") { rest::text(cx, 200, "ok"); }; };
    };
    show("POST", "/found") { cx =>
        rest::routes(cx) { cx => rest::get(cx, "/found") { rest::text(cx, 200, "ok"); }; };
    };
    show("GET", "/private") { cx => rest::bearer(cx) { token => rest::text(cx, 200, token); }; };
    show("GET", "/private") { cx => rest::invalid_token(cx); };
    show("GET", "/bad") { cx => rest::fail_param(cx, "id: integer"); };
    show("GET", "/domain") { cx => rest::fail(cx, 409, "project_exists"); };

    let ordinary = rest::serve_one(expect::request("GET", "/ordinary")) { cx =>
        rest::fail(cx, 404, "not_found");
    };
    print(ordinary);
}
