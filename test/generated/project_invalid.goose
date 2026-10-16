// Invalid Projects, each refused by the generated reader with the error its
// schema gives.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.3.6";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;
import common;

fn main() {
    bad_project("""{"name": "goose"}""", "id: required");
    bad_project(minimal(""", "id": 0 """), "id: minimum");
    bad_project(minimal(""", "status": "deleted" """), "status: enum");
    bad_project(minimal(""", "budget": -0.5 """), "budget: minimum");
    bad_project(minimal(""", "budget": 1e9 """), "budget: exclusiveMaximum");
    bad_project(minimal(""", "priority": 6 """), "priority: maximum");
    bad_project(minimal(""", "priority": 3000000000 """), "priority: format");
    bad_project(minimal(""", "priority": 1.5 """), "expected an integer");
    bad_project(minimal(""", "createdAt": "2026-10-13" """), "createdAt: format");
    bad_project(minimal(""", "dueOn": "2023-02-29" """), "dueOn: format");
    bad_project(minimal(""", "ref": "not-a-uuid" """), "ref: format");
    bad_project(minimal(""", "kind": "partner" """), "kind: enum");
    bad_project(minimal(""", "tags": ["123456789012345678901"] """), "tags[]: maxLength");
    bad_project(minimal(""", "tags": "a" """), "expected '['");
    bad_project(minimal(""", "reviewers": [{"id": 1, "email": "x"}] """), "email: format");
    bad_project(minimal(""", "reviewers": [{"id": 1}] """), "email: required");
    bad_project(minimal(""", "reviewers": [1,2,3,4,5,6,7,8,9,10,11] """), "expected '{'");
    bad_project(minimal(""", "owner": {"id": 1, "email": "a@b.co", "displayName": 5} """), "expected a string");
    bad_project(minimal(""", "owner": null """), "expected '{'");
    bad_project(minimal(""", "settings": {"channels": ["fax"]} """), "channels[]: enum");
    bad_project(minimal(""", "name": null """), "expected a string");
    bad_project(minimal(""", "public": "yes" """), "expected true or false");
    bad_project(minimal(""", "scores": [1, "2"] """), "expected a number");
    bad_project("""{"id": 1""", "expected ',' or '}'");
    print("invalid Projects, refused: ok");
}
