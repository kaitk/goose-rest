# 022: Write an OpenAPI document from the routes

Status: todo (planned for later, 2026-10-15)

Elysia writes an OpenAPI document from its routes and their schemas, and serves it
with a viewer. goose-rest reads OpenAPI as the generator's input today; writing one is
planned for later (2026-10-15, `docs/decisions.md`). A program without a schema has only
`rest::on` calls in code, which Goose can't enumerate at run time, so the design has to
say where the document's routes, parameters, and types come from.

## Acceptance criteria

- [ ] A design in `docs/decisions.md`: where routes and types come from, and what a
      program writes to get a document
- [ ] Built, with a test that checks the document against the routes it serves
