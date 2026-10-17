// A Project with more reviewers than maxItems, refused.
import std;
import json;
import http from "github.com/kaitk/goose-http@782ec236b44bdc5da5a4ea289115095268d6696e";
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
