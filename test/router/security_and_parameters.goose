// What only the generated router does: its security check, and typed path
// parameters with their bounds.
import std;
import json;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;
import common;

fn main() {
    let anon = answer("GET /v1/projects/7 HTTP/1.1\r\nHost: x\r\n\r\n", true);
    expect::same(expect::body_of(anon), "{\"error\":\"unauthenticated\"}", "no cookie");
    expect::same(expect::body_of(answer("GET /health HTTP/1.1\r\nHost: x\r\n\r\n", true)), "health",
                 "no cookie, no security");
    expect::same(expect::body_of(answer(request("GET", "/v1/projects/0"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"id: minimum\"}", "id 0");
    expect::same(expect::body_of(answer(request("GET", "/v1/projects/x7"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "id x7");
    expect::same(expect::body_of(answer(request("GET", "/v1/projects/-3"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"id: minimum\"}", "id -3");
    expect::same(expect::body_of(answer(request("GET", "/v1/reports/time/2147483648"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"user: format\"}", "user 2^31");
    expect::same(expect::body_of(answer(request("GET", "/v1/reports/time/-2147483648"), true)),
                 "user_time_report -2147483648", "user -2^31");
    expect::same(expect::body_of(answer(request("GET", "/v1/projects/99999999999999999999"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "id past i64");
    // A concrete path wins over a template where both match: /v1/users/me
    // has no avatar route, so this is /v1/users/{id}/avatar with id "me",
    // which isn't an integer. The if chain calls the handler with "me".
    expect::same(expect::body_of(answer(request("GET", "/v1/users/me/avatar"), true)),
                 "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "me/avatar");
    print("the generated router's security and path parameters: ok");
}
