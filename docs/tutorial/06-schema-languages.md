# 6. The schema in TypeScript, Python, or Rust

`api.json` is plain OpenAPI 3.1, and any tool that writes OpenAPI can write it, as long
as it stays inside the [subset](../generator.md#the-subset) the generator reads.

## TypeScript

goose-rest's own helper is [`ts/api.mts`](../../ts/api.mts): TypeScript types that
describe only that subset. A file passes the document to `api()`, and `tsc` refuses a
keyword or a shape the generator doesn't read while you type it, with comments and
shared constants that JSON lacks. [`05-schema/api.mts`](05-schema/api.mts) writes the
same `api.json` as [the previous page](05-schema.md):

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

A `pattern`, which the generator doesn't support yet, fails at `tsc`, before the
generator runs:

```text
error TS2322: Type '"^[a-z]+$"' is not assignable to type '"pattern isn't supported on a string"'.
```

`tsc` also refuses a `$ref` to a missing component, a `required` name that isn't a
property, and a path parameter its template doesn't name. The generator still checks
what types can't: cycles, names, and number ranges. `scripts/test.sh` type-checks this
file with `ts/`, and checks that it prints the committed `api.json`, where `tsc` is
installed ([development](../development.md#run-the-typescript-helpers-tests)).

## Python and Rust

A schema can also come from Python or Rust. pydantic models, or a FastAPI app, export
OpenAPI with their `$ref`s under `#/components/schemas`, and the generator reads the
`anyOf` with `null` that pydantic and schemars write for an optional value
([generator reference](../generator.md#export-it-from-python-or-rust)). A backend in
another language and a Goose one can then share one contract.

---

[Index](README.md) · Previous: [5. The API from a schema](05-schema.md) · Next:
[7. Middleware and scopes](07-middleware.md)
