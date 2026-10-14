// What tsc refuses: each keyword, type, format, and shape outside the subset
// (task 011). Each case is a document that is valid but for one construct,
// and tsc fails on an unused @ts-expect-error, so the run fails as soon as
// tsc accepts one of them. What only the generator refuses is in
// generator.mts.
import { api } from "../api.mts";

const d = { openapi: "3.1.0", info: { title: "t", version: "1" } } as const;
const c = {
  schemas: { A: { type: "object", properties: {} }, N: { type: "string" } },
  securitySchemes: { s: { type: "http", scheme: "bearer" } },
} as const;
const id = { name: "id", in: "path", required: true, schema: { type: "integer" } } as const;
const body = { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/A" } } } } as const;

// The document these cases change one thing in.
api({
  ...d,
  components: c,
  security: [{ s: [] }],
  paths: { "/a/{id}": { parameters: [id], get: { operationId: "a", security: [] }, post: { operationId: "b", requestBody: body } } },
});

// The document.

// openapi other than 3.1.x
// @ts-expect-error
api({ ...d, openapi: "3.0.3", components: { schemas: {} } });
// components without schemas
// @ts-expect-error
api({ ...d, components: {} });

// Keywords outside the subset.

// pattern
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", pattern: "^#" } } } });
// default
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", default: "x" } } } });
// const
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", const: "x" } } } });
// multipleOf
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "integer", multipleOf: 2 } } } });
// uniqueItems
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "array", items: { type: "string" }, uniqueItems: true } } } });
// oneOf
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: {}, oneOf: [] } } } });
// anyOf, without a type
// @ts-expect-error
api({ ...d, components: { schemas: { A: { anyOf: [{ type: "string" }] } } } });
// allOf
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: {}, allOf: [] } } } });
// not
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", not: { type: "integer" } } } } });
// readOnly
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", readOnly: true } } } });
// writeOnly
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", writeOnly: true } } } });
// nullable, OpenAPI 3.0's
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", nullable: true } } } });
// a number's keyword on a string
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", minimum: 1 } } } });
// an array's keyword on an object
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: {}, items: { type: "string" } } } } });
// maxLength beside enum
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", enum: ["a"], maxLength: 3 } } } });
// format beside enum
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", enum: ["a"], format: "uuid" } } } });
// a keyword beside $ref
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string" }, B: { $ref: "#/components/schemas/A", maxLength: 3 } } } });

// Types.

// an unknown type
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "date" } } } });
// two types besides null
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: ["string", "integer"] } } } });
// enum on an integer
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "integer", enum: [1, 2] } } } });
// an enum value that isn't a string
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", enum: ["a", 2] } } } });

// Formats.

// a string format outside date, date-time, uuid, and email
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", format: "hostname" } } } });
// an integer format outside int32 and int64
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "integer", format: "uint8" } } } });
// a number format outside float and double
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "number", format: "decimal" } } } });
// a format on a boolean
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "boolean", format: "int32" } } } });

// Shapes.

// an array of arrays
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "array", items: { type: "array", items: { type: "string" } } } } } });
// an array of arrays, through a $ref
// @ts-expect-error
api({ ...d, components: { schemas: { L: { type: "array", items: { type: "string" } }, A: { type: "array", items: { $ref: "#/components/schemas/L" } } } } });
// an array without items
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "array" } } } });
// a nullable element
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "array", items: { type: ["string", "null"] } } } } });
// a nullable element, through a $ref
// @ts-expect-error
api({ ...d, components: { schemas: { N: { type: ["string", "null"] }, A: { type: "array", items: { $ref: "#/components/schemas/N" } } } } });
// an object without properties
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object" } } } });
// an empty enum
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "string", enum: [] } } } });
// additionalProperties other than true or false
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: {}, additionalProperties: { type: "string" } } } } });
// a $ref outside #/components/schemas/
// @ts-expect-error
api({ ...d, components: { schemas: { A: { $ref: "other.json#/B" } } } });
// a $ref to a component that doesn't exist
// @ts-expect-error
api({ ...d, components: { schemas: { A: { $ref: "#/components/schemas/B" } } } });
// a required name that isn't a property
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", required: ["b"], properties: { a: { type: "string" } } } } } });
// a field named after a reader local
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: { r: { type: "boolean" } } } } } });
// a field named after a reader local, in snake_case
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: { Scratch: { type: "boolean" } } } } } });
// @ts-expect-error
api({ ...d, components: { schemas: { A: { type: "object", properties: { "end-": { type: "boolean" } } } } } });

// Paths.

// a path that doesn't start with /
// @ts-expect-error
api({ ...d, components: c, paths: { a: { get: { operationId: "a" } } } });
// a key outside the subset on a path item
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { servers: [], get: { operationId: "a" } } } });
// a path without an operation
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { summary: "x" } } });
// an operation without operationId
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: {} } } });
// a key outside the subset on an operation
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", callbacks: {} } } } });
// a handler named after a local of dispatch
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "plain" } } } });

// Parameters.

// a template parameter no parameter declares
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a" } } } });
// in other than path, query, header, or cookie
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "body", schema: { type: "string" } }] } } } });
// style
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ ...id, style: "label" }] } } } });
// $ref on a parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ ...id, $ref: "#/components/parameters/id" }] } } } });
// a path parameter without required: true
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ name: "id", in: "path", schema: { type: "integer" } }] } } } });
// a path parameter the template doesn't name
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [id, { ...id, name: "key" }] } } } });
// a path parameter named after a local of dispatch
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{path}": { get: { operationId: "a", parameters: [{ ...id, name: "path" }] } } } });
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{s1}": { get: { operationId: "a", parameters: [{ ...id, name: "s1" }] } } } });
// a path parameter's number
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ ...id, schema: { type: "number" } }] } } } });
// a keyword on a path parameter's string
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ ...id, schema: { type: "string", maxLength: 3 } }] } } } });
// a $ref as a parameter's schema
// @ts-expect-error
api({ ...d, components: c, paths: { "/a/{id}": { get: { operationId: "a", parameters: [{ ...id, schema: { $ref: "#/components/schemas/N" } }] } } } });
// a query parameter's number
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "number" } }] } } } });
// a query parameter's array
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "array", items: { type: "string" } } }] } } } });
// a nullable query parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: ["integer", "null"] } }] } } } });
// format on a string parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "string", format: "uuid" } }] } } } });
// enum on a string parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "string", enum: ["x"] } }] } } } });
// default on a boolean parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "boolean", default: true } }] } } } });
// exclusiveMinimum on an integer parameter
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "integer", exclusiveMinimum: 0 } }] } } } });
// required other than true or false
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", required: "yes", schema: { type: "string" } }] } } } });
// a header parameter OpenAPI ignores
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "Authorization", in: "header", schema: { type: "string" } }] } } } });
// a parameter named after a local of its reader
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", parameters: [{ name: "v", in: "query", schema: { type: "string" } }] } } } });

// Request bodies.

// a body without required: true
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { post: { operationId: "a", requestBody: { content: body.content } } } } });
// a body other than application/json
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { post: { operationId: "a", requestBody: { required: true, content: { "text/plain": { schema: { type: "string" } } } } } } } });
// a body's schema that isn't a $ref
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { post: { operationId: "a", requestBody: { required: true, content: { "application/json": { schema: { type: "object", properties: {} } } } } } } } });
// a body's $ref to a component that isn't an object
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { post: { operationId: "a", requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/N" } } } } } } } });

// Security.

// alternatives
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", security: [{ s: [] }, {}] } } } });
// two schemes in one requirement
// @ts-expect-error
api({ ...d, components: { ...c, securitySchemes: { s: { type: "http" }, t: { type: "http" } } }, paths: { "/a": { get: { operationId: "a", security: [{ s: [], t: [] }] } } } });
// scopes
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", security: [{ s: ["read"] }] } } } });
// a scheme components.securitySchemes doesn't declare
// @ts-expect-error
api({ ...d, components: c, paths: { "/a": { get: { operationId: "a", security: [{ t: [] }] } } } });
// @ts-expect-error
api({ ...d, components: c, security: [{ t: [] }] });
