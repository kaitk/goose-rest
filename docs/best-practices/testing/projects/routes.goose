// The projects' routes, under /projects: each extracts, calls one rule, and
// answers.
namespace projects;

import std;
import http;
import plod;
import projects.structs;
import projects.errors;
import projects.rules;

fn routes(cx) {
    plod::post(cx, "") { create(cx); };
    plod::post(cx, "/:id/archive") { archive(cx); };
}

fn create(cx) {
    let name, has = plod::form(cx, "name");
    // 400 invalid_parameter for a request without a name: the rule never runs.
    plod::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, cx.app.projects.len + 1);
    // The rule's refusal, such as 422 project_name_required, ends the route.
    check(err, cx);
    // In place of a job on a lane, as the program has no database.
    cx.app.projects.push(project);
    plod::json(cx, 201, project);
}

fn archive(cx) {
    let id = plod::param_int(cx, "id");
    guard id >= 1 && id <= cx.app.projects.len else { check(Error.NotFound, cx); }
    let project, err = archived(cx.app.projects[id - 1]);
    check(err, cx);
    cx.app.projects[id - 1] = project;
    plod::json(cx, 200, project);
}
