// rest::cors: a request without Origin, an allowed origin, an error inside,
// a refused origin, a preflight, an OPTIONS that isn't one, and any origin
// with credentials.
import std;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "../../";
import expect from "../";
import common;

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

fn main() {
    expect::same(with_cors(expect::request("GET", "/")), str("HTTP/1.1 200 OK\r\n", OK));
    expect::same(with_cors(expect::request("GET", "/", "Origin: https://b.example\r\n")),
                 str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://b.example\r\n",
                     "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    expect::same(with_cors(expect::request("GET", "/missing", "Origin: https://a.example\r\n")),
                 str("HTTP/1.1 404 Not Found\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
                     "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n",
                     "Content-Type: application/json\r\nContent-Length: 21\r\n\r\n{\"error\":\"not_found\"}"));
    expect::same(with_cors(expect::request("GET", "/", "Origin: https://a.example.evil\r\n")),
                 str("HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n",
                     "{\"error\":\"origin_not_allowed\"}"));
    expect::same(with_cors(expect::request("OPTIONS", "/",
                                           "Origin: https://a.example\r\nAccess-Control-Request-Method: PUT\r\n")),
                 str("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
                     "Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE\r\n",
                     "Access-Control-Allow-Headers: Authorization, Content-Type\r\nAccess-Control-Max-Age: 600\r\n",
                     "Vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\r\n\r\n"));
    // OPTIONS without Access-Control-Request-Method isn't a preflight.
    expect::same(with_cors(expect::request("OPTIONS", "/", "Origin: https://a.example\r\n")),
                 str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://a.example\r\n",
                     "Access-Control-Expose-Headers: X-Total\r\nVary: Origin\r\n", OK));
    let any = answer(expect::request("GET", "/", "Origin: https://c.example\r\n")) { cx =>
        rest::cors(cx, rest::Cors { origins: "*", credentials: true, .. }) { rest::text(cx, 200, "ok"); };
    };
    expect::same(any, str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://c.example\r\n",
                          "Access-Control-Allow-Credentials: true\r\nVary: Origin\r\n", OK));
    print("rest::cors: ok");
}
