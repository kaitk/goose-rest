# 003: The generator's types, readers, and writers

Status: done

A Goose program, `goose-rest gen`, reads an OpenAPI 3.1 subset and writes a struct, a
reader, and a `format` writer per schema, as the architecture doc's "With a schema"
shows. Starts before the runtime, since it doesn't depend on goose-http's API.

## Acceptance criteria

- [x] Objects, arrays, strings with length and format, integers and numbers with bounds,
      enums, nullable and optional fields, and `$ref`. `pattern` is refused until Goose's
      `regex` has anchors (docs/goose-findings.md).
- [x] Readers collect slices and build once, dispatch keys on `match key.len`, count
      code points for lengths, and reject unknown keys under
      `additionalProperties: false`
- [x] Writers write only declared fields, each key's bytes a constant
- [x] A construct outside the subset, or a `$ref` cycle, is an error naming it and its
      JSON pointer
- [x] Golden tests: schemas in `test/gen/`, their expected `_gen.goose`, compared byte
      for byte; and the generated code compiles and round-trips valid and invalid JSON.
      Generated files are `_gen.goose`, not `.gen.goose`: an import can't name a file
      with a dot in its name (docs/generator.md).
