# 6. The schema in TypeScript, Python, or Rust

`api.json` is plain OpenAPI 3.1. Any tool that produces OpenAPI can generate it, as long
as the output stays within the generator's supported [subset](../generator.md#the-subset).

## TypeScript

goose-rest provides [`ts/api.mts`](../../ts/api.mts), with TypeScript types covering
only that subset. Pass the document to `api()`, and `tsc` rejects unsupported keywords
and structures while you write it. TypeScript also lets you use comments and shared
constants, which JSON lacks. [`05-schema/api.mts`](05-schema/api.mts) produces the same
`api.json` as [the previous page](05-schema.md):

```ts
import { api, json } from "../../../ts/api.mts";

// A project's name, the same in what a client sends and what it gets back.
const name = { type: "string", minLength: 1, maxLength: 64 } as const;
```

```ts
      ProjectCreate: {
        type: "object",
        required: ["name"],
        additionalProperties: false,
        properties: { name },
      },
```

```sh
node docs/tutorial/05-schema/api.mts > docs/tutorial/05-schema/api.json   # Node 22.18+, or bun
```

The generator doesn't support `pattern` yet, so `tsc` rejects it before the generator
runs:

```text
error TS2322: Type '"^[a-z]+$"' is not assignable to type '"pattern isn't supported on a string"'.
```

`tsc` also rejects a `$ref` to a missing component, a `required` name that isn't a
property, and a path parameter not named in its template. The generator still checks
what the types can't: cycles, names, and numeric ranges. When `tsc` is installed,
`scripts/test.sh` type-checks this file along with `ts/` and checks that its output
matches the committed `api.json`
([development](../development.md#run-the-typescript-helpers-tests)).

## Python and Rust

A schema can also come from Python or Rust. pydantic models, or a FastAPI app, export
OpenAPI with their `$ref`s under `#/components/schemas`, and the generator reads the
`anyOf` with `null` that pydantic and schemars write for an optional value
([generator reference](../generator.md#export-it-from-python-or-rust)). A backend written in
another language and one written in Goose can then share a contract.

---

[Index](README.md) · Previous: [5. The API from a schema](05-schema.md) · Next:
[7. Middleware and scopes](07-middleware.md)
