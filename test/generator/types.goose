// plod gen's errors for types, formats, and bounds outside its
// subset, or that leave no value.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import plod.gen.gen;
import common;

fn main() {
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": ["string", "integer"]}}}}"""),
        "#/components/schemas/A/properties/c/type: one type besides \"null\" is supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "date"}}}}"""),
        "#/components/schemas/A/properties/c/type: unknown type date");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "format": "hostname"}}}}"""),
        "#/components/schemas/A/properties/c/format: only date, date-time, uuid, email and ascii are supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "integer", "format": "uint8"}}}}"""),
        "#/components/schemas/A/properties/c/format: only int32 and int64 are supported");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "integer", "minimum": 1.5}}}}"""),
        "#/components/schemas/A/properties/c/minimum: must be an integer on an integer");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "maxLength": -1}}}}"""),
        "#/components/schemas/A/properties/c/maxLength: must be a non-negative integer");
    fails(doc("""{"A": {"type": "string", "minLength": 5, "maxLength": 4}}"""),
        "#/components/schemas/A: minLength and maxLength leave no value between them");
    fails(doc("""{"A": {"type": "string", "format": "uuid", "maxLength": 35}}"""),
        "#/components/schemas/A: format uuid and maxLength leave no value between them");
    fails(doc("""{"A": {"type": "string", "format": "date", "minLength": 11}}"""),
        "#/components/schemas/A: minLength and format date leave no value between them");
    fails(doc("""{"A": {"type": "array", "items": {"type": "string"}, "minItems": 3, "maxItems": 2}}"""),
        "#/components/schemas/A: minItems and maxItems leave no value between them");
    fails(doc("""{"A": {"type": "integer", "minimum": 2, "maximum": 1}}"""),
        "#/components/schemas/A: minimum and maximum leave no value between them");
    fails(doc("""{"A": {"type": "integer", "exclusiveMinimum": 1, "exclusiveMaximum": 2}}"""),
        "#/components/schemas/A: exclusiveMinimum and exclusiveMaximum leave no value between them");
    fails(doc("""{"A": {"type": "integer", "format": "int32", "minimum": 2147483648}}"""),
        "#/components/schemas/A: minimum and format int32 leave no value between them");
    fails(doc("""{"A": {"type": "integer", "exclusiveMaximum": -9223372036854775808}}"""),
        "#/components/schemas/A: exclusiveMaximum leaves no value below it");
    fails(doc("""{"A": {"type": "number", "minimum": 1.5, "exclusiveMaximum": 1.5}}"""),
        "#/components/schemas/A: minimum and exclusiveMaximum leave no value between them");
    fails(doc("""{"A": {"type": "object", "properties": {"a": {"type": "string"}}, "required": ["a", "a"]}}"""),
        "#/components/schemas/A/required: names a twice");
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
    print("types refused: ok");
}
