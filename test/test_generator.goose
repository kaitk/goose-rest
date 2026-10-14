// Unit tests for goose-rest gen's errors: each construct outside the subset
// fails with a message that names it and its JSON pointer. The code it
// writes is tested by test_gen.goose and by scripts/test.sh's golden files.
// scripts/test-unit.sh runs this through TinyCC.
import std;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../";
import rest.gen.gen;

// A document whose components.schemas is schemas.
fn doc(schemas: const u8[:]) -> u8[>..] {
    str("""{"openapi": "3.1.0", "components": {"schemas": """, schemas, "}}")
}

fn fails(text: const u8[:], want: const u8[:]) {
    var out: u8[>..] = [];
    let err = gen::generate(text, "api", "app", "api.json", out);
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

// A document with paths, a schema A, and a security scheme s.
fn api(paths: const u8[:]) -> u8[>..] {
    str("""{"openapi": "3.1.0", "paths": """, paths,
        """, "components": {"schemas": {"A": {"type": "object", "properties": {}}, "N": {"type": "string"}}, "securitySchemes": {"s": {"type": "http"}}}}""")
}

let ID = """{"name": "id", "in": "path", "required": true, "schema": {"type": "integer"}}""";

fn test_paths() {
    fails(api("""{"a": {"get": {"operationId": "a"}}}"""), "#/paths/a: a path must start with '/'");
    fails(api("""{"/a/x{id}": {"get": {"operationId": "a"}}}"""),
        "#/paths/~1a~1x{id}: a segment with '%', '{', '}', '\"', '\\' or a control character isn't supported");
    fails(api("""{"/a/{id}/{id}": {"get": {"operationId": "a"}}}"""), "#/paths/~1a~1{id}~1{id}: {id} is repeated");
    fails(api(str("""{"/a/{id}": {"parameters": [""", ID, """], "get": {"operationId": "a"}}, "/a/{key}": {"get": {"operationId": "b"}}}""")),
        "#/paths/~1a~1{key}: matches the same requests as /a/{id}");
    fails(api("""{"/a": {"servers": [], "get": {"operationId": "a"}}}"""), "#/paths/~1a/servers: not supported on a path item");
    fails(api("""{"/a": {"summary": "x"}}"""), "#/paths/~1a: a path needs an operation");
    fails(api("""{"/a": {"get": {}}}"""), "#/paths/~1a/get: an operation needs an operationId, its handler's name");
    fails(api("""{"/a": {"get": {"operationId": "a", "callbacks": {}}}}"""), "#/paths/~1a/get/callbacks: not supported on an operation");
    fails(api("""{"/a": {"get": {"operationId": "x"}}, "/b": {"get": {"operationId": "x"}}}"""),
        "#/paths/~1b/get/operationId: another operation's handler is x");
    fails(api("""{"/a": {"get": {"operationId": "get-a!"}}}"""),
        "#/paths/~1a/get/operationId: a name of letters, digits, '_', '-', '.' and spaces is supported");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a"}}}"""), "#/paths/~1a~1{id}/get: no parameter declares {id}");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "body", "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/in: must be path, query, header, or cookie, not body");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "number"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/schema: a parameter's schema is an integer, a string, or a boolean");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string", "format": "uuid"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/schema/format: not supported on a string parameter");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "boolean", "default": true}}]}}}"""),
        "#/paths/~1a/get/parameters/0/schema/default: not supported on a boolean parameter");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "required": "yes", "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/required: must be true or false");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "Authorization", "in": "header", "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/name: OpenAPI ignores a header parameter named Authorization");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string"}}, {"name": "q", "in": "query", "schema": {"type": "integer"}}]}}}"""),
        "#/paths/~1a/get/parameters/1: a repeated parameter");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string", "minLength": 2, "maxLength": 1}}]}}}"""),
        "#/paths/~1a/get/parameters/0/schema: minLength and maxLength leave no value between them");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a", "parameters": [{"name": "id", "in": "path", "required": true, "schema": {"type": "integer", "minimum": 1, "maximum": 0}}]}}}"""),
        "#/paths/~1a~1{id}/get/parameters/0/schema: minimum and maximum leave no value between them");
    fails(api("""{"/a": {"post": {"operationId": "a", "requestBody": {"required": true, "x-body-limit": 0, "content": {"application/json": {"schema": {"$ref": "#/components/schemas/A"}}}}}}}"""),
        "#/paths/~1a/post/requestBody/x-body-limit: must be a positive integer");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string"}}, {"name": "q", "in": "header", "schema": {"type": "integer"}}]}}}"""),
        "#/paths/~1a/get/parameters: two parameters make the name q");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string"}}, {"name": "has_q", "in": "cookie", "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a/get/parameters: two parameters make the name has_q");
    fails(api("""{"/a": {"get": {"operationId": "a", "parameters": [{"name": "v", "in": "query", "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a/get/parameters/0/name: the name v is one the generated code uses");
    fails("""{"openapi": "3.1.0", "paths": {"/a": {"get": {"operationId": "a", "parameters": [{"name": "q", "in": "query", "schema": {"type": "string"}}]}}}, "components": {"schemas": {"AParams": {"type": "object", "properties": {}}}}}""",
        "#/paths/~1a/get/operationId: another type has this name");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a", "parameters": [{"name": "id", "in": "path", "schema": {"type": "integer"}}]}}}"""),
        "#/paths/~1a~1{id}/get/parameters/0: a path parameter must have required: true");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a", "parameters": [{"name": "id", "in": "path", "required": true, "style": "label", "schema": {"type": "integer"}}]}}}"""),
        "#/paths/~1a~1{id}/get/parameters/0/style: not supported on a parameter");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a", "parameters": [{"name": "id", "in": "path", "required": true, "schema": {"type": "number"}}]}}}"""),
        "#/paths/~1a~1{id}/get/parameters/0/schema: a path parameter's schema is an integer or a string");
    fails(api("""{"/a/{id}": {"get": {"operationId": "a", "parameters": [{"name": "id", "in": "path", "required": true, "schema": {"type": "string", "maxLength": 3}}]}}}"""),
        "#/paths/~1a~1{id}/get/parameters/0/schema/maxLength: not supported on a path parameter's string");
    fails(api("""{"/a/{path}": {"get": {"operationId": "a", "parameters": [{"name": "path", "in": "path", "required": true, "schema": {"type": "string"}}]}}}"""),
        "#/paths/~1a~1{path}/get/parameters/0/name: the name path is one the generated code uses");
    fails(api("""{"/a": {"post": {"operationId": "a", "requestBody": {"content": {"application/json": {"schema": {"$ref": "#/components/schemas/A"}}}}}}}"""),
        "#/paths/~1a/post/requestBody: a request body must have required: true");
    fails(api("""{"/a": {"post": {"operationId": "a", "requestBody": {"required": true, "content": {"text/plain": {"schema": {"type": "string"}}}}}}}"""),
        "#/paths/~1a/post/requestBody/content/text~1plain: only application/json is supported");
    fails(api("""{"/a": {"post": {"operationId": "a", "requestBody": {"required": true, "content": {"application/json": {"schema": {"type": "object", "properties": {}}}}}}}}"""),
        "#/paths/~1a/post/requestBody/content/application~1json/schema: a body is a $ref to an object component");
    fails(api("""{"/a": {"post": {"operationId": "a", "requestBody": {"required": true, "content": {"application/json": {"schema": {"$ref": "#/components/schemas/N"}}}}}}}"""),
        "#/paths/~1a/post/requestBody/content/application~1json/schema/$ref: a body is a $ref to an object component");
    fails(api("""{"/a": {"get": {"operationId": "a", "security": [{"s": []}, {}]}}}"""),
        "#/paths/~1a/get/security: one security requirement is supported, not alternatives");
    fails(api("""{"/a": {"get": {"operationId": "a", "security": [{"t": []}]}}}"""),
        "#/paths/~1a/get/security/0/t: no such scheme in components.securitySchemes");
    fails(api("""{"/a": {"get": {"operationId": "a", "security": [{"s": ["read"]}]}}}"""),
        "#/paths/~1a/get/security/0/s: scopes aren't supported");
}

fn test_accepted() {
    var out: u8[>..] = [];
    let err = gen::generate(doc("""{"A": {"type": "object", "properties": {"type": {"type": "string"}, "HTTPServer": {"type": "boolean"}}}}"""),
        "api", "app", "api.json", out);
    if err.len > 0 { print(err); assert(false); }
    assert(find(out, "    has_type_: bool,\n    type_: u8[],\n") >= 0);
    assert(find(out, "    http_server: bool,\n") >= 0);
}

fn generated(text: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let err = gen::generate(text, "api", "app", "api.json", out);
    if err.len > 0 { print(err, "\nfor ", text); assert(false); }
    return out;
}

// pydantic's and schemars' optional values, anyOf with null, generate what
// a type array with null does.
fn test_any_of_null() {
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
}

fn same_code(a: const u8[:], b: const u8[:]) {
    let x = generated(a);
    let y = generated(b);
    if x != y { print("differ:\n", a, "\n", b, "\n---\n", x, "\n---\n", y); assert(false); }
}

fn main() {
    test_any_of_null();
    test_document();
    test_keywords();
    test_types();
    test_refs();
    test_names();
    test_paths();
    test_accepted();
    print("test_generator: ok");
}
