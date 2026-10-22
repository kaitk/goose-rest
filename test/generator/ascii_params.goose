// A string parameter's format is ascii or an error, and the router checks it.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
    let q = """{"name": "q", "in": "query", "schema": {"type": "string", "format": "ascii"}}""";
    let out = generated(api(str("""{"/a": {"get": {"operationId": "a", "parameters": [""", q, "]}}}")));
    assert(find(out, "if has_q && !rest::is_ascii(q) { rest::fail_param(cx, \"q: format\"); }") >= 0);
    let p = """{"name": "k", "in": "path", "required": true, "schema": {"type": "string", "format": "ascii"}}""";
    let out2 = generated(api(str("""{"/a/{k}": {"get": {"operationId": "a", "parameters": [""", p, "]}}}")));
    assert(find(out2, "if !rest::is_ascii(k) { rest::fail_param(cx, \"k: format\"); }") >= 0);
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string", "format": "uuid"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/schema/format: only ascii is supported");
    print("ascii parameters: ok");
}
