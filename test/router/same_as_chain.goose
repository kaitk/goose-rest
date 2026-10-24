// The generated router against the if chain: for every path with each
// method, and for paths no route takes, both answer with the same bytes.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;
import common;

let PATHS = ["/health", "/v1/auth/login", "/v1/auth/logout", "/v1/auth/refresh", "/v1/auth/session",
    "/v1/users/me", "/v1/users/me/settings", "/v1/users/7", "/v1/users/7/avatar", "/v1/orgs", "/v1/orgs/acme",
    "/v1/orgs/acme/members", "/v1/orgs/acme/members/9", "/v1/projects", "/v1/projects/7", "/v1/projects/7/archive",
    "/v1/projects/7/restore", "/v1/projects/7/members", "/v1/projects/7/members/9", "/v1/tasks", "/v1/tasks/7",
    "/v1/tasks/7/assign", "/v1/tasks/7/comments", "/v1/tasks/7/comments/c1", "/v1/files", "/v1/files/7",
    "/v1/files/7/content", "/v1/webhooks", "/v1/webhooks/7", "/v1/webhooks/7/deliveries", "/v1/reports/time",
    "/v1/reports/time/9", "/v1/reports/budget", "/v1/reports/exports", "/v1/reports/exports/7",
    "/v1/reports/exports/7/cancel", "/v1/reports/exports/7/download",
    // Paths no route takes, escaped segments, and a query.
    "/", "/v1", "/v2/x", "/v1/projects/7/nope", "/v1/projects/", "/health/", "/v1//projects", "/%68ealth",
    "/v1/%70rojects/7", "/v1/reports/exports/7/%64ownload", "/v1/orgs/a%2Fb", "/v1/tasks/7?x=1", "/v1/../health",
    "/v1/%2e%2e/health"];

let METHODS = ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"];

fn main() {
    var n = 0;
    for path in PATHS {
        for m in METHODS {
            // The generated router reads this one's body: json_body.goose.
            if m == "POST" && path == "/v1/projects" { continue; }
            let text = request(m, path);
            expect::same(answer(text, true), answer(text, false), text);
            n++;
        }
    }
    for text in ["BREW /health HTTP/1.1\r\nHost: x\r\n\r\n", "OPTIONS * HTTP/1.1\r\nHost: x\r\n\r\n"] {
        expect::same(answer(text, true), answer(text, false), text);
        n++;
    }
    assert(n == 358);
    print("the generated router answers as the if chain, ", n, " requests: ok");
}
