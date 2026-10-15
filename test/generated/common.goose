// What the tests of the readers and writers goose-rest gen wrote from
// test/gen/api.json share: a round trip of valid JSON, and the error of
// invalid JSON. scripts/test.sh checks that test/gen/api_gen.goose is what
// the generator writes now.
import std;
import json;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../";
import expect from "../";
import expect.gen.api_gen;

// Reads text as a Project, writes it back, and compares with want.
fn project(text: const u8[:], want: const u8[:]) {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    let p = api::read_project(r, scratch);
    if !json::finish(r) { print("refused: ", json::message(r), "\n", text); assert(false); }
    var out: u8[>..] = [];
    api::format(out, p);
    expect::same(out, want);
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
    expect::same(out, want);
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
