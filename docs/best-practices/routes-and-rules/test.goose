// docs/best-practices/routes-and-rules.md: the projects' rules, called as
// plain functions, with no server, thread, or database. scripts/test.sh runs
// it through TinyCC:
//
//   goose docs/best-practices/routes-and-rules/test.goose
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../../";
import projects.rules;

fn main() {
    let p, err = projects::new_project(projects::CreateInput { name: "goose" }, 1);
    assert(err == projects::Error.None && p.name == "goose" && !p.archived);
    let unnamed, why = projects::new_project(projects::CreateInput { name: "" }, 2);
    assert(why == projects::Error.NameRequired);

    let a, done = projects::archived(p);
    assert(done == projects::Error.None && a.archived);
    let again, refused = projects::archived(a);
    assert(refused == projects::Error.AlreadyArchived);
    print("routes-and-rules: ok");
}
