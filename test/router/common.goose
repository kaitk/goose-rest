// What the router's tests share: the generated router (test/gen/routes_gen.goose,
// from routes.json), and an if chain of http::on over the same 60 routes in
// the same order, each answering as the handler in test/gen/app.goose it
// stands for.
import std;
import json;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import rest from "../../";
import expect from "../";
import expect.gen.routes_gen;
import expect.gen.app;

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

fn bad(detail: const u8[:]) -> u8[>..] { str("{\"error\":\"invalid_parameter\",\"detail\":\"", detail, "\"}") }
