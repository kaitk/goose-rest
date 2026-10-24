import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    print("at: ", problems::member(problems::body(400, "", 0), "at"));
    print("negative at omitted: ", problems::member(problems::body(404), "at").len == 0);
}
