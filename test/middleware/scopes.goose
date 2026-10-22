// plod::scope: prefix scopes, nested, with 404, 405, and OPTIONS across
// them, an escaped prefix, and the paths that aren't in one.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import common;

// /v1 holds /projects, its root, and /admin, which holds /users; /health is
// outside, after /v1, which owns the paths under it.
fn scoped(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        plod::routes(cx) { cx =>
            plod::scope(cx, "/v1") {
                plod::get(cx, "") { plod::text(cx, 200, "v1"); };
                plod::get(cx, "/projects") { plod::text(cx, 200, "list"); };
                plod::post(cx, "/projects") { plod::text(cx, 200, "create"); };
                plod::scope(cx, "/admin") {
                    plod::delete(cx, "/users/:id") { plod::text(cx, 200, str("delete ", plod::param(cx, "id"))); };
                };
            };
            plod::get(cx, "/health") { plod::text(cx, 200, "health"); };
        };
    };
}

fn main() {
    expect::same(expect::body_of(scoped(expect::request("GET", "/v1/projects"))), "list");
    expect::same(expect::body_of(scoped(expect::request("POST", "/v1/projects"))), "create");
    expect::same(expect::body_of(scoped(expect::request("GET", "/v1"))), "v1");
    expect::same(expect::body_of(scoped(expect::request("GET", "/%761/projects"))), "list");
    expect::same(expect::body_of(scoped(expect::request("DELETE", "/v1/admin/users/7"))), "delete 7");
    expect::same(expect::body_of(scoped(expect::request("GET", "/health"))), "health");
    expect::same(scoped(expect::request("DELETE", "/v1/projects")),
                 str("HTTP/1.1 405 Method Not Allowed\r\nAllow: GET, HEAD, POST\r\nContent-Type: application/json\r\n",
                     "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    expect::same(scoped(expect::request("OPTIONS", "/v1/projects")),
                 "HTTP/1.1 204 No Content\r\nAllow: GET, HEAD, POST\r\n\r\n");
    expect::same(scoped(expect::request("GET", "/v1/admin/users/7")),
                 str("HTTP/1.1 405 Method Not Allowed\r\nAllow: DELETE\r\nContent-Type: application/json\r\n",
                     "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    let missing = str("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                      "{\"error\":\"not_found\"}");
    expect::same(scoped(expect::request("GET", "/v1/nope")), missing);
    expect::same(scoped(expect::request("GET", "/v1/")), missing);
    expect::same(scoped(expect::request("GET", "/v10/projects")), missing);
    expect::same(scoped(expect::request("GET", "/v1/admin")), missing);
    expect::same(expect::status_of(scoped(expect::request("GET", "/v1/../health"))), "HTTP/1.1 400 Bad Request");
    expect::same(expect::status_of(scoped(expect::request("BREW", "/v1/projects"))), "HTTP/1.1 501 Not Implemented");
    print("plod::scope: ok");
}
