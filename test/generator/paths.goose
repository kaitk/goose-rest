// plod gen's errors for paths, operations, parameters, request
// bodies, and security outside its subset.
import std;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../";
import plod.gen.gen;
import common;

let ID = """{"name": "id", "in": "path", "required": true, "schema": {"type": "integer"}}""";

fn main() {
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
        "#/paths/~1a/get/parameters/0/schema/format: only ascii is supported");
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
    print("paths refused: ok");
}
