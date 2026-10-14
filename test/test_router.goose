// The generated router (test/gen/routes_gen.goose, from routes.json) against
// an if chain of http::on over the same 60 routes in the same order: for
// every path with each method, and for paths no route takes, both answer
// with the same bytes. Then what only the generated router does: security,
// typed path parameters, and the JSON body. scripts/test-unit.sh runs this
// through TinyCC.
import std;
import json;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../";
import .gen.routes_gen;
import .gen.app;

fn t(cx, s: const u8[:]) { rest::text(cx, 200, s); }

// The if chain, flat, each route answering as the handler in gen/app.goose
// it stands for, given a request without query, header, or cookie
// parameters but X-Trace. Inside one route, since rest::param can fail.
fn chain(cx) {
    rest::route(cx) { chain_routes(cx); };
}

fn chain_routes(cx) {
    var r = http::router(cx.req);
    fn p(name: const u8[:]) -> const u8[:] { rest::param(cx, r, name) }
    if http::on(r, "GET", "/health") { t(cx, "health"); }
    else if http::on(r, "POST", "/v1/auth/login") { t(cx, "login"); }
    else if http::on(r, "POST", "/v1/auth/logout") { t(cx, "logout"); }
    else if http::on(r, "POST", "/v1/auth/refresh") { t(cx, "refresh"); }
    else if http::on(r, "GET", "/v1/auth/session") { t(cx, "get_session"); }
    else if http::on(r, "GET", "/v1/users/me") { t(cx, "get_me"); }
    else if http::on(r, "PATCH", "/v1/users/me") { t(cx, "update_me"); }
    else if http::on(r, "GET", "/v1/users/me/settings") { t(cx, "get_settings"); }
    else if http::on(r, "PUT", "/v1/users/me/settings") { t(cx, "put_settings"); }
    else if http::on(r, "GET", "/v1/users/:id") { t(cx, str("get_user ", p("id"))); }
    else if http::on(r, "GET", "/v1/users/:id/avatar") { t(cx, str("get_avatar ", p("id"))); }
    else if http::on(r, "PUT", "/v1/users/:id/avatar") { t(cx, str("put_avatar ", p("id"))); }
    else if http::on(r, "GET", "/v1/orgs") { t(cx, "list_orgs"); }
    else if http::on(r, "POST", "/v1/orgs") { t(cx, "create_org"); }
    else if http::on(r, "GET", "/v1/orgs/:org") { t(cx, str("get_org ", p("org"))); }
    else if http::on(r, "PATCH", "/v1/orgs/:org") { t(cx, str("update_org ", p("org"))); }
    else if http::on(r, "DELETE", "/v1/orgs/:org") { t(cx, str("delete_org ", p("org"))); }
    else if http::on(r, "GET", "/v1/orgs/:org/members") { t(cx, str("list_org_members ", p("org"))); }
    else if http::on(r, "POST", "/v1/orgs/:org/members") { t(cx, str("add_org_member ", p("org"))); }
    else if http::on(r, "DELETE", "/v1/orgs/:org/members/:user") { t(cx, str("remove_org_member ", p("org"), " ", p("user"))); }
    else if http::on(r, "GET", "/v1/projects") { t(cx, "list_projects"); }
    else if http::on(r, "POST", "/v1/projects") { t(cx, "create_project"); }
    else if http::on(r, "GET", "/v1/projects/:id") { t(cx, str("get_project ", p("id"))); }
    else if http::on(r, "PATCH", "/v1/projects/:id") { t(cx, str("update_project ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/projects/:id") { t(cx, str("delete_project ", p("id"))); }
    else if http::on(r, "POST", "/v1/projects/:id/archive") { t(cx, str("archive_project ", p("id"))); }
    else if http::on(r, "POST", "/v1/projects/:id/restore") { t(cx, str("restore_project ", p("id"))); }
    else if http::on(r, "GET", "/v1/projects/:id/members") { t(cx, str("list_project_members ", p("id"))); }
    else if http::on(r, "POST", "/v1/projects/:id/members") { t(cx, str("add_project_member ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/projects/:id/members/:user") { t(cx, str("remove_project_member ", p("id"), " ", p("user"))); }
    else if http::on(r, "GET", "/v1/tasks") { t(cx, "list_tasks"); }
    else if http::on(r, "POST", "/v1/tasks") { t(cx, "create_task"); }
    else if http::on(r, "GET", "/v1/tasks/:id") { t(cx, str("get_task ", p("id"))); }
    else if http::on(r, "PATCH", "/v1/tasks/:id") { t(cx, str("update_task ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/tasks/:id") { t(cx, str("delete_task ", p("id"))); }
    else if http::on(r, "POST", "/v1/tasks/:id/assign") { t(cx, str("assign_task ", p("id"))); }
    else if http::on(r, "GET", "/v1/tasks/:id/comments") { t(cx, str("list_comments ", p("id"))); }
    else if http::on(r, "POST", "/v1/tasks/:id/comments") { t(cx, str("add_comment ", p("id"))); }
    else if http::on(r, "PATCH", "/v1/tasks/:id/comments/:comment") { t(cx, str("update_comment ", p("id"), " ", p("comment"))); }
    else if http::on(r, "GET", "/v1/files") { t(cx, "list_files"); }
    else if http::on(r, "POST", "/v1/files") { t(cx, "upload_file"); }
    else if http::on(r, "GET", "/v1/files/:id") { t(cx, str("get_file ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/files/:id") { t(cx, str("delete_file ", p("id"))); }
    else if http::on(r, "GET", "/v1/files/:id/content") { t(cx, str("get_file_content ", p("id"))); }
    else if http::on(r, "PUT", "/v1/files/:id/content") { t(cx, str("put_file_content ", p("id"))); }
    else if http::on(r, "GET", "/v1/webhooks") { t(cx, "list_webhooks"); }
    else if http::on(r, "POST", "/v1/webhooks") { t(cx, "create_webhook"); }
    else if http::on(r, "GET", "/v1/webhooks/:id") { t(cx, str("get_webhook ", p("id"))); }
    else if http::on(r, "PATCH", "/v1/webhooks/:id") { t(cx, str("update_webhook ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/webhooks/:id") { t(cx, str("delete_webhook ", p("id"))); }
    else if http::on(r, "GET", "/v1/webhooks/:id/deliveries") { t(cx, str("list_deliveries ", p("id"))); }
    else if http::on(r, "GET", "/v1/reports/time") { t(cx, "time_report"); }
    else if http::on(r, "GET", "/v1/reports/time/:user") { t(cx, str("user_time_report ", p("user"))); }
    else if http::on(r, "GET", "/v1/reports/budget") { t(cx, "budget_report"); }
    else if http::on(r, "GET", "/v1/reports/exports") {
        let trace, found = rest::header(cx, "X-Trace");
        t(cx, str("list_exports ", trace));
    }
    else if http::on(r, "POST", "/v1/reports/exports") { t(cx, "create_export"); }
    else if http::on(r, "GET", "/v1/reports/exports/:id") { t(cx, str("get_export ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/reports/exports/:id") { t(cx, str("delete_export ", p("id"))); }
    else if http::on(r, "POST", "/v1/reports/exports/:id/cancel") { t(cx, str("cancel_export ", p("id"))); }
    else if http::on(r, "GET", "/v1/reports/exports/:id/download") { t(cx, str("download_export ", p("id"))); }
    else { rest::otherwise(cx, r); }
}

// What the generated router, or the if chain, answers to text.
fn answer(text: const u8[:], generated: bool) -> u8[>..] {
    return rest::serve_one(text) { cx => if generated { api::dispatch(cx); } else { chain(cx); } };
}

fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "X-Trace: t1\r\n") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\nCookie: session=1\r\n", fields, "\r\n")
}

fn same(got: const u8[:], want: const u8[:], text: const u8[:]) {
    if got != want {
        print("for:\n", text, "got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

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

fn test_same_as_chain() {
    var n = 0;
    for path in PATHS {
        for m in METHODS {
            // The generated router reads this one's body: test_body.
            if m == "POST" && path == "/v1/projects" { continue; }
            let text = request(m, path);
            same(answer(text, true), answer(text, false), text);
            n++;
        }
    }
    for text in ["BREW /health HTTP/1.1\r\nHost: x\r\n\r\n", "OPTIONS * HTTP/1.1\r\nHost: x\r\n\r\n"] {
        same(answer(text, true), answer(text, false), text);
        n++;
    }
    assert(n == 358);
}

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn test_security_and_parameters() {
    let anon = answer("GET /v1/projects/7 HTTP/1.1\r\nHost: x\r\n\r\n", true);
    same(body_of(anon), "{\"error\":\"unauthenticated\"}", "no cookie");
    same(body_of(answer("GET /health HTTP/1.1\r\nHost: x\r\n\r\n", true)), "health", "no cookie, no security");
    same(body_of(answer(request("GET", "/v1/projects/0"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"id: minimum\"}", "id 0");
    same(body_of(answer(request("GET", "/v1/projects/x7"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "id x7");
    same(body_of(answer(request("GET", "/v1/projects/-3"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"id: minimum\"}", "id -3");
    same(body_of(answer(request("GET", "/v1/reports/time/2147483648"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"user: format\"}", "user 2^31");
    same(body_of(answer(request("GET", "/v1/reports/time/-2147483648"), true)), "user_time_report -2147483648",
         "user -2^31");
    same(body_of(answer(request("GET", "/v1/projects/99999999999999999999"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "id past i64");
    // A concrete path wins over a template where both match: /v1/users/me
    // has no avatar route, so this is /v1/users/{id}/avatar with id "me",
    // which isn't an integer. The if chain calls the handler with "me".
    same(body_of(answer(request("GET", "/v1/users/me/avatar"), true)),
         "{\"error\":\"invalid_parameter\",\"detail\":\"id: integer\"}", "me/avatar");
}

fn bad(detail: const u8[:]) -> u8[>..] { str("{\"error\":\"invalid_parameter\",\"detail\":\"", detail, "\"}") }

fn test_query_header_cookie() {
    fn says(target: const u8[:], fields: const u8[:] = "X-Trace: t1\r\n") -> u8[>..] {
        return str(body_of(answer(request("GET", target, fields), true)));
    }
    same(says("/v1/projects?page=2&archived=false&q=a+%C3%A9"), "list_projects page=2 archived=false q=a é", "all");
    same(says("/v1/projects?q=abc&page=1000"), "list_projects page=1000 q=abc", "bounds");
    same(says("/v1/projects?page=0"), bad("page: minimum"), "page 0");
    same(says("/v1/projects?page=1001"), bad("page: maximum"), "page 1001");
    same(says("/v1/projects?page=2147483648"), bad("page: format"), "page 2^31");
    same(says("/v1/projects?page=two"), bad("page: integer"), "page two");
    same(says("/v1/projects?page="), bad("page: integer"), "page empty");
    same(says("/v1/projects?archived=1"), bad("archived: boolean"), "archived 1");
    same(says("/v1/projects?q=abcd"), bad("q: maxLength"), "q abcd");
    same(says("/v1/projects?q=%FF"), bad("q: not UTF-8"), "q %FF");
    same(says("/v1/orgs/a%2Fb"), "get_org a/b", "org decoded");
    same(says("/v1/reports/exports", "X-Trace: t1\r\nCookie: theme=dark\r\nX-Limit: 5\r\n"),
         "list_exports t1 theme=dark limit=5", "header and cookie");
    same(says("/v1/reports/exports", ""), bad("X-Trace: required"), "no X-Trace");
    same(says("/v1/reports/exports", "X-Trace: t\r\n"), bad("X-Trace: minLength"), "X-Trace t");
    same(says("/v1/reports/exports", "X-Trace: t1\r\nX-Limit: 0\r\n"), bad("X-Limit: minimum"), "X-Limit 0");
    same(says("/v1/reports/exports", "X-Trace: t1\r\nX-Limit: x\r\n"), bad("X-Limit: integer"), "X-Limit x");
    // The path item's X-Trace, which list_exports overrides, is optional.
    same(str(body_of(answer(request("POST", "/v1/reports/exports", ""), true))), "create_export", "optional X-Trace");
    // Security and path parameters come first.
    same(says("/v1/reports/exports?page=x", ""), bad("X-Trace: required"), "first failure");
    let whole = answer(request("GET", "/v1/projects?page=0"), true);
    same(whole, str("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 54\r\n\r\n",
                    bad("page: minimum")), "whole answer");
}

fn post(content_type: const u8[:], body: const u8[:]) -> u8[>..] {
    let text = str("POST /v1/projects HTTP/1.1\r\nHost: x\r\nCookie: session=1\r\n", content_type,
                   "Content-Length: ", body.len, "\r\n\r\n", body);
    return answer(text, true);
}

fn test_body() {
    same(status_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\"}")), "HTTP/1.1 201 Created", "201");
    same(body_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\"}")), "create_project goose", "201");
    same(body_of(post("", "{\"name\": \"goose\"}")), "{\"error\":\"unsupported_media_type\"}", "415");
    same(body_of(post("Content-Type: application/json\r\n", "{\"name\": \"\"}")),
         "{\"error\":\"invalid_body\",\"detail\":\"name: minLength\",\"at\":12}", "minLength");
    same(body_of(post("Content-Type: application/json\r\n", "{\"name\": \"goose\", \"x\": 1}")),
         "{\"error\":\"invalid_body\",\"detail\":\"unknown member\",\"at\":22}", "unknown member");
}

// Hand-written routes before dispatch, one on a path of its own and one on a
// path the schema has, which dispatch answers with their Allow.
fn beside(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "PUT", "/uploads/:name") {
            rest::route(cx) { t(cx, str("upload ", rest::param(cx, "name"))); };
        } else if rest::on(cx, "POST", "/v1/files/:id/content") {
            t(cx, "post_file_content");
        } else {
            api::dispatch(cx);
        }
    };
}

fn answer_beside(text: const u8[:]) -> u8[>..] {
    return rest::serve_one(text) { cx => beside(cx) };
}

fn test_beside_dispatch() {
    let not_allowed = "HTTP/1.1 405 Method Not Allowed\r\nAllow: ";
    let json = "\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n{\"error\":\"method_not_allowed\"}";
    same(body_of(answer_beside(request("PUT", "/uploads/logo.png"))), "upload logo.png", "PUT");
    same(answer_beside(request("GET", "/uploads/logo.png")), str(not_allowed, "PUT", json), "GET");
    same(answer_beside(request("OPTIONS", "/uploads/logo.png")), "HTTP/1.1 204 No Content\r\nAllow: PUT\r\n\r\n",
         "OPTIONS");
    same(body_of(answer_beside(request("POST", "/v1/files/7/content"))), "post_file_content", "POST");
    same(body_of(answer_beside(request("GET", "/v1/files/7/content"))), "get_file_content 7", "generated GET");
    same(answer_beside(request("DELETE", "/v1/files/7/content")), str(not_allowed, "POST, GET, HEAD, PUT", json),
         "DELETE");
    same(answer_beside(request("OPTIONS", "/v1/files/7/content")),
         "HTTP/1.1 204 No Content\r\nAllow: POST, GET, HEAD, PUT\r\n\r\n", "OPTIONS of both");
    // Without hand-written routes on the path, dispatch answers alone.
    same(answer_beside(request("DELETE", "/health")), str(not_allowed, "GET, HEAD", json), "generated only");
    same(status_of(answer_beside(request("GET", "/uploads"))), "HTTP/1.1 404 Not Found", "404");
}

fn main() {
    test_same_as_chain();
    test_security_and_parameters();
    test_query_header_cookie();
    test_body();
    test_beside_dispatch();
    print("test_router: ok");
}
