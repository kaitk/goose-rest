// The projects' routes, under /organization/projects: each extracts, calls
// one rule, and answers.
namespace projects;

import std;
import http;
import plod;
import common.members.structs;
import projects.structs;
import projects.errors;
import projects.rules;

fn routes(cx, member: members::Member) {
    plod::get(cx, "") { list(cx, member); };
    plod::post(cx, "") { create(cx, member); };
}

fn list(cx, member: members::Member) {
    var mine: Project[>..] = [];
    for p in cx.app.projects {
        if p.organization == member.organization { mine.push(p); }
    }
    plod::json(cx, 200, mine);
}

fn create(cx, member: members::Member) {
    let name, has = plod::form(cx, "name");
    plod::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, member, cx.app.projects.len + 1);
    check(err, cx);
    cx.app.projects.push(project);
    plod::json(cx, 201, project);
}
