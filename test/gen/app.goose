// The handlers test/gen/routes_gen.goose calls. Each answers 200 with its
// operation's name and its path parameters, so that test_router.goose can
// compare the generated router with an if chain byte for byte.
namespace app;

import std;
import http;
import rest;

// Fails 401 without a session cookie, and returns the session's user.
fn security_session(cx, state) -> i64 {
    let v, found = http::cookie_of(cx.req, "session");
    guard found && v.len > 0 else { rest::fail(cx, 401, "unauthenticated"); }
    return 1;
}

fn health(cx, state) { rest::text(cx, 200, "health"); }
fn login(cx, state) { rest::text(cx, 200, "login"); }
fn logout(cx, state, s) { rest::text(cx, 200, "logout"); }
fn refresh(cx, state) { rest::text(cx, 200, "refresh"); }
fn get_session(cx, state, s) { rest::text(cx, 200, "get_session"); }
fn get_me(cx, state, s) { rest::text(cx, 200, "get_me"); }
fn update_me(cx, state, s) { rest::text(cx, 200, "update_me"); }
fn get_settings(cx, state, s) { rest::text(cx, 200, "get_settings"); }
fn put_settings(cx, state, s) { rest::text(cx, 200, "put_settings"); }
fn get_user(cx, state, s, id) { rest::text(cx, 200, str("get_user ", id)); }
fn get_avatar(cx, state, s, id) { rest::text(cx, 200, str("get_avatar ", id)); }
fn put_avatar(cx, state, s, id) { rest::text(cx, 200, str("put_avatar ", id)); }
fn list_orgs(cx, state, s) { rest::text(cx, 200, "list_orgs"); }
fn create_org(cx, state, s) { rest::text(cx, 200, "create_org"); }
fn get_org(cx, state, s, org) { rest::text(cx, 200, str("get_org ", org)); }
fn update_org(cx, state, s, org) { rest::text(cx, 200, str("update_org ", org)); }
fn delete_org(cx, state, s, org) { rest::text(cx, 200, str("delete_org ", org)); }
fn list_org_members(cx, state, s, org) { rest::text(cx, 200, str("list_org_members ", org)); }
fn add_org_member(cx, state, s, org) { rest::text(cx, 200, str("add_org_member ", org)); }
fn remove_org_member(cx, state, s, org, user) { rest::text(cx, 200, str("remove_org_member ", org, " ", user)); }
// Names each parameter given, so that a request without any answers as the
// if chain does.
fn list_projects(cx, state, s, q) {
    var t: u8[>..] = [];
    t.append("list_projects");
    if q.has_page { format(t, " page=", q.page); }
    if q.has_archived { format(t, " archived=", q.archived); }
    if q.has_q { format(t, " q=", q.q); }
    rest::text(cx, 200, t);
}
fn create_project(cx, state, s, body) { rest::text(cx, 201, str("create_project ", body.name)); }
fn get_project(cx, state, s, id) { rest::text(cx, 200, str("get_project ", id)); }
fn update_project(cx, state, s, id) { rest::text(cx, 200, str("update_project ", id)); }
fn delete_project(cx, state, s, id) { rest::text(cx, 200, str("delete_project ", id)); }
fn archive_project(cx, state, s, id) { rest::text(cx, 200, str("archive_project ", id)); }
fn restore_project(cx, state, s, id) { rest::text(cx, 200, str("restore_project ", id)); }
fn list_project_members(cx, state, s, id) { rest::text(cx, 200, str("list_project_members ", id)); }
fn add_project_member(cx, state, s, id) { rest::text(cx, 200, str("add_project_member ", id)); }
fn remove_project_member(cx, state, s, id, user) { rest::text(cx, 200, str("remove_project_member ", id, " ", user)); }
fn list_tasks(cx, state, s) { rest::text(cx, 200, "list_tasks"); }
fn create_task(cx, state, s) { rest::text(cx, 200, "create_task"); }
fn get_task(cx, state, s, id) { rest::text(cx, 200, str("get_task ", id)); }
fn update_task(cx, state, s, id) { rest::text(cx, 200, str("update_task ", id)); }
fn delete_task(cx, state, s, id) { rest::text(cx, 200, str("delete_task ", id)); }
fn assign_task(cx, state, s, id) { rest::text(cx, 200, str("assign_task ", id)); }
fn list_comments(cx, state, s, id) { rest::text(cx, 200, str("list_comments ", id)); }
fn add_comment(cx, state, s, id) { rest::text(cx, 200, str("add_comment ", id)); }
fn update_comment(cx, state, s, id, comment) { rest::text(cx, 200, str("update_comment ", id, " ", comment)); }
fn list_files(cx, state, s) { rest::text(cx, 200, "list_files"); }
fn upload_file(cx, state, s) { rest::text(cx, 200, "upload_file"); }
fn get_file(cx, state, s, id) { rest::text(cx, 200, str("get_file ", id)); }
fn delete_file(cx, state, s, id) { rest::text(cx, 200, str("delete_file ", id)); }
fn get_file_content(cx, state, s, id) { rest::text(cx, 200, str("get_file_content ", id)); }
fn put_file_content(cx, state, s, id) { rest::text(cx, 200, str("put_file_content ", id)); }
fn list_webhooks(cx, state, s) { rest::text(cx, 200, "list_webhooks"); }
fn create_webhook(cx, state, s) { rest::text(cx, 200, "create_webhook"); }
fn get_webhook(cx, state, s, id) { rest::text(cx, 200, str("get_webhook ", id)); }
fn update_webhook(cx, state, s, id) { rest::text(cx, 200, str("update_webhook ", id)); }
fn delete_webhook(cx, state, s, id) { rest::text(cx, 200, str("delete_webhook ", id)); }
fn list_deliveries(cx, state, s, id) { rest::text(cx, 200, str("list_deliveries ", id)); }
fn time_report(cx, state, s) { rest::text(cx, 200, "time_report"); }
fn user_time_report(cx, state, s, user) { rest::text(cx, 200, str("user_time_report ", user)); }
fn budget_report(cx, state, s) { rest::text(cx, 200, "budget_report"); }
fn list_exports(cx, state, s, q) {
    var t: u8[>..] = [];
    format(t, "list_exports ", q.x_trace);
    if q.has_theme { format(t, " theme=", q.theme); }
    if q.has_x_limit { format(t, " limit=", q.x_limit); }
    rest::text(cx, 200, t);
}
fn create_export(cx, state, s, q) { rest::text(cx, 200, "create_export"); }
fn get_export(cx, state, s, id) { rest::text(cx, 200, str("get_export ", id)); }
fn delete_export(cx, state, s, id) { rest::text(cx, 200, str("delete_export ", id)); }
fn cancel_export(cx, state, s, id) { rest::text(cx, 200, str("cancel_export ", id)); }
fn download_export(cx, state, s, id) { rest::text(cx, 200, str("download_export ", id)); }
