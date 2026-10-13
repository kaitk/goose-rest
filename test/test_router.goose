// The generated router (test/gen/routes_gen.goose, from routes.json) against
// an if chain of http::on over the same 60 routes in the same order: for
// every path with each method, and for paths no route takes, both answer
// with the same bytes. Then what only the generated router does: security,
// typed path parameters, and the JSON body. scripts/test-unit.sh runs this
// through TinyCC.
import std;
import json;
import http from "github.com/kaitk/goose-http@cfb9c02bd8cd1d841eaf9d140ff0dbd96bb3bcf8";
import rest from "../";
import .gen.routes_gen;
import .gen.app;

fn t(cx, s: const u8[:]) { rest::text(cx, 200, s); }

// The if chain, flat, each route answering as the handler in gen/app.goose
// it stands for.
fn chain(cx) {
    var r = http::router(cx.req);
    fn p(name: const u8[:]) -> const u8[:] { http::param(r, name) }
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
    else if http::on(r, "GET", "/v1/reports/exports") { t(cx, "list_exports"); }
    else if http::on(r, "POST", "/v1/reports/exports") { t(cx, "create_export"); }
    else if http::on(r, "GET", "/v1/reports/exports/:id") { t(cx, str("get_export ", p("id"))); }
    else if http::on(r, "DELETE", "/v1/reports/exports/:id") { t(cx, str("delete_export ", p("id"))); }
    else if http::on(r, "POST", "/v1/reports/exports/:id/cancel") { t(cx, str("cancel_export ", p("id"))); }
    else if http::on(r, "GET", "/v1/reports/exports/:id/download") { t(cx, str("download_export ", p("id"))); }
    else { rest::otherwise(cx, r); }
}

// What the generated router, or the if chain, answers to text.
fn answer(text: const u8[:], generated: bool) -> u8[>..] {
    var out: u8[>..] = [];
    let req, status = http::parse(text);
    if status != 200 { print("parse: ", status, "\n", text); assert(false); }
    var keep = true;
    var st = http::Stream { .. };
    var state = rest::NoState { .. };
    var cx = rest::Cx<rest::NoState> { req: req, body: text[req.len..], out: http::Reply { buf: out, common: "",
                                       keep_alive: keep, minor: 1, head: req.method == "HEAD", stream: st },
                                       state: state };
    if generated { api::dispatch(cx, state); } else { chain(cx); }
    return out;
}

fn request(method: const u8[:], target: const u8[:]) -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\nCookie: session=1\r\n\r\n")
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

fn main() {
    test_same_as_chain();
    test_security_and_parameters();
    test_body();
    print("test_router: ok");
}
