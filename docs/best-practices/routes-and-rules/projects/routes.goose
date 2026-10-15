// The projects' routes, under /projects: each extracts, calls one rule, and
// answers.
namespace projects;

import std;
import http;
import rest;
import projects.structs;
import projects.errors;
import projects.rules;

fn routes(cx) {
    if rest::on(cx, "POST", "") {
        create(cx);
    } else if rest::on(cx, "POST", "/:id/archive") {
        archive(cx);
    } else {
        rest::otherwise(cx);
    }
}

fn create(cx) {
    let name, has = rest::form(cx, "name");
    rest::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, cx.app.projects.len + 1);
    check(err, cx);
    cx.app.projects.push(project);
    rest::json(cx, 201, project);
}

fn archive(cx) {
    let id = rest::param_int(cx, "id");
    guard id >= 1 && id <= cx.app.projects.len else { check(Error.NotFound, cx); }
    let project, err = archived(cx.app.projects[id - 1]);
    check(err, cx);
    cx.app.projects[id - 1] = project;
    rest::json(cx, 200, project);
}
