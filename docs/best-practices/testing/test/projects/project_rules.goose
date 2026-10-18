// The projects' rules, called as plain functions: no server, thread, or
// database.
import std;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "../../../../../";
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
