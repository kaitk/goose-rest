// The projects' rules, called as plain functions: no server, thread, or
// database.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../../../../";
import app from "../../";

fn main() {
    let p, err = projects::new_project(projects::CreateInput { name: "goose" }, 1);
    print("new_project goose: ", err, " ", p);
    let unnamed, why = projects::new_project(projects::CreateInput { name: "" }, 2);
    print("new_project with no name: ", why);
    let a, done = projects::archived(p);
    print("archived: ", done, " ", a);
    let again, refused = projects::archived(a);
    print("archived again: ", refused);
}
