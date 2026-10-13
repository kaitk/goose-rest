// Round trips through the readers and writers goose-rest gen wrote from
// test/gen/api.json: valid JSON reads and writes back as expected, and each
// invalid one fails with the error its schema gives. scripts/test.sh checks
// that test/gen/api_gen.goose is what the generator writes now.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import json;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../";
import .gen.api_gen;

fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// Reads text as a Project, writes it back, and compares with want.
fn project(text: const u8[:], want: const u8[:]) {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    let p = api::read_project(r, scratch);
    if !json::finish(r) { print("refused: ", json::message(r), "\n", text); assert(false); }
    var out: u8[>..] = [];
    api::format(out, p);
    same(out, want);
}

// Reads text as a Project, which must fail with error.
fn bad_project(text: const u8[:], error: const u8[:]) {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    let p = api::read_project(r, scratch);
    let ok = json::finish(r);
    if ok || r.error != error {
        print("want error '", error, "', got '", r.error, "' for\n", text);
        assert(false);
    }
}

fn create(text: const u8[:], want: const u8[:]) {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    let p = api::read_project_create(r, scratch);
    if !json::finish(r) { print("refused: ", json::message(r), "\n", text); assert(false); }
    var out: u8[>..] = [];
    api::format(out, p);
    same(out, want);
}

fn bad_create(text: const u8[:], error: const u8[:]) {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    let p = api::read_project_create(r, scratch);
    let ok = json::finish(r);
    if ok || r.error != error {
        print("want error '", error, "', got '", r.error, "' for\n", text);
        assert(false);
    }
}

let OWNER = """{"id": 7, "email": "ada@example.com"}""";

// The smallest valid Project, with each required field and nothing else.
fn minimal(extra: const u8[:]) -> u8[>..] {
    str("""{"id": 1, "name": "goose", "status": "active", "owner": """, OWNER,
        """, "tags": [], "createdAt": "2026-10-13T18:28:00Z" """, extra, "}")
}

fn test_project_valid() {
    project(minimal(""),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z"}""");
    // Every field, keys in another order, an unknown key skipped, a string
    // with escapes, a repeated key whose last value wins, and nulls.
    project("""
        {"type": "x", "settings": {"channels": ["slack", "email"], "notify": true, "other": 1},
         "kind": "client", "ref": "123e4567-e89b-12d3-a456-426614174000", "dueOn": null,
         "createdAt": "2026-10-13T18:28:00+02:00", "scores": [1, 0.5, -2e-3], "tags": ["a", "b\"c", "ü"],
         "reviewers": [{"id": 2, "email": "b@c.de", "displayName": "Bee"}, {"id": 3, "email": "c@d.ef", "displayName": null}],
         "owner": {"displayName": "Ada", "email": "ada@example.com", "id": 7, "unknown": [1, {"a": 2}]},
         "public": false, "priority": -5, "budget": 0, "status": "in-review", "name": "first",
         "name": "goose é", "id": 42, "extra": {"x": [null]}}
        """,
        """{"id":42,"name":"goose é","status":"in-review","budget":0.0,"priority":-5,"public":false,"owner":{"id":7,"email":"ada@example.com","displayName":"Ada"},"reviewers":[{"id":2,"email":"b@c.de","displayName":"Bee"},{"id":3,"email":"c@d.ef","displayName":null}],"tags":["a","b\"c","ü"],"scores":[1.0,0.5,-0.002],"createdAt":"2026-10-13T18:28:00+02:00","dueOn":null,"ref":"123e4567-e89b-12d3-a456-426614174000","kind":"client","settings":{"notify":true,"channels":["slack","email"]},"type":"x"}""");
    // Only the optional field after the first one, and a settings of null.
    project(minimal(""", "settings": {"channels": []}, "dueOn": "2024-02-29" """),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z","dueOn":"2024-02-29","settings":{"channels":[]}}""");
    project(minimal(""", "settings": null, "budget": 999999999.5 """),
        """{"id":1,"name":"goose","status":"active","budget":999999999.5,"owner":{"id":7,"email":"ada@example.com"},"tags":[],"createdAt":"2026-10-13T18:28:00Z","settings":null}""");
    project(minimal(""", "settings": {}, "tags": ["12345678901234567890"] """),
        """{"id":1,"name":"goose","status":"active","owner":{"id":7,"email":"ada@example.com"},"tags":["12345678901234567890"],"createdAt":"2026-10-13T18:28:00Z","settings":{}}""");
}

fn test_project_invalid() {
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
}

fn test_reviewers_max_items() {
    var many: u8[>..] = [];
    many.append(""", "reviewers": [""");
    for i in 11 {
        if i > 0 { many.push(','); }
        many.append(OWNER);
    }
    many.push(']');
    bad_project(minimal(many), "reviewers: maxItems");
}

fn test_create() {
    create("""{"name": "g"}""", """{"name":"g"}""");
    create("""{"status": "archived", "color": "#ff0000", "name": "goose"}""",
        """{"name":"goose","color":"#ff0000","status":"archived"}""");
    // 120 code points of two bytes each fill the 480-byte field halfway.
    var long: u8[>..] = [];
    long.append("""{"name": " """);
    long.pop();
    for i in 120 { long.append("é"); }
    long.append("\"}");
    var want: u8[>..] = [];
    want.append("""{"name":" """);
    want.pop();
    for i in 120 { want.append("é"); }
    want.append("\"}");
    create(long, want);
    long.clear();
    long.append("""{"name": " """);
    long.pop();
    for i in 121 { long.append("é"); }
    long.append("\"}");
    bad_create(long, "name: maxLength");
    bad_create("""{"name": ""}""", "name: minLength");
    bad_create("""{"name": "\ud800"}""", "name: not UTF-8");
    bad_create("""{"color": "#ff0000"}""", "name: required");
    bad_create("""{"name": "goose", "colour": "#ff0000"}""", "unknown member");
    bad_create("""{"name": "goose", "color": "#ff00000"}""", "color: maxLength");
}

fn main() {
    test_project_valid();
    test_project_invalid();
    test_reviewers_max_items();
    test_create();
    print("test_gen: ok");
}
