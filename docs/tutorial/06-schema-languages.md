# 6. The schema in TypeScript, Python, or Rust

`api.json` is plain OpenAPI 3.1. Any tool that writes OpenAPI can make it, as long as
the output stays within the generator's [subset](../generator.md#4-the-subset).

## TypeScript

Plod provides [`ts/api.mts`](../../ts/api.mts), with TypeScript types for only
that subset. Pass the document to `api()`, and `tsc` rejects unsupported keywords
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

A string whose values are ASCII, such as a login, takes `format: "ascii"`, which sizes
it at one byte per character ([JSON bodies](04-json.md#size-a-string-in-bytes)). The
types accept it beside `date`, `date-time`, `uuid`, and `email`:

```ts
          owner: { type: "string", format: "ascii", maxLength: 32 },
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
([generator reference](../generator.md#3-export-it-from-python-or-rust)). A backend written in
another language and one written in Goose can then share a contract.

Neither tool has a type for `format: ascii`, so each adds the keyword by hand. In
pydantic, `json_schema_extra` merges it into the field's schema
([`05-schema/pydantic`](05-schema/pydantic/project.py)):

```python
from pydantic import BaseModel, Field

class Project(BaseModel):
    color: str = Field(max_length=7, json_schema_extra={"format": "ascii"})
```

This writes `{"type": "string", "maxLength": 7, "format": "ascii"}` (checked with
pydantic 2.14.1). In schemars 1.x, `extend` does the same
([`05-schema/schemars`](05-schema/schemars/src/main.rs)):

```rust
#[derive(JsonSchema)]
struct Project {
    #[schemars(length(max = 7), extend("format" = "ascii"))]
    color: String,
}
```

This writes `{"type": "string", "format": "ascii", "maxLength": 7}` (checked with
schemars 1.2.3). Neither tool enforces the format: pydantic still accepts `"é"` for
`color`, so only Plod refuses it.

---

[Index](README.md) · Previous: [5. The API from a schema](05-schema.md) · Next:
[7. Middleware and scopes](07-middleware.md)
