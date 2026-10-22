// A Project with more reviewers than maxItems, refused.
import std;
import json;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    var many: u8[>..] = [];
    many.append(""", "reviewers": [""");
    for i in 11 {
        if i > 0 { many.push(','); }
        many.append(OWNER);
    }
    many.push(']');
    bad_project(minimal(many), "reviewers: maxItems");
    print("maxItems: ok");
}
