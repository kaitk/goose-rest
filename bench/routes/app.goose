// gen60.goose's handlers: each answers "ok", as routes60.goose's routes do.
// The session check accepts every request, since routes60 checks none.
namespace app;

import std;
import http;
import rest;

fn ok(cx) { http::respond(cx.out, 200, "text/plain", "ok"); }

fn security_session(cx, state) -> i64 { 1 }

fn health(cx, state) { ok(cx); }
fn login(cx, state) { ok(cx); }
fn logout(cx, state, s) { ok(cx); }
fn refresh(cx, state) { ok(cx); }
fn get_session(cx, state, s) { ok(cx); }
fn get_me(cx, state, s) { ok(cx); }
fn update_me(cx, state, s) { ok(cx); }
fn get_settings(cx, state, s) { ok(cx); }
fn put_settings(cx, state, s) { ok(cx); }
fn get_user(cx, state, s, id) { ok(cx); }
fn get_avatar(cx, state, s, id) { ok(cx); }
fn put_avatar(cx, state, s, id) { ok(cx); }
fn list_orgs(cx, state, s) { ok(cx); }
fn create_org(cx, state, s) { ok(cx); }
fn get_org(cx, state, s, org) { ok(cx); }
fn update_org(cx, state, s, org) { ok(cx); }
fn delete_org(cx, state, s, org) { ok(cx); }
fn list_org_members(cx, state, s, org) { ok(cx); }
fn add_org_member(cx, state, s, org) { ok(cx); }
fn remove_org_member(cx, state, s, org, user) { ok(cx); }
fn list_projects(cx, state, s) { ok(cx); }
fn create_project(cx, state, s, body) { ok(cx); }
fn get_project(cx, state, s, id) { ok(cx); }
fn update_project(cx, state, s, id) { ok(cx); }
fn delete_project(cx, state, s, id) { ok(cx); }
fn archive_project(cx, state, s, id) { ok(cx); }
fn restore_project(cx, state, s, id) { ok(cx); }
fn list_project_members(cx, state, s, id) { ok(cx); }
fn add_project_member(cx, state, s, id) { ok(cx); }
fn remove_project_member(cx, state, s, id, user) { ok(cx); }
fn list_tasks(cx, state, s) { ok(cx); }
fn create_task(cx, state, s) { ok(cx); }
fn get_task(cx, state, s, id) { ok(cx); }
fn update_task(cx, state, s, id) { ok(cx); }
fn delete_task(cx, state, s, id) { ok(cx); }
fn assign_task(cx, state, s, id) { ok(cx); }
fn list_comments(cx, state, s, id) { ok(cx); }
fn add_comment(cx, state, s, id) { ok(cx); }
fn update_comment(cx, state, s, id, comment) { ok(cx); }
fn list_files(cx, state, s) { ok(cx); }
fn upload_file(cx, state, s) { ok(cx); }
fn get_file(cx, state, s, id) { ok(cx); }
fn delete_file(cx, state, s, id) { ok(cx); }
fn get_file_content(cx, state, s, id) { ok(cx); }
fn put_file_content(cx, state, s, id) { ok(cx); }
fn list_webhooks(cx, state, s) { ok(cx); }
fn create_webhook(cx, state, s) { ok(cx); }
fn get_webhook(cx, state, s, id) { ok(cx); }
fn update_webhook(cx, state, s, id) { ok(cx); }
fn delete_webhook(cx, state, s, id) { ok(cx); }
fn list_deliveries(cx, state, s, id) { ok(cx); }
fn time_report(cx, state, s) { ok(cx); }
fn user_time_report(cx, state, s, user) { ok(cx); }
fn budget_report(cx, state, s) { ok(cx); }
fn list_exports(cx, state, s) { ok(cx); }
fn create_export(cx, state, s) { ok(cx); }
fn get_export(cx, state, s, id) { ok(cx); }
fn delete_export(cx, state, s, id) { ok(cx); }
fn cancel_export(cx, state, s, id) { ok(cx); }
fn download_export(cx, state, s, id) { ok(cx); }
