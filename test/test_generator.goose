// Unit tests for goose-rest gen's errors: each construct outside the subset
// fails with a message that names it and its JSON pointer. The code it
// writes is tested by test_gen.goose and by scripts/test.sh's golden files.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@04791ac50b69d99e93c08dc2c3f3ff8d4ab1867c";
import rest from "../";
import rest.gen.gen;

// A document whose components.schemas is schemas.
fn doc(schemas: const u8[:]) -> u8[>..] {
    str("""{"openapi": "3.1.0", "components": {"schemas": """, schemas, "}}")
}

fn fails(text: const u8[:], want: const u8[:]) {
    var out: u8[>..] = [];
    let err = gen::generate(text, "api", "api.json", out);
    if err != want {
        print("want '", want, "'\ngot  '", err, "'\nfor ", text);
        assert(false);
    }
}

fn test_document() {
    fails("""{"openapi": "3.0.3", "components": {"schemas": {}}}""", "#/openapi: must be 3.1.x");
    fails("""{"openapi": "3.1.0"}""", "#/components/schemas: missing");
    fails("""{"openapi": "3.1.0",""", "json: expected a key at byte 20");
}

fn test_keywords() {
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
}

fn test_types() {
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": ["string", "integer"]}}}}"""),
        "#/components/schemas/A/properties/c/type: one type besides \"null\" is supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "date"}}}}"""),
        "#/components/schemas/A/properties/c/type: unknown type date");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "format": "hostname"}}}}"""),
        "#/components/schemas/A/properties/c/format: only date, date-time, uuid and email are supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "integer", "format": "uint8"}}}}"""),
        "#/components/schemas/A/properties/c/format: only int32 and int64 are supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "integer", "minimum": 1.5}}}}"""),
        "#/components/schemas/A/properties/c/minimum: must be an integer on an integer");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "maxLength": -1}}}}"""),
        "#/components/schemas/A/properties/c/maxLength: must be a non-negative integer");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "array", "items": {"type": "array", "items": {"type": "string"}}}}}}"""),
        "#/components/schemas/A/properties/c/items/type: an array of arrays isn't supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "array"}}}}"""),
        "#/components/schemas/A/properties/c: an array needs items");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "array", "items": {"type": ["string", "null"]}}}}}"""),
        "#/components/schemas/A/properties/c/items/type: a nullable element isn't supported");
    fails(doc("""{"A": {"type": "object"}}"""), "#/components/schemas/A: an object needs properties");
    fails(doc("""{"A": {"type": "object", "properties": {}, "additionalProperties": {"type": "string"}}}"""),
        "#/components/schemas/A/additionalProperties: only true and false are supported");
    fails(doc("""{"A": {"type": "integer", "enum": [1, 2]}}"""),
        "#/components/schemas/A/enum: not supported on an integer");
    fails(doc("""{"A": {"type": "string", "enum": ["a", 2]}}"""),
        "#/components/schemas/A/enum: only string enums are supported");
    fails(doc("""{"A": {"type": "string", "enum": ["in-review", "in_review"]}}"""),
        "#/components/schemas/A/enum: two values make the variant InReview");
    fails(doc("""{"A": {"type": "string", "enum": ["a"], "maxLength": 3}}"""),
        "#/components/schemas/A/maxLength: not supported beside enum");
}

fn test_refs() {
    fails(doc("""{"A": {"type": "object", "properties": {"b": {"$ref": "other.json#/B"}}}}"""),
        "#/components/schemas/A/properties/b/$ref: only #/components/schemas/<name> is supported");
    fails(doc("""{"A": {"type": "object", "properties": {"b": {"$ref": "#/components/schemas/B"}}}}"""),
        "#/components/schemas/A/properties/b/$ref: no such schema");
    fails(doc("""{"A": {"type": "object", "properties": {"b": {"$ref": "#/components/schemas/B", "maxLength": 3}}}, "B": {"type": "string"}}"""),
        "#/components/schemas/A/properties/b/maxLength: not supported beside $ref");
    fails(doc("""{"A": {"$ref": "#/components/schemas/B"}, "B": {"$ref": "#/components/schemas/A"}}"""),
        "#/components/schemas/A: a cycle of $refs");
    fails(doc("""{"A": {"type": "object", "properties": {"b": {"$ref": "#/components/schemas/B"}}}, "B": {"type": "object", "properties": {"a": {"$ref": "#/components/schemas/A"}}}}"""),
        "#/components/schemas/B/properties/a: a cycle through A isn't supported");
    fails(doc("""{"Node": {"type": "object", "properties": {"children": {"type": "array", "items": {"$ref": "#/components/schemas/Node"}}}}}"""),
        "#/components/schemas/Node/properties/children: a cycle through Node isn't supported");
}

fn test_names() {
    fails(doc("""{"My-Type": {"type": "object", "properties": {}}}"""),
        "#/components/schemas/My-Type: the name isn't a Goose identifier");
    fails(doc("""{"ProjectOwner": {"type": "object", "properties": {}}, "Project": {"type": "object", "properties": {"owner": {"type": "object", "properties": {}}}}}"""),
        "#/components/schemas/Project/properties/owner: another type has this name");
    fails(doc("""{"A": {"type": "object", "properties": {"a\"b": {"type": "string"}}}}"""),
        "#/components/schemas/A/properties/a\"b: a property name that's empty, or has '\"', '\\' or a control character, isn't supported");
    fails(doc("""{"A": {"type": "object", "properties": {"a/b": {"type": "string"}}}}"""),
        "#/components/schemas/A/properties/a~1b: a property name of letters, digits, '_', '-', '.' and spaces is supported");
    fails(doc("""{"A": {"type": "object", "properties": {"2fa": {"type": "boolean"}}}}"""),
        "#/components/schemas/A/properties/2fa: the field name 2fa isn't a Goose identifier");
    fails(doc("""{"A": {"type": "object", "properties": {"r": {"type": "boolean"}}}}"""),
        "#/components/schemas/A/properties/r: the field name r is one the reader uses");
    fails(doc("""{"A": {"type": "object", "properties": {"fooBar": {"type": "boolean"}, "foo_bar": {"type": "boolean"}}}}"""),
        "#/components/schemas/A/properties: two properties make the name foo_bar");
    fails(doc("""{"A": {"type": "object", "properties": {"name": {"type": "string"}, "has_name": {"type": "boolean"}}}}"""),
        "#/components/schemas/A/properties: two properties make the name has_name");
    fails(doc("""{"A": {"type": "object", "required": ["b"], "properties": {"a": {"type": "string"}}}}"""),
        "#/components/schemas/A/required: names b, which isn't a property");
}

fn test_accepted() {
    var out: u8[>..] = [];
    let err = gen::generate(doc("""{"A": {"type": "object", "properties": {"type": {"type": "string"}, "HTTPServer": {"type": "boolean"}}}}"""),
        "api", "api.json", out);
    if err.len > 0 { print(err); assert(false); }
    assert(find(out, "    has_type_: bool,\n    type_: u8[],\n") >= 0);
    assert(find(out, "    http_server: bool,\n") >= 0);
}

fn main() {
    test_document();
    test_keywords();
    test_types();
    test_refs();
    test_names();
    test_accepted();
    print("test_generator: ok");
}
