import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    print("detail: ", problems::member(problems::body(400, "name: \"required\"\n\\"), "detail"));
    print("empty detail omitted: ", problems::member(problems::body(404), "detail").len == 0);
}
