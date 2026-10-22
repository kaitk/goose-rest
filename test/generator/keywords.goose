// goose-rest gen's errors for keywords outside its subset, each naming the
// keyword and its JSON pointer.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "pattern": "^#"}}}}"""),
        "#/components/schemas/A/properties/c/pattern: not supported on a string");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "nullable": true}}}}"""),
        "#/components/schemas/A/properties/c/nullable: nullable is OpenAPI 3.0's; write the type as [\"<type>\", \"null\"]");
    fails(doc("""{"A": {"type": "object", "oneOf": [], "properties": {}}}"""),
        "#/components/schemas/A/oneOf: not supported on an object");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"oneOf": [{"type": "string"}]}}}}"""),
        "#/components/schemas/A/properties/c: a schema needs a type or a $ref");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "array", "items": {"type": "string"}, "uniqueItems": true}}}}"""),
        "#/components/schemas/A/properties/c/uniqueItems: not supported on an array");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "integer", "multipleOf": 2}}}}"""),
        "#/components/schemas/A/properties/c/multipleOf: not supported on an integer");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "default": "x"}}}}"""),
        "#/components/schemas/A/properties/c/default: not supported on a string");
    print("keywords refused: ok");
}
