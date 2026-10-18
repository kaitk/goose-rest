// The projects' rules, called as plain functions: no server, thread, or
// database.
import std;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
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
