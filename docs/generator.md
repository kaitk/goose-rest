# The generator

`goose-rest gen` reads an OpenAPI 3.1 document and writes a Goose file with a struct, a
JSON reader, and a JSON writer for each schema under `components.schemas`. The design
and its reasons are in the [architecture doc](architecture/README.md#the-generator).
This page is the reference: what the generator reads, what it writes, and what it
refuses.

It reads `components.schemas` only. Paths become routes in tasks 007 and 008.

## Run it

The generator is a Goose program, `gen/main.goose`. Run it through TinyCC, or build it
once:

```sh
$GOOSE gen/main.goose -- gen api.json -o api_gen.goose
$GOOSE build -o build/goose-rest gen/main.goose
build/goose-rest gen api.json -o api_gen.goose --namespace api
```

`--namespace` names the generated file's namespace (default `api`). On an error, the
generator writes nothing and exits with status 1, printing the construct's JSON
pointer:

```text
goose-rest: api.json: #/components/schemas/A/properties/c/pattern: not supported on a string
```

A program imports the file by its module name, so name it `<name>_gen.goose`, not
`<name>.gen.goose`: an import is identifiers separated by dots, and a dot in a file
name reads as a directory (spec §11.1). The file imports `json`, and `rest` when a
check needs it, so the program's root declares goose-rest and goose-http (README,
"Use").

## The subset

| Schema | Goose |
|---|---|
| `"type": "object"` with `properties` | a struct, one field per property, in the schema's order |
| `"type": "string"` | `u8[]` |
| … with `maxLength: n` | `u8[..4n]`, a limited array: 4 bytes per code point |
| `"type": "string"` with `enum` | a Goose enum, one variant per value |
| `"type": "integer"`, `"number"`, `"boolean"` | `i64`, `f64`, `bool` |
| `"type": "array"` with `items` | `T[]` |
| `"$ref": "#/components/schemas/X"` | `X`, for an object or enum; any other schema is read in place |
| a property not in `required` | `has_<field>: bool` before the field |
| `"type": ["T", "null"]` | `<field>_null: bool` before the field |

Each kind takes these keywords besides `type`:

| Kind | Keywords |
|---|---|
| string | `minLength`, `maxLength`, `format` (`date`, `date-time`, `uuid`, `email`), `enum` (strings) |
| integer | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `format` (`int32`, `int64`) |
| number | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `format` (`float`, `double`) |
| object | `properties`, `required`, `additionalProperties` (`true` or `false`) |
| array | `items`, `minItems`, `maxItems` |

Any schema may carry `description`, `title`, `examples`, `example`, `deprecated`, and
`$comment`, which the generator ignores. Any other keyword is an error, among them
`pattern`, `default`, `const`, `multipleOf`, `uniqueItems`, `oneOf`, `anyOf`, `allOf`,
`not`, `readOnly`, `writeOnly`, and OpenAPI 3.0's `nullable`. So are:

- A `$ref` outside `#/components/schemas/`, a `$ref` with a keyword beside it other than
  an annotation, and a cycle of `$ref`s.
- An object that holds itself, directly or through other objects or arrays (a
  recursive schema). A struct can't hold itself, and a recursive reader can't keep its
  slices across the call (architecture doc).
- An array of arrays, a nullable array element, an object without `properties`, and
  enum values that aren't strings.
- `pattern`, until Goose's `regex` has anchors
  ([findings](goose-findings.md#the-regex-module-has-no-anchors-so-json-schemas-pattern-cant-be-checked)).

Formats are checked as follows (`check.goose`): `date` and `date-time` as RFC 3339,
with days that exist; `uuid` as 8-4-4-4-12 hex digits; `email` as a dot-atom address
whose domain has two or more labels, without quoted local parts or address literals.

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
- `fn push_project(v: Project[>..]&, r, scratch)` when an array holds `Project`. An
  array reader calls it rather than pushing from its block, to work around a compiler
  gap ([findings](goose-findings.md#a-block-cant-push-a-value-whose-call-grows-a-parameters-array)).
- `fn format(out: u8[>..]&, v: const Project&)`, the writer, which `rest::json` finds by
  its namespace (spike 07).

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

## Tests

`test/gen/` holds schemas and the files the generator writes from them, the golden
files. `scripts/test.sh` regenerates each and compares it byte for byte.
`test/test_gen.goose` round-trips valid and invalid JSON through `test/gen/api_gen.goose`,
and `test/test_generator.goose` checks each error above. After changing the generator,
regenerate the golden files and read the diff:

```sh
$GOOSE gen/main.goose -- gen test/gen/api.json -o test/gen/api_gen.goose
```
