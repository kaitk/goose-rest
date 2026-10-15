# The generator

`goose-rest gen` reads an OpenAPI 3.1 document and writes a Goose file with a struct, a
JSON reader, and a JSON writer for each schema under `components.schemas`, and a router,
`dispatch`, from its `paths` ([Paths](#paths)). The design and its reasons are in the
[architecture doc](architecture/README.md#the-generator). This page is the reference:
what the generator reads, what it writes, and what it refuses.

## Run it

The generator is a Goose program, `gen/main.goose`. Run it through TinyCC, or build it
once:

```sh
$GOOSE gen/main.goose -- gen api.json -o api_gen.goose
$GOOSE build -o build/goose-rest gen/main.goose
build/goose-rest gen api.json -o api_gen.goose --namespace api
```

`--namespace` names the generated file's namespace (default `api`), and `--handlers` the
namespace whose functions the router calls (default `app`). On an error, the generator
writes nothing and exits with status 1, printing the construct's JSON pointer:

```text
goose-rest: api.json: #/components/schemas/A/properties/c/pattern: not supported on a string
```

A program imports the file by its module name, so name it `<name>_gen.goose`, not
`<name>.gen.goose`: an import is identifiers separated by dots, and a dot in a file
name reads as a directory (spec §11.1). The file imports `json`, and `rest` when a
check or the router needs it, and `http` with a router, so the
program's root declares goose-rest and goose-http ([README](../README.md#quick-start)). It doesn't import the
handlers' module: the root does, wherever the module lives, and the router's qualified
calls find it.

## Write it in TypeScript

`ts/api.mts` types the subset below, so `tsc` rejects a keyword, a type, a format, or a
shape outside it while the document is being written. Copy it beside the contract, pass
the document to `api()`, and print it with `json()`:

```ts
import { api, json } from "./api.mts";

const doc = api({
  openapi: "3.1.0",
  info: { title: "Projects", version: "1" },
  components: {
    schemas: {
      Project: {
        type: "object",
        required: ["id"],
        properties: { id: { type: "integer", minimum: 1 }, name: { type: "string", maxLength: 64 } },
      },
    },
  },
});
console.log(json(doc));
```

```sh
tsc --noEmit --strict --allowImportingTsExtensions --module nodenext contract.mts
node contract.mts > api.json    # Node 22.18 or later, or bun
```

With Bun instead of Node, `bunx -p typescript tsc` runs the check.

`api()` keeps the document's literal types, so `tsc` also rejects a `$ref` to a missing
component, a `required` name that isn't a property, and a path parameter its template
doesn't name. The generator still checks what types can't: cycles, names that aren't
Goose identifiers or that collide, and number values such as a negative `maxLength`.
`ts/test/` checks which of the two rejects each construct.

## Export it from Python or Rust

A team that keeps its models in pydantic (2.x) exports them as the document's
components, with `$ref`s pointing there instead of at `$defs`:

```python
from pydantic.json_schema import models_json_schema

_, top = models_json_schema([(Settings, "validation")], ref_template="#/components/schemas/{model}")
doc = {"openapi": "3.1.0", "info": {"title": "Device", "version": "1"},
       "components": {"schemas": top["$defs"]}}
```

`test/gen/pydantic.json` is such an export, of pydantic 2.11.7, and the golden file
beside it what the generator writes from it. `Field(ge=, le=, min_length=, max_length=)`,
`Literal` of strings, `Optional[T] = None`, nested models, `list[T]`, and
`extra="forbid"` map onto the subset. Defaults other than `None`, unions other than with
`None`, and `pattern` are refused, each with its pointer. FastAPI writes a whole
document the same way, with paths. Rust's schemars writes optional values in the same
`anyOf` shape.

## The subset

| Schema | Goose |
|---|---|
| `"type": "object"` with `properties` | a struct, one field per property, in the schema's order |
| `"type": "string"` | `u8[]` |
| … with `maxLength: n` | `u8[..4n]`, a limited array: 4 bytes per code point |
| … with `maxLength: n` and `format` `uuid`, `date`, `date-time`, `email`, or `ascii` | `u8[..n]`: the format's values are ASCII, 1 byte per code point |
| `"type": "string"` with `enum` | a Goose enum, one variant per value |
| `"type": "integer"`, `"number"`, `"boolean"` | `i64`, `f64`, `bool` |
| `"type": "array"` with `items` | `T[]` |
| `"$ref": "#/components/schemas/X"` | `X`, for an object or enum; any other schema is read in place |
| a property not in `required` | `has_<field>: bool` before the field |
| `"type": ["T", "null"]` | `<field>_null: bool` before the field |
| `"anyOf": [<schema>, {"type": "null"}]`, in either order, with annotations and `"default": null` beside it | the schema, nullable, as above; pydantic and schemars write optional values this way |

A limited array takes its full capacity whatever the string's length, so a field of
`maxLength: 200` takes 800 bytes, and 200 with a format in the table's last row. That
suits a request's body, which lives for the request. A program that keeps many records
of a generated type, as a cache, keeps their strings as ranges into one byte array
instead ([tutorial](tutorial/08-state.md#per-worker)), or marks a string that holds
only codes or identifiers `format: ascii`
([tutorial](tutorial/04-json.md#size-a-string-in-bytes)).

Each kind takes these keywords besides `type`:

| Kind | Keywords |
|---|---|
| string | `minLength`, `maxLength`, `format` (`date`, `date-time`, `uuid`, `email`, `ascii`), `enum` (strings) |
| integer | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `format` (`int32`, `int64`) |
| number | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `format` (`float`, `double`) |
| object | `properties`, `required`, `additionalProperties` (`true` or `false`) |
| array | `items`, `minItems`, `maxItems` |

Any schema may carry `description`, `title`, `examples`, `example`, `deprecated`, and
`$comment`, which the generator ignores. Any other keyword is an error, among them
`pattern`, `default`, `const`, `multipleOf`, `uniqueItems`, `oneOf`, `anyOf` other than
with null (above), `allOf`, `not`, `readOnly`, `writeOnly`, and OpenAPI 3.0's
`nullable`. So are:

- A `$ref` outside `#/components/schemas/`, a `$ref` with a keyword beside it other than
  an annotation, and a cycle of `$ref`s.
- An object that holds itself, directly or through other objects or arrays (a
  recursive schema). A struct can't hold itself, and a recursive reader can't keep its
  slices across the call (architecture doc).
- An array of arrays, a nullable array element, an object without `properties`, and
  enum values that aren't strings.
- Bounds that leave no value, in a schema or a parameter's: `minLength` above `maxLength`, `minItems` above `maxItems`,
  a lower `minimum` or `exclusiveMinimum` that meets or passes the upper bound (for
  `int32`, the type's range counts as a bound), and a length a format can't have, such as
  `maxLength: 35` on a `uuid` (36 characters), a `date` (10), a `date-time` (20 or more),
  or an `email` (5 to 254). A `required` that names a property twice.
- `pattern`, until Goose's `regex` has anchors
  ([findings](goose-findings.md#the-regex-module-has-no-anchors-so-json-schemas-pattern-cant-be-checked)).

Formats are checked as follows (`check.goose`): `date` and `date-time` as RFC 3339,
with days that exist; `uuid` as 8-4-4-4-12 hex digits; `email` as a dot-atom address
whose domain has two or more labels, without quoted local parts or address literals;
`ascii` as bytes below 0x80, so a name with an accent or an emoji fails with
`<field>: format`, as a malformed `uuid` does. `ascii` isn't a format JSON Schema
defines. A validator that doesn't know a format ignores it, so a client's validator
accepts a value that isn't ASCII, and only goose-rest refuses it.

## Names

- A component's name is its type's name and must be a Goose identifier. A type declared
  inline is named after its parent and property in PascalCase, `Project` and `owner`
  making `ProjectOwner`, with `Item` after an array's element.
- A property's field is its name in snake_case: `createdAt` becomes `created_at`,
  `HTTPServer` `http_server`, and a Goose keyword gets a trailing `_` (`type_`).
- An enum's variants are its values in PascalCase: `in-review` becomes `InReview`.
- Two names that come out the same, a property name the snake_case form can't express,
  and a field named after one of the reader's own locals (`r`, `scratch`, `key`, and a
  few ending in `_`) are errors.

## The code

For a schema `Project`, the file has:

- `struct Project`.
- `fn read_project(r: json::Reader&, scratch: u8[>..]&) -> Project`, the reader.
- `fn read_project_<field>(r, scratch) -> T[>..]` for each array field.
- `fn format(out: u8[>..]&, v: const Project&)`, the writer, which `rest::json` finds by
  its namespace (spike 07).
- `fn rest::from_request(cx, v: const api::Project?) -> api::Project`, the extractor
  `rest::take<api::Project>(cx)` calls: it reads the JSON body with the reader, and
  fails with 415 for another media type and 400 `invalid_body` for a body the reader
  refuses ([reference](reference.md#extractors)).

For an enum `Status`: `enum Status`, `fn status_of(s) -> Status, bool`, and `fn
format(out, v: Status)`.

The reader takes two passes over an object. The first reads each key as it arrives,
dispatching on `match key.len` and then comparing bytes. It reads a scalar into a local
and keeps a string as a slice, of the text or of `scratch` for one with escapes. For an
object or array value it records only where the value starts and skips it. A repeated
key overwrites the earlier one, and an unknown key is skipped, or an error under
`additionalProperties: false`. Then come the checks, in property order. The second
pass builds the struct with one literal, in place, reading each nested value from
where it starts, and then puts the cursor back after the object. A struct holding a
`u8[]` field can't be assigned or filled after construction (spike 05), so a nested
object can't be read into a local first.

Errors go through the reader's sticky error, `json::fail`, so `json::finish` reports the
first one and where it was: `id: required`, `name: maxLength`, `tags[]: maxLength`,
`status: enum`, `unknown member`. A string with a length check must be UTF-8 (`name:
not UTF-8`), and its length counts code points. After an error, a reader returns the
type's empty value without building it, so a string that fails `maxLength` never
overruns its field.

The writer writes the declared fields only, in the schema's order, each key and its
punctuation a constant: `out.append(",\"name\":")`. It leaves out an optional field whose
`has_` is false, and writes `null` for one whose `_null` is true. Where the fields before
a key may all have been left out, the writer checks the last byte for the object's `{`
to know whether a comma is due.

## Paths

A document with `paths` also gets `fn dispatch(cx)`, which answers a
request through the handler its path and method name. A program calls it from
`rest::serve`:

```rust
let e = rest::serve(cfg, app) { cx => api::dispatch(cx) };
```

### What it reads

| OpenAPI | Goose |
|---|---|
| A path, `/projects/{id}` | matched segment by segment; a parameter takes a whole, non-empty segment |
| An operation, `get`, `post`, ... | a call to `<handlers>::<operationId in snake_case>` inside `rest::route` |
| A path parameter, `"type": "integer"` | an `i64` from `rest::path_int`, checked against `minimum`, `maximum`, and `format: int32` |
| A path parameter, `"type": "string"`, with `format: ascii` or none | the segment, decoded, from `rest::path_str`, checked as ASCII for `format: ascii` |
| Query, header, and cookie parameters | a struct, `<OperationId>Params`, read by `rest::take` (below) |
| `requestBody` with `application/json` and a `$ref` to an object | the object, from `rest::take`; 415 for another media type |
| `"x-body-limit": n` on a `requestBody`, a positive byte count | `rest::body(cx, n)` before `rest::take`, so the route takes a body of up to `n` bytes, not 1 MB; 413 past it |
| `security: [{"<scheme>": []}]`, on the operation or the document | `<handlers>::security_<scheme>(cx)`, whose result the handler gets |

The router's namespace also gets `MAX_BODY`, the largest `x-body-limit` or 1 MB, for
`http::Config { max_body: api::MAX_BODY, .. }`. goose-http refuses a body past it with a
413 of its own, without a body, before the route runs.

A handler takes `cx`, then the security check's result if the operation names
a scheme, its path parameters in the template's order, its parameters struct, and its
body. For `GET /projects/{id}` with `security: [{"session": []}]`:

```rust
fn get_project(cx, s, id: i64) { ... }    // in app, the handlers' namespace
fn security_session(cx) -> Session { ... }
```

Handlers and security checks reach the worker's state through `cx.app` and the
request's through `cx.state`. `rest::serve(cfg, app, fresh)` supplies both, and
`rest::serve(cfg, app)` uses `rest::NoState` for the request.

An operation's `security: []` overrides the document's. A path item's `parameters`
apply to each of its operations, and an operation's own replace one of the same name
and place.

An operation with query, header, or cookie parameters gets a struct of them, named after
its `operationId` in PascalCase with `Params` after it, and a `fn rest::from_request`
that reads and checks each. The struct holds the path item's parameters, then the
operation's own, each a field in snake_case: `X-Request-Id` becomes `x_request_id`.
An optional parameter has a `has_<field>: bool` before its field.

| Schema | Field | Read with |
|---|---|---|
| `"type": "integer"`, with `minimum`, `maximum`, `format` (`int32`, `int64`) | `i64` | `rest::int_of` |
| `"type": "boolean"` | `bool`, from `true` or `false` | `rest::bool_of` |
| `"type": "string"`, with `minLength`, `maxLength`, `format: ascii` | `const u8[:]`, a query parameter decoded with `+` as a space | as it is |

A query parameter's value is decoded; a header's and a cookie's are given as sent. A
parameter that's missing when `required`, malformed, or outside its schema fails the
route with `400 {"error":"invalid_parameter","detail":"page: minimum"}`, named as the
document names it. For `listProjects` with an optional integer `page` and a required
string `q`:

```rust
struct ListProjectsParams { has_page: bool, page: i64, q: const u8[:] }

fn list_projects(cx, s, q) { ... q.page ... }    // in app
```
`summary`, `description`, `tags`, `deprecated`, `externalDocs`, `responses`, and a
parameter's `description`, `deprecated`, and examples are read for nothing. The
handler writes the response; `responses` isn't checked against it.

### What it refuses

Each of these is an error at its JSON pointer:

- A path that doesn't start with `/`; a literal segment with `%`, `{`, or `}`;
  a parameter named twice in one path; two paths that match the same requests, such as
  `/a/{id}` and `/a/{key}`.
- An operation without `operationId`, an `operationId` that isn't a Goose identifier in
  snake_case, and two that make the same handler name.
- A parameter `in` anything but the path, the query, a header, or a cookie; a path
  parameter without `required: true`, or one the template doesn't name; a template
  parameter no parameter declares; a parameter's `style`, `explode`, or `content`; a
  `required` that isn't `true` or `false`; a parameter repeated in one list.
- A path parameter's schema other than an integer or a string, and on a string any
  keyword but `format: ascii`. Another parameter's other than an integer, a boolean, or
  a string with `minLength`, `maxLength`, and `format: ascii`, so `default`, `enum`, and
  arrays among them, and a `format` other than `ascii`.
- A header parameter named `Accept`, `Content-Type`, or `Authorization`, which OpenAPI
  says to ignore.
- A path parameter or handler named after one of `dispatch`'s locals (`cx`, `state`,
  `allow`, `path`, `m`, `plain`, `s_`, `q_`, `body_`, and `s` or `e` followed by digits); another
  parameter named `cx`, `v`, or `n_`; two parameters whose fields, `has_` fields, or
  locals come out the same; a parameters struct named as another type.
- A request body that isn't `required: true`, isn't `application/json`, or isn't a
  `$ref` to an object component.
- More than one security requirement (alternatives), more than one scheme in one,
  scopes, and a scheme `components.securitySchemes` doesn't declare.
- Any other key on a path item, an operation, a parameter, or a request body, such as
  `servers`, `callbacks`, or `$ref`.

### How it matches

`dispatch` answers as an if chain of `http::on` over the same routes in the same order
would, with two differences: a parameter is typed, so `/users/me/avatar` for
`/users/{id}/avatar` is a 400 where the chain calls the handler with `id` `me`, and
where a concrete path and a template both match a path, the concrete one wins, as
OpenAPI says, where the chain takes whichever comes first. `test/test_router.goose`
checks the rest byte for byte against such a chain.

1. An unknown method is 501, and a path with a dot-segment or an escaped control byte
   400, as `rest::otherwise` answers them.
2. A path without `%` is compared with the static paths by `match path.len`, then
   bytes.
3. Then the path is walked segment by segment. At each segment the literals come first,
   in the document's order, then a parameter; a branch that doesn't answer falls
   through to the next. A literal compares with `==`, or, in a path with `%`, as
   `http::on` compares it: an escape of an unreserved byte matches the byte.
4. A path that matched runs its method's operation, `GET`'s for `HEAD` too. Another
   method gets 405, and `OPTIONS` 204, each with the path's `Allow`, a constant, after
   the methods in `allow` (below).
5. A path nothing matched is 404, or 204 for `OPTIONS *`. Where `allow` isn't empty,
   it gets 405, or `OPTIONS` 204, with `allow` alone.

`dispatch` reads `allow` from `rest::allow_before(cx)`: the `Allow` collected by
hand-written routes in the surrounding `rest::routes` block, or an empty string with
`rest::NoRouter`. A path matched by a hand-written route, a generated one, or both
answers another method as one router would, listing the hand-written routes' methods first
([tutorial](tutorial/05-schema.md#generated-and-hand-written-routes)):

```rust
rest::routes(cx) { cx =>
    if rest::on(cx, "PUT", "/uploads/:name") {
        rest::route(cx) { upload(cx, rest::param(cx, "name")); };
    } else {
        api::dispatch(cx);
    }
};
```

`rest::scope(cx, prefix)` narrows the path for hand-written matching. `dispatch`
matches the full request path from the schema. A generated handler gets each path
parameter as an argument; a helper that calls `rest::param` inside a routes block
reads the last hand-written match instead.

Each answer is in goose-rest's error shape ([reference](reference.md#errors)). A route checks the security scheme first,
then the path parameters, the other parameters, and the body, and answers the first
failure: a path parameter that doesn't fit its schema is `400
{"error":"invalid_parameter","detail":"id: minimum"}`.

## Tests

`test/gen/` holds schemas and the files the generator writes from them, the golden
files. `scripts/test.sh` regenerates each and compares it byte for byte.
`test/test_gen.goose` round-trips valid and invalid JSON through `test/gen/api_gen.goose`,
`test/test_router.goose` runs `test/gen/routes_gen.goose` against an if chain of the same
routes, with the handlers in `test/gen/app.goose`, and `test/test_generator.goose` checks
each error above. After changing the generator, regenerate the golden files and read the
diff:

```sh
$GOOSE gen/main.goose -- gen test/gen/api.json -o test/gen/api_gen.goose
$GOOSE gen/main.goose -- gen test/gen/routes.json -o test/gen/routes_gen.goose
```
