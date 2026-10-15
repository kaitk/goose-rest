# 022: Write an OpenAPI document from the routes

Status: todo (planned for later, 2026-10-15)

Elysia writes an OpenAPI document from its routes and their schemas, and serves it
with a viewer. goose-rest reads OpenAPI as the generator's input today; writing one is
planned for later (2026-10-15, architecture doc). A program without a schema has only
`rest::on` calls in code, which Goose can't enumerate at run time, so the design has to
say where the document's routes, parameters, and types come from.

## Acceptance criteria

- [ ] A design in the architecture doc: where routes and types come from, and what a
      program writes to get a document
- [ ] Built, with a test that checks the document against the routes it serves
