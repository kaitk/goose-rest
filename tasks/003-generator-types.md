# 003: The generator's types, readers, and writers

Status: todo

A Goose program, `goose-rest gen`, reads an OpenAPI 3.1 subset and writes a struct, a
reader, and a `format` writer per schema, as the architecture doc's "With a schema"
shows. Starts before the runtime, since it doesn't depend on goose-http's API.

## Acceptance criteria

- [ ] Objects, arrays, strings with length and format, integers and numbers with bounds,
      enums, nullable and optional fields, and `$ref`
- [ ] Readers collect slices and build once, dispatch keys on `match key.len`, count
      code points for lengths, and reject unknown keys under
      `additionalProperties: false`
- [ ] Writers write only declared fields, each key's bytes a constant
- [ ] A construct outside the subset, or a `$ref` cycle, is an error naming it and its
      JSON pointer
- [ ] Golden tests: schemas in `test/`, their expected `.gen.goose`, compared byte for
      byte; and the generated code compiles and round-trips valid and invalid JSON
