// docs/tutorial/06-schema-languages.md: api.json, written with the TypeScript
// helper.
//
//   node docs/tutorial/05-schema/api.mts > docs/tutorial/05-schema/api.json
import { api, json } from "../../../ts/api.mts";

// A project's name, the same in what a client sends and what it gets back.
const name = { type: "string", minLength: 1, maxLength: 64 } as const;

const doc = api({
  openapi: "3.1.0",
  info: { title: "Projects", version: "1" },
  paths: {
    "/health": { get: { operationId: "health" } },
    "/v1/projects": {
      get: {
        operationId: "listProjects",
        parameters: [
          { name: "q", in: "query", schema: { type: "string", maxLength: 64 } },
          { name: "limit", in: "query", schema: { type: "integer", minimum: 1, maximum: 100 } },
        ],
      },
      post: {
        operationId: "createProject",
        security: [{ token: [] }],
        requestBody: {
          required: true,
          "x-body-limit": 16 * 1024,
          content: { "application/json": { schema: { $ref: "#/components/schemas/ProjectCreate" } } },
        },
      },
    },
    "/v1/projects/{id}": {
      get: {
        operationId: "getProject",
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer", minimum: 1 } }],
      },
    },
  },
  components: {
    securitySchemes: { token: { type: "http", scheme: "bearer" } },
    schemas: {
      Project: {
        type: "object",
        required: ["id", "name", "owner"],
        properties: {
          id: { type: "integer", minimum: 1 },
          name,
          owner: { type: "string", maxLength: 32 },
        },
      },
      ProjectCreate: {
        type: "object",
        required: ["name"],
        additionalProperties: false,
        properties: { name },
      },
    },
  },
});

console.log(json(doc));
