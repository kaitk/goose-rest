// plod::route: an answer, a failure from two calls below it, one with text
// the failure owns, and a failure after an answer, which leaves it.
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 31\r\n\r\n",
                 "{\"id\":7,\"name\":\"goose \\\"one\\\"\"}") { cx =>
        plod::route(cx) { plod::json(cx, 200, load(cx, 7)); };
    };
    // Two calls down, and with text owned by the failure.
    answers(GET, "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 29\r\n\r\n",
                 "{\"error\":\"project_not_found\"}") { cx =>
        plod::route(cx) { plod::json(cx, 200, load(cx, 0)); };
    };
    answers(GET, "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: 24\r\n\r\n",
                 "{\"error\":\"forbidden_13\"}") { cx =>
        plod::route(cx) { plod::json(cx, 200, load(cx, 13)); };
    };
    answers(GET, "HTTP/1.1 409 Conflict\r\nContent-Type: application/json\r\nContent-Length: 17\r\n\r\n",
                 "{\"error\":\"taken\"}") { cx =>
        plod::route(cx) { plod::fail(cx, 409, "taken"); };
    };
    // The first answer wins: a failure after one leaves it as it is.
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 5\r\n\r\n",
                 "first") { cx =>
        plod::route(cx) {
            plod::text(cx, 200, "first");
            plod::fail(cx, 409, "taken");
        };
    };
    print("plod::route and plod::fail: ok");
}
