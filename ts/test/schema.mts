// examples/schema/api.json, written with the helper: scripts/test.sh checks that its output is
// the same JSON and that the generator accepts it.
import { api, json } from "../api.mts";

const doc = api({
  "openapi": "3.1.0",
  "info": { "title": "goose-rest's schema example", "version": "1" },
  "paths": {
    "/health": { "get": { "operationId": "health" } },
    "/v1/projects": {
      "get": {
        "operationId": "listProjects",
        "parameters": [
          { "name": "q", "in": "query", "schema": { "type": "string", "maxLength": 64 } },
          { "name": "limit", "in": "query", "schema": { "type": "integer", "minimum": 1, "maximum": 100 } }
        ]
      },
      "post": {
        "operationId": "createProject",
        "security": [{ "token": [] }],
        "requestBody": {
          "required": true,
          "content": { "application/json": { "schema": { "$ref": "#/components/schemas/ProjectCreate" } } }
        }
      }
    },
    "/v1/projects/{id}": {
      "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "integer", "minimum": 1 } }],
      "get": { "operationId": "getProject" },
      "delete": { "operationId": "deleteProject", "security": [{ "token": [] }] }
    }
  },
  "components": {
    "securitySchemes": { "token": { "type": "http", "scheme": "bearer" } },
    "schemas": {
      "Project": {
        "type": "object",
        "required": ["id", "name"],
        "properties": {
          "id": { "type": "integer", "minimum": 1 },
          "name": { "type": "string", "minLength": 1, "maxLength": 64 }
        }
      },
      "ProjectCreate": {
        "type": "object",
        "required": ["name"],
        "additionalProperties": false,
        "properties": { "name": { "type": "string", "minLength": 1, "maxLength": 64 } }
      }
    }
  }
});

console.log(json(doc));
