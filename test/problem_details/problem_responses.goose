import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import common;

fn show<H>(method: const u8[:], target: const u8[:]) {
    var app = plod::NoState { .. };
    let out = plod::serve_one(expect::request(method, target), app, problems::St { .. }) { cx => H(cx); };
    print(out);
}

fn main() {
    show("GET", "/missing") { cx =>
        plod::routes(cx) { cx => plod::get(cx, "/found") { plod::text(cx, 200, "ok"); }; };
    };
    show("POST", "/found") { cx =>
        plod::routes(cx) { cx => plod::get(cx, "/found") { plod::text(cx, 200, "ok"); }; };
    };
    show("GET", "/private") { cx => plod::bearer(cx) { token => plod::text(cx, 200, token); }; };
    show("GET", "/private") { cx => plod::invalid_token(cx); };
    show("GET", "/bad") { cx => plod::fail_param(cx, "id: integer"); };
    show("GET", "/domain") { cx => plod::fail(cx, 409, "project_exists"); };

    let ordinary = plod::serve_one(expect::request("GET", "/ordinary")) { cx =>
        plod::fail(cx, 404, "not_found");
    };
    print(ordinary);
}
