// rest::bearer: a token in any case of the scheme, none, another scheme, an
// empty one, and one the program refuses.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import expect from "../";
import common;

fn with_bearer(fields: const u8[:]) -> u8[>..] {
    return answer(expect::request("GET", "/", fields)) { cx =>
        rest::route(cx) {
            rest::bearer(cx) { token =>
                guard token == "t0k" else { rest::invalid_token(cx); }
                rest::text(cx, 200, "ok");
            };
        };
    };
}

fn main() {
    expect::same(with_bearer("Authorization: Bearer t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    expect::same(with_bearer("Authorization: bearer   t0k\r\n"), str("HTTP/1.1 200 OK\r\n", OK));
    let none = "HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer\r\nContent-Type: application/json\r\nContent-Length: 27\r\n\r\n{\"error\":\"unauthenticated\"}";
    expect::same(with_bearer(""), none);
    expect::same(with_bearer("Authorization: Basic YTpi\r\n"), none);
    expect::same(with_bearer("Authorization: Bearer\r\n"), none);
    expect::same(with_bearer("Authorization: Bearer nope\r\n"),
                 str("HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer error=\"invalid_token\"\r\n",
                     "Content-Type: application/json\r\nContent-Length: 25\r\n\r\n{\"error\":\"invalid_token\"}"));
    print("rest::bearer: ok");
}
