// rest::text, rest::json, and rest::empty, byte for byte.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import expect from "../";
import common;

fn main() {
    answers(GET, "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 2\r\n\r\nok") { cx =>
        rest::text(cx, 200, "ok");
    };
    answers(GET, "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Length: 31\r\n\r\n",
                 "{\"id\":7,\"name\":\"goose \\\"one\\\"\"}") { cx =>
        rest::json(cx, 201, Project { id: 7, name: "goose \"one\"" });
    };
    answers(GET, "HTTP/1.1 204 No Content\r\n\r\n") { cx => rest::empty(cx, 204); };
    answers(GET, "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\n\r\n") { cx => rest::empty(cx, 202); };
    print("rest::text, rest::json, and rest::empty: ok");
}
