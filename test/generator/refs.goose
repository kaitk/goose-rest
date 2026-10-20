// goose-rest gen's errors for a $ref outside its subset: another document,
// a missing schema, a keyword beside it, and cycles.
import std;
import http from "github.com/kaitk/goose-http@v0.4.2";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
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
    print("$refs refused: ok");
}
