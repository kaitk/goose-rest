// pydantic's and schemars' optional values, anyOf with null, generate what
// a type array with null does.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import rest.gen.gen;
import common;

fn same_code(a: const u8[:], b: const u8[:]) {
    let x = generated(a);
    let y = generated(b);
    if x != y { print("differ:\n", a, "\n", b, "\n---\n", x, "\n---\n", y); assert(false); }
}

fn main() {
    let b = """"B": {"type": "object", "properties": {"x": {"type": "integer"}}}""";
    same_code(doc(str("""{"A": {"type": "object", "properties": {"n": {"anyOf": [{"type": "integer", "minimum": 1}, {"type": "null"}], "default": null, "title": "N"}}}, """, b, "}")),
              doc(str("""{"A": {"type": "object", "properties": {"n": {"type": ["integer", "null"], "minimum": 1}}}, """, b, "}")));
    let out = generated(doc(str("""{"A": {"type": "object", "properties": {"b": {"anyOf": [{"type": "null"}, {"$ref": "#/components/schemas/B"}]}}}, """, b, "}")));
    assert(find(out, "    b_null: bool,\n    b: B,\n") >= 0);
    fails(doc("""{"A": {"anyOf": [{"type": "string"}, {"type": "integer"}]}}"""),
        "#/components/schemas/A/anyOf: only anyOf of one schema and {\"type\": \"null\"} is supported");
    fails(doc("""{"A": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": "x"}}"""),
        "#/components/schemas/A/default: only null is supported beside anyOf");
    fails(doc("""{"A": {"anyOf": [{"type": "string"}, {"type": "null"}], "type": "string"}}"""),
        "#/components/schemas/A/type: not supported beside anyOf");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "array", "items": {"anyOf": [{"type": "string"}, {"type": "null"}]}}}}}"""),
        "#/components/schemas/A/properties/c/items/type: a nullable element isn't supported");
    print("anyOf with null: ok");
}
