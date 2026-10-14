// The middleware and scopes, byte for byte: CORS for a simple request, a
// refused origin, a preflight, and an error inside; the bearer check; the
// Server-Timing field; and prefix scopes with 404, 405, and OPTIONS across
// them. scripts/test-unit.sh runs this through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "../";

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// Calls H with a context for text, a whole request, and returns what it
// wrote.
fn answer<H>(text: const u8[:]) -> u8[>..] {
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var out: u8[>..] = [];
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    var scratch: u8[>..] = [];
    var app = rest::NoState { .. };
    var none = rest::NoRouter { .. };
    var cx = rest::Cx<rest::NoState, rest::NoState, rest::NoRouter> { req: req, body: text[req.len..],
                                       out: http::Reply { buf: out, common: "", keep_alive: keep, minor: 1,
                                       head: req.method == "HEAD", stream: st }, state: state, app: app,
                                       scratch: scratch, router: none };
    H(cx);
    return out;
}

fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}

let OK = "Content-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok";

// A handler behind CORS: /missing fails 404 inside it.
fn with_cors(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        rest::cors(cx, rest::Cors { origins: "https://a.example https://b.example", expose: "X-Total", .. }) {
            rest::route(cx) {
                guard http::path_of(cx.req.target) != "/missing" else { rest::fail(cx, 404, "not_found"); }
                rest::text(cx, 200, "ok");
            };
        };
    };
}

fn test_cors() {
    same(with_cors(request("GET", "/")), str("HTTP/1.1 200 OK\r\n", OK));
    same(with_cors(request("GET", "/", "Origin: https://b.example\r\n")),
         str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://b.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    same(with_cors(request("GET", "/missing", "Origin: https://a.example\r\n")),
         str("HTTP/1.1 404 Not Found\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n",
             "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    same(with_cors(request("GET", "/", "Origin: https://a.example.evil\r\n")),
         str("HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n",
             "{\"error\":\"origin_not_allowed\"}"));
    same(with_cors(request("OPTIONS", "/", "Origin: https://a.example\r\nAccess-Control-Request-Method: PUT\r\n")),
         str("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE\r\n",
             "Access-Control-Allow-Headers: Authorization, Content-Type\r\nAccess-Control-Max-Age: 600\r\n",
             "Vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\r\n\r\n"));
    // OPTIONS without Access-Control-Request-Method isn't a preflight.
    same(with_cors(request("OPTIONS", "/", "Origin: https://a.example\r\n")),
         str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
             "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    let any = answer(request("GET", "/", "Origin: https://c.example\r\n")) { cx =>
        rest::cors(cx, rest::Cors { origins: "*", credentials: true, .. }) { rest::text(cx, 200, "ok"); };
    };
    same(any, str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://c.example\r\n",
                  "Access-Control-Allow-Credentials: true\r\nVary: Origin\r\n", OK));
}

fn with_bearer(fields: const u8[:]) -> u8[>..] {
    return answer(request("GET", "/", fields)) { cx =>
        rest::route(cx) {
            rest::bearer(cx) { token =>
                guard token == "t0k" else { rest::invalid_token(cx); }
                rest::text(cx, 200, "ok");
            };
        };
    };
}

fn test_bearer() {
    same(with_bearer("Authorization: Bearer t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    same(with_bearer("Authorization: bearer   t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    let none = "HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer\r\nContent-Type: application/json\r\nContent-Length: 27\r\n\r\n{\"error\":\"unauthenticated\"}";
    same(with_bearer(""), none);
    same(with_bearer("Authorization: Basic YTpi\r\n"), none);
    same(with_bearer("Authorization: Bearer\r\n"), none);
    same(with_bearer("Authorization: Bearer nope\r\n"),
         str("HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer error=\"invalid_token\"\r\n",
             "Content-Type: application/json\r\nContent-Length: 25\r\n\r\n{\"error\":\"invalid_token\"}"));
}

fn test_timed() {
    let out = answer(request("GET", "/")) { cx => rest::timed(cx, false) { rest::text(cx, 200, "ok"); }; };
    let head = "HTTP/1.1 200 OK\r\nServer-Timing: app;dur=";
    same(out[..head.len], head);
    let rest_at = find(out, "\r\nContent-Type");
    // The value, padded with spaces to a fixed width.
    assert(rest_at - head.len == 12);
    let padded = out[head.len..rest_at];
    let dur = padded[..find(padded, " ")];
    for c in padded[dur.len..] { assert(c == ' '); }
    let dot = find(dur, ".");
    assert(dot >= 1 && dur.len == dot + 4);
    for c, i in dur { assert(i == dot || c >= '0' && c <= '9'); }
    same(out[rest_at + 2..], OK);
    // Nothing written, nothing added.
    same(answer(request("GET", "/")) { cx => rest::timed(cx, false) {}; }, "");
}

// Scopes over an if chain: /v1 holds /projects, its root, and /admin, which
// holds /users; /health is outside.
fn scoped(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        rest::routes(cx) { cx =>
            if rest::scope(cx, "/v1") {
                if rest::on(cx, "GET", "") { rest::text(cx, 200, "v1"); }
                else if rest::on(cx, "GET", "/projects") { rest::text(cx, 200, "list"); }
                else if rest::on(cx, "POST", "/projects") { rest::text(cx, 200, "create"); }
                else if rest::scope(cx, "/admin") {
                    if rest::on(cx, "DELETE", "/users/:id") {
                        rest::route(cx) { rest::text(cx, 200, str("delete ", rest::param(cx, "id"))); };
                    }
                    else { rest::otherwise(cx); }
                }
                else { rest::otherwise(cx); }
            } else if rest::on(cx, "GET", "/health") {
                rest::text(cx, 200, "health");
            } else {
                rest::otherwise(cx);
            }
        };
    };
}

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn test_scopes() {
    same(body_of(scoped(request("GET", "/v1/projects"))), "list");
    same(body_of(scoped(request("POST", "/v1/projects"))), "create");
    same(body_of(scoped(request("GET", "/v1"))), "v1");
    same(body_of(scoped(request("GET", "/%761/projects"))), "list");
    same(body_of(scoped(request("DELETE", "/v1/admin/users/7"))), "delete 7");
    same(body_of(scoped(request("GET", "/health"))), "health");
    same(scoped(request("DELETE", "/v1/projects")),
         str("HTTP/1.1 405 Method Not Allowed\r\nAllow: GET, HEAD, POST\r\nContent-Type: application/json\r\n",
             "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    same(scoped(request("OPTIONS", "/v1/projects")), "HTTP/1.1 204 No Content\r\nAllow: GET, HEAD, POST\r\n\r\n");
    same(scoped(request("GET", "/v1/admin/users/7")),
         str("HTTP/1.1 405 Method Not Allowed\r\nAllow: DELETE\r\nContent-Type: application/json\r\n",
             "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}"));
    let missing = str("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                      "{\"error\":\"not_found\"}");
    same(scoped(request("GET", "/v1/nope")), missing);
    same(scoped(request("GET", "/v1/")), missing);
    same(scoped(request("GET", "/v10/projects")), missing);
    same(scoped(request("GET", "/v1/admin")), missing);
    same(status_of(scoped(request("GET", "/v1/../health"))), "HTTP/1.1 400 Bad Request");
    same(status_of(scoped(request("BREW", "/v1/projects"))), "HTTP/1.1 501 Not Implemented");
}

fn main() {
    test_cors();
    test_bearer();
    test_timed();
    test_scopes();
    print("test_middleware: ok");
}
