// The projects' routes, under /organization/projects: each extracts, calls
// one rule, and answers.
namespace projects;

import std;
import http;
import rest;
import common.members.structs;
import projects.structs;
import projects.errors;
import projects.rules;

fn routes(cx, member: members::Member) {
    if rest::on(cx, "GET", "") {
        list(cx, member);
    } else if rest::on(cx, "POST", "") {
        create(cx, member);
    } else {
        rest::otherwise(cx);
    }
}

fn list(cx, member: members::Member) {
    var mine: Project[>..] = [];
    for p in cx.app.projects {
        if p.organization == member.organization { mine.push(p); }
    }
    rest::json(cx, 200, mine);
}

fn create(cx, member: members::Member) {
    let name, has = rest::form(cx, "name");
    rest::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, member, cx.app.projects.len + 1);
    check(err, cx);
    cx.app.projects.push(project);
    rest::json(cx, 201, project);
}
