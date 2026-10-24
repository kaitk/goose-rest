// plod gen's errors for a document it can't read: another OpenAPI
// version, no schemas, and JSON that doesn't parse.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import plod.gen.gen;
import common;

fn main() {
    fails("""{"openapi": "3.0.3", "components": {"schemas": {}}}""", "#/openapi: must be 3.1.x");
    fails("""{"openapi": "3.1.0"}""", "#/components/schemas: missing");
    fails("""{"openapi": "3.1.0",""", "json: expected a key at byte 20");
    print("documents refused: ok");
}
