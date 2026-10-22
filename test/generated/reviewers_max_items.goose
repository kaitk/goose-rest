// A Project with more reviewers than maxItems, refused.
import std;
import json;
import http from "github.com/kaitk/goose-http@5701a0d83a2f6e381bc13b69d80ae0a33d42daef";
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
