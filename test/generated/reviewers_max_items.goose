// A Project with more reviewers than maxItems, refused.
import std;
import json;
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
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
