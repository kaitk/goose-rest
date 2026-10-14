// What the generator refuses and tsc accepts: cycles, names, and values,
// which types can't check (task 011). Each document here type-checks, and
// scripts/test.sh writes each to JSON and checks that the generator refuses it
// with the error given. Run, this prints one case a line: the error, a tab,
// and the document.
import { api } from "../api.mts";

const d = { openapi: "3.1.0", info: { title: "t", version: "1" } } as const;
const id = { name: "id", in: "path", required: true, schema: { type: "integer" } } as const;
const cases: [string, object][] = [];
function refused(want: string, doc: object) {
  cases.push([want, doc]);
}

// Cycles.
refused(
  "#/components/schemas/A: a cycle of $refs",
  api({ ...d, components: { schemas: { A: { $ref: "#/components/schemas/B" }, B: { $ref: "#/components/schemas/A" } } } }),
);
refused(
  "#/components/schemas/B/properties/a: a cycle through A isn't supported",
  api({
    ...d,
    components: {
      schemas: {
        A: { type: "object", properties: { b: { $ref: "#/components/schemas/B" } } },
        B: { type: "object", properties: { a: { $ref: "#/components/schemas/A" } } },
      },
    },
  }),
);
refused(
  "#/components/schemas/Node/properties/children: a cycle through Node isn't supported",
  api({
    ...d,
    components: {
      schemas: { Node: { type: "object", properties: { children: { type: "array", items: { $ref: "#/components/schemas/Node" } } } } },
    },
  }),
);

// Names.
refused(
  "#/components/schemas/My-Type: the name isn't a Goose identifier",
  api({ ...d, components: { schemas: { "My-Type": { type: "object", properties: {} } } } }),
);
refused(
  "#/components/schemas/Project/properties/owner: another type has this name",
  api({
    ...d,
    components: {
      schemas: {
        ProjectOwner: { type: "object", properties: {} },
        Project: { type: "object", properties: { owner: { type: "object", properties: {} } } },
      },
    },
  }),
);
refused(
  "#/components/schemas/A/properties/a~1b: a property name of letters, digits, '_', '-', '.' and spaces is supported",
  api({ ...d, components: { schemas: { A: { type: "object", properties: { "a/b": { type: "string" } } } } } }),
);
refused(
  "#/components/schemas/A/properties/2fa: the field name 2fa isn't a Goose identifier",
  api({ ...d, components: { schemas: { A: { type: "object", properties: { "2fa": { type: "boolean" } } } } } }),
);
refused(
  "#/components/schemas/A/properties: two properties make the name foo_bar",
  api({
    ...d,
    components: { schemas: { A: { type: "object", properties: { fooBar: { type: "boolean" }, foo_bar: { type: "boolean" } } } } },
  }),
);
refused(
  "#/components/schemas/A/properties: two properties make the name has_name",
  api({
    ...d,
    components: { schemas: { A: { type: "object", properties: { name: { type: "string" }, has_name: { type: "boolean" } } } } },
  }),
);
refused(
  "#/components/schemas/A/enum: two values make the variant InReview",
  api({ ...d, components: { schemas: { A: { type: "string", enum: ["in-review", "in_review"] } } } }),
);
refused(
  "#/components/schemas/A/enum: an enum value needs a letter or digit",
  api({ ...d, components: { schemas: { A: { type: "string", enum: ["-"] } } } }),
);

// Values.
refused(
  "#/components/schemas/A/maxLength: must be a non-negative integer",
  api({ ...d, components: { schemas: { A: { type: "string", maxLength: -1 } } } }),
);
refused(
  "#/components/schemas/A/maxLength: must be a non-negative integer",
  api({ ...d, components: { schemas: { A: { type: "string", maxLength: 1.5 } } } }),
);
refused(
  "#/components/schemas/A/minimum: must be an integer on an integer",
  api({ ...d, components: { schemas: { A: { type: "integer", minimum: 1.5 } } } }),
);

// Paths and operations.
const c = { schemas: { A: { type: "object", properties: {} } } } as const;
refused(
  "#/paths/~1a~1x{id}: a segment with '%', '{', '}', '\"', '\\' or a control character isn't supported",
  api({ ...d, components: c, paths: { "/a/x{id}": { parameters: [id], get: { operationId: "a" } } } }),
);
refused(
  "#/paths/~1a~1{id}~1{id}: {id} is repeated",
  api({ ...d, components: c, paths: { "/a/{id}/{id}": { parameters: [id], get: { operationId: "a" } } } }),
);
refused(
  "#/paths/~1a~1{key}: matches the same requests as /a/{id}",
  api({
    ...d,
    components: c,
    paths: {
      "/a/{id}": { parameters: [id], get: { operationId: "a" } },
      "/a/{key}": { parameters: [{ ...id, name: "key" }], get: { operationId: "b" } },
    },
  }),
);
refused(
  "#/paths/~1b/get/operationId: another operation's handler is x",
  api({ ...d, components: c, paths: { "/a": { get: { operationId: "x" } }, "/b": { get: { operationId: "x" } } } }),
);
refused(
  "#/paths/~1a/get/operationId: the name if isn't a Goose identifier",
  api({ ...d, components: c, paths: { "/a": { get: { operationId: "if" } } } }),
);
refused(
  "#/paths/~1a/get/parameters/1: a repeated parameter",
  api({
    ...d,
    components: c,
    paths: {
      "/a": {
        get: {
          operationId: "a",
          parameters: [
            { name: "q", in: "query", schema: { type: "string" } },
            { name: "q", in: "query", schema: { type: "integer" } },
          ],
        },
      },
    },
  }),
);
refused(
  "#/paths/~1a/get/parameters: two parameters make the name q",
  api({
    ...d,
    components: c,
    paths: {
      "/a": {
        get: {
          operationId: "a",
          parameters: [
            { name: "q", in: "query", schema: { type: "string" } },
            { name: "q", in: "header", schema: { type: "integer" } },
          ],
        },
      },
    },
  }),
);
refused(
  "#/paths/~1a/get/operationId: another type has this name",
  api({
    ...d,
    components: { schemas: { AParams: { type: "object", properties: {} } } },
    paths: { "/a": { get: { operationId: "a", parameters: [{ name: "q", in: "query", schema: { type: "string" } }] } } },
  }),
);

for (const [want, doc] of cases) console.log(`${want}\t${JSON.stringify(doc)}`);
