// plod::cors: a request without Origin, an allowed origin, an error inside,
// a refused origin, a preflight, an OPTIONS that isn't one, any origin
// with credentials (answered "*", without them), and a listed origin with credentials.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";
import expect from "../";
import common;

// A handler behind CORS: /missing fails 404 inside it.
fn with_cors(text: const u8[:]) -> u8[>..] {
    return answer(text) { cx =>
        plod::cors(cx, plod::Cors { origins: "https://a.example https://b.example", expose: "X-Total", .. }) {
            plod::route(cx) {
                guard http::path_of(cx.req.target) != "/missing" else { plod::fail(cx, 404, "not_found"); }
                plod::text(cx, 200, "ok");
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
        plod::cors(cx, plod::Cors { origins: "*", credentials: true, .. }) { plod::text(cx, 200, "ok"); };
    };
    expect::same(any, str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nVary: Origin\r\n", OK));
    let any_preflight = answer(expect::request("OPTIONS", "/",
                                               "Origin: https://c.example\r\nAccess-Control-Request-Method: PUT\r\n")) { cx =>
        plod::cors(cx, plod::Cors { origins: "*", credentials: true, .. }) { plod::text(cx, 200, "ok"); };
    };
    expect::same(any_preflight, str("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\n",
                     "Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE\r\n",
                     "Access-Control-Allow-Headers: Authorization, Content-Type\r\nAccess-Control-Max-Age: 600\r\n",
                     "Vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers\r\n\r\n"));
    let listed = answer(expect::request("GET", "/", "Origin: https://c.example\r\n")) { cx =>
        plod::cors(cx, plod::Cors { origins: "https://c.example", credentials: true, .. }) { plod::text(cx, 200, "ok"); };
    };
    expect::same(listed, str("HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: https://c.example\r\n",
                             "Access-Control-Allow-Credentials: true\r\nVary: Origin\r\n", OK));
    print("plod::cors: ok");
}
