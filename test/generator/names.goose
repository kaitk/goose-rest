// plod gen's errors for names it can't write: type and field names
// that aren't Goose identifiers, collide, or are the reader's own.
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";
import plod.gen.gen;
import common;

fn main() {
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
    print("names refused: ok");
}
