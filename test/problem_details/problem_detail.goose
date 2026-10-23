import std;
import http from "github.com/kaitk/goose-http@ebb4238728179e82140550af50e5bab1a7e0dab2";
import plod from "../../";
import expect from "../";
import common;

fn main() {
    print("detail: ", problems::member(problems::body(400, "name: \"required\"\n\\"), "detail"));
    print("empty detail omitted: ", problems::member(problems::body(404), "detail").len == 0);
}
