// The projects' rules, called as plain functions: no server, thread, or
// database.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
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
