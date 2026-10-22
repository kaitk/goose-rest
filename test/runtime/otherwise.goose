// rest::otherwise: 404, 405 with Allow, OPTIONS, 501, and a program's own
// http::router given to it.
import std;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    answers(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 21\r\n\r\n",
                 "{\"error\":\"not_found\"}") { cx =>
        rest::routes(cx) { cx => if rest::on(cx, "GET", "/q") { rest::text(cx, 200, "q"); } else { rest::otherwise(cx); } };
    };
    answers(GET, "HTTP/1.1 405 Method Not Allowed\r\nAllow: POST, PUT\r\nContent-Type: application/json\r\n",
                 "Content-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}") { cx =>
        rest::routes(cx) { cx =>
            if rest::on(cx, "POST", "/p") { rest::text(cx, 200, "p"); }
            else if rest::on(cx, "PUT", "/p") { rest::text(cx, 200, "p"); }
            else { rest::otherwise(cx); }
        };
    };
    answers("OPTIONS /p HTTP/1.1\r\nHost: x\r\n\r\n", "HTTP/1.1 204 No Content\r\nAllow: GET, HEAD\r\n\r\n") { cx =>
        rest::routes(cx) { cx => if rest::on(cx, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx); } };
    };
    answers("BREW /p HTTP/1.1\r\nHost: x\r\n\r\n",
            "HTTP/1.1 501 Not Implemented\r\nContent-Type: application/json\r\nContent-Length: 27\r\n\r\n",
            "{\"error\":\"not_implemented\"}") { cx =>
        rest::routes(cx) { cx => if rest::on(cx, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx); } };
    };
    // A program's own http::router, with rest::otherwise given it.
    answers("GET /a/../p HTTP/1.1\r\nHost: x\r\n\r\n",
            "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 20\r\n\r\n",
            "{\"error\":\"bad_path\"}") { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/p") { rest::text(cx, 200, "p"); } else { rest::otherwise(cx, r); }
    };
    print("rest::otherwise: ok");
}
