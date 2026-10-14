// gen60.goose's handlers: each answers "ok", as routes60.goose's routes do.
// The session check accepts every request, since routes60 checks none.
namespace app;

import std;
import http;
import rest;

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

fn security_session(cx) -> i64 { 1 }

fn health(cx) { ok(cx); }
fn login(cx) { ok(cx); }
fn logout(cx,s) { ok(cx); }
fn refresh(cx) { ok(cx); }
fn get_session(cx,s) { ok(cx); }
fn get_me(cx,s) { ok(cx); }
fn update_me(cx,s) { ok(cx); }
fn get_settings(cx,s) { ok(cx); }
fn put_settings(cx,s) { ok(cx); }
fn get_user(cx,s, id) { ok(cx); }
fn get_avatar(cx,s, id) { ok(cx); }
fn put_avatar(cx,s, id) { ok(cx); }
fn list_orgs(cx,s) { ok(cx); }
fn create_org(cx,s) { ok(cx); }
fn get_org(cx,s, org) { ok(cx); }
fn update_org(cx,s, org) { ok(cx); }
fn delete_org(cx,s, org) { ok(cx); }
fn list_org_members(cx,s, org) { ok(cx); }
fn add_org_member(cx,s, org) { ok(cx); }
fn remove_org_member(cx,s, org, user) { ok(cx); }
fn list_projects(cx,s, q) { ok(cx); }
fn create_project(cx,s, body) { ok(cx); }
fn get_project(cx,s, id) { ok(cx); }
fn update_project(cx,s, id) { ok(cx); }
fn delete_project(cx,s, id) { ok(cx); }
fn archive_project(cx,s, id) { ok(cx); }
fn restore_project(cx,s, id) { ok(cx); }
fn list_project_members(cx,s, id) { ok(cx); }
fn add_project_member(cx,s, id) { ok(cx); }
fn remove_project_member(cx,s, id, user) { ok(cx); }
fn list_tasks(cx,s) { ok(cx); }
fn create_task(cx,s) { ok(cx); }
fn get_task(cx,s, id) { ok(cx); }
fn update_task(cx,s, id) { ok(cx); }
fn delete_task(cx,s, id) { ok(cx); }
fn assign_task(cx,s, id) { ok(cx); }
fn list_comments(cx,s, id) { ok(cx); }
fn add_comment(cx,s, id) { ok(cx); }
fn update_comment(cx,s, id, comment) { ok(cx); }
fn list_files(cx,s) { ok(cx); }
fn upload_file(cx,s) { ok(cx); }
fn get_file(cx,s, id) { ok(cx); }
fn delete_file(cx,s, id) { ok(cx); }
fn get_file_content(cx,s, id) { ok(cx); }
fn put_file_content(cx,s, id) { ok(cx); }
fn list_webhooks(cx,s) { ok(cx); }
fn create_webhook(cx,s) { ok(cx); }
fn get_webhook(cx,s, id) { ok(cx); }
fn update_webhook(cx,s, id) { ok(cx); }
fn delete_webhook(cx,s, id) { ok(cx); }
fn list_deliveries(cx,s, id) { ok(cx); }
fn time_report(cx,s) { ok(cx); }
fn user_time_report(cx,s, user) { ok(cx); }
fn budget_report(cx,s) { ok(cx); }
fn list_exports(cx,s, q) { ok(cx); }
fn create_export(cx,s, q) { ok(cx); }
fn get_export(cx,s, id) { ok(cx); }
fn delete_export(cx,s, id) { ok(cx); }
fn cancel_export(cx,s, id) { ok(cx); }
fn download_export(cx,s, id) { ok(cx); }
