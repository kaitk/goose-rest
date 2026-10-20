// The generated router's query, header, and cookie parameters: their
// bounds and formats, an optional one a path item declares, and which
// failure comes first.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.4.1";
import rest from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;
import common;

fn main() {
    fn says(target: const u8[:], fields: const u8[:] = "X-Trace: t1\r\n") -> u8[>..] {
        return str(expect::body_of(answer(request("GET", target, fields), true)));
    }
    expect::same(says("/v1/projects?page=2&archived=false&q=a+%C3%A9"), "list_projects page=2 archived=false q=a é", "all");
    expect::same(says("/v1/projects?q=abc&page=1000"), "list_projects page=1000 q=abc", "bounds");
    expect::same(says("/v1/projects?page=0"), bad("page: minimum"), "page 0");
    expect::same(says("/v1/projects?page=1001"), bad("page: maximum"), "page 1001");
    expect::same(says("/v1/projects?page=2147483648"), bad("page: format"), "page 2^31");
    expect::same(says("/v1/projects?page=two"), bad("page: integer"), "page two");
    expect::same(says("/v1/projects?page="), bad("page: integer"), "page empty");
    expect::same(says("/v1/projects?archived=1"), bad("archived: boolean"), "archived 1");
    expect::same(says("/v1/projects?q=abcd"), bad("q: maxLength"), "q abcd");
    expect::same(says("/v1/projects?q=%FF"), bad("q: not UTF-8"), "q %FF");
    expect::same(says("/v1/orgs/a%2Fb"), "get_org a/b", "org decoded");
    expect::same(says("/v1/reports/exports", "X-Trace: t1\r\nCookie: theme=dark\r\nX-Limit: 5\r\n"),
                 "list_exports t1 theme=dark limit=5", "header and cookie");
    expect::same(says("/v1/reports/exports", ""), bad("X-Trace: required"), "no X-Trace");
    expect::same(says("/v1/reports/exports", "X-Trace: t\r\n"), bad("X-Trace: minLength"), "X-Trace t");
    expect::same(says("/v1/reports/exports", "X-Trace: t1\r\nX-Limit: 0\r\n"), bad("X-Limit: minimum"), "X-Limit 0");
    expect::same(says("/v1/reports/exports", "X-Trace: t1\r\nX-Limit: x\r\n"), bad("X-Limit: integer"), "X-Limit x");
    // The path item's X-Trace, which list_exports overrides, is optional.
    expect::same(str(expect::body_of(answer(request("POST", "/v1/reports/exports", ""), true))), "create_export",
                 "optional X-Trace");
    // Security and path parameters come first.
    expect::same(says("/v1/reports/exports?page=x", ""), bad("X-Trace: required"), "first failure");
    let whole = answer(request("GET", "/v1/projects?page=0"), true);
    expect::same(whole, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 54\r\n\r\n",
                            bad("page: minimum")), "whole answer");
    print("the generated router's query, header, and cookie parameters: ok");
}
