# 005: Extractors

Status: done (2026-10-13)

Typed access to the request, each failure answered by `rest::fail`.

## Acceptance criteria

- [x] Path parameters as integers or strings, query parameters, headers, and cookies
- [x] A JSON body into a struct through `rest::take<T>`, with 400 and field errors for
      an invalid body and 415 for another media type
- [x] Application extractors declared as `fn rest::from_request`, and the generator
      writes them for its types
- [x] `rest::once`, a lazy value computed on first call and kept for the request
- [x] A test for each failure's status and body

## What was built

`extract.goose`, listed in the README's "Extractors":

- `param`, `param_int`, `query`, `query_int`, `query_bool`, `header`, `cookie`,
  `int_of`, `bool_of`, and `require`. A failure is 400 `invalid_parameter` with
  `<name>: integer`, `boolean`, or `required`. A value with escapes is decoded into
  `cx.scratch`, a buffer `rest::serve` gives each request; one without is the
  request's own slice.
- `take<T>(cx) -> T` calls `from_request(cx, v: const T?)`, whose null `v` picks the
  overload. A `T` holding `u8[]` can't be filled after it's built (spike 05), so the
  overload returns it, built at the caller's destination.
- `json_body<R>`, which generated `from_request` overloads call: 415, the reader, and
  `fail_body`.
- `Once<T>` and `once`.

The generator writes a `from_request` for each object, and for each operation with query,
header, or cookie parameters a `<OperationId>Params` struct and its `from_request`,
checking `required`, integer bounds and `int32`, booleans, and string lengths. The router
takes both with `rest::take`, decodes string path parameters with `rest::path_str`, and
passes the struct after the path parameters (docs/generator.md, "Paths").

`test/test_extract.goose` checks each extractor and each failure byte for byte, and
`test_router.goose` the generated parameters, against the same if chain as before.
`test_generator.goose` checks each new refusal.

## Found on the way

- A block given a local `json::Reader` advances a copy
  ([findings](../docs/goose-findings.md#a-block-given-a-local-struct-gets-a-copy-of-it)).
  `json_body` passes `&r`.
- `test_generator.goose`, alone among the callers, couldn't store a parameter's name
  taken from its JSON string into the generator's table ("storing a reference rooted
  at n"). Two attempts at a minimal program compiled, so it isn't in the findings yet;
  the generator copies the name into its own `strs`.
