// The projects' routes, under /projects. Project 1 exists, and project 2
// is archived.
namespace projects;

import std;
import http;
import rest;
import common.errors;
import projects.errors;
import projects.rules;

fn routes(cx) {
    if rest::on(cx, "GET", "/:id") {
        show(cx);
    } else if rest::on(cx, "DELETE", "/:id") {
        remove(cx);
    } else {
        rest::otherwise(cx);
    }
}

fn show(cx) {
    let id = rest::param_int(cx, "id");
    check(readable(id), cx);
    rest::text(cx, 200, str("project ", id));
}

fn remove(cx) {
    let role, has = rest::header(cx, "X-Role");
    guard has && role == "admin" else { common::check(common::Error.NotAnAdmin, cx); }
    check(removable(rest::param_int(cx, "id")), cx);
    rest::empty(cx, 204);
}
