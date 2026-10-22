// The projects' routes, under /projects. Project 1 exists, and project 2
// is archived.
namespace projects;

import std;
import http;
import plod;
import common.errors;
import projects.errors;
import projects.rules;

fn routes(cx) {
    plod::get(cx, "/:id") { show(cx); };
    plod::delete(cx, "/:id") { remove(cx); };
}

fn show(cx) {
    let id = plod::param_int(cx, "id");
    // Ends the route with the rule's refusal, or goes on for Error.None.
    check(readable(id), cx);
    plod::text(cx, 200, str("project ", id));
}

fn remove(cx) {
    let role, has = plod::header(cx, "X-Role");
    guard has && role == "admin" else { common::check(common::Error.NotAnAdmin, cx); }
    check(removable(plod::param_int(cx, "id")), cx);
    plod::empty(cx, 204);
}
