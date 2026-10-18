// goose-rest gen's errors for a document it can't read: another OpenAPI
// version, no schemas, and JSON that doesn't parse.
import std;
import http from "github.com/kaitk/goose-http@d0e3fd4afebcdb9ce032a8c7ebc13e00fe5bf841";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
    fails("""{"openapi": "3.0.3", "components": {"schemas": {}}}""", "#/openapi: must be 3.1.x");
    fails("""{"openapi": "3.1.0"}""", "#/components/schemas: missing");
    fails("""{"openapi": "3.1.0",""", "json: expected a key at byte 20");
    print("documents refused: ok");
}
