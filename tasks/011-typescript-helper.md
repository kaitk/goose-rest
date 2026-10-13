# 011: The TypeScript helper

Status: todo (decided 2026-10-13; the helper isn't built yet)

Settle the open question in the architecture doc: a `.ts` file typed to the subset that
writes `api.json`.

## Acceptance criteria

- [x] Decided whether it lives here or in its own repository, recorded with the reason
- [ ] Its types describe the subset, and `tsc` rejects every keyword, type, format, and
      shape outside it, checked by a test of each that names whether `tsc` or the
      generator rejects it (reworded 2026-10-13, below)
- [x] Decided whether it exports from valibot, with the lossy cases listed

## Where it lives

Decided (2026-10-13): here, in `ts/`, until the subset stops changing. The helper's
types are a second statement of `docs/generator.md`'s subset, and the subset still grows:
`pattern` comes once Goose's `regex` has anchors. In this repository, the commit that
teaches the generator a keyword also changes the types and their `tsc` test. In another
one, each such change is two commits, and each helper version has to say which goose-rest
commits it matches. goose-rest stays free of a JavaScript toolchain: `scripts/test.sh`
runs the `tsc` tests only where `tsc` is installed, and says when it skips them.

What would change this: publishing the helper to npm. npm can't install a package
from a subfolder of a git repository (pnpm can), so users would need a published package, which
can still be built from `ts/` here. A repository of its own pays off once the subset
settles and the helper gains users who don't use goose-rest.

The second criterion can't be met as written. TypeScript types can reject every keyword,
type, format, and shape outside the subset, but not all the values and names
`docs/generator.md` refuses:

| The generator refuses | `tsc` can reject it |
|---|---|
| A keyword outside the subset (`pattern`, `default`, `const`, `oneOf`, `nullable`, and so on) | Yes |
| A format other than `date`, `date-time`, `uuid`, `email`, `int32`, `int64`, `float`, `double` | Yes |
| An array of arrays, a nullable array element, an object without `properties`, a non-string enum value | Yes |
| `additionalProperties` other than `true` or `false` | Yes |
| A `$ref` outside `#/components/schemas/`, or with a keyword beside it | Yes |
| A `$ref` to a component that doesn't exist, a `required` name that isn't a property | Yes, if the document goes through a generic function that infers its literal types |
| A field named after a reader local (`r`, `scratch`, `key`, and the rest) | Yes, against a fixed list, with the same inference |
| A cycle of `$ref`s, or an object that holds itself | No |
| A component name that isn't a Goose identifier, or two names equal after snake_case | Not in practice |
| A negative or fractional `maxLength`, or `minLength` above `maxLength` | No |

Decided (2026-10-13): the criterion now reads "`tsc` rejects every keyword, type,
format, and shape outside the subset", and the generator stays the check for the rest.
Each test names which of the two rejects its construct.

## Exporting from valibot

Decided (2026-10-13): the helper doesn't export from valibot. valibot already has an
exporter, `@valibot/to-json-schema` (`target: 'draft-2020-12'`; by default it throws on
what it can't convert). An application can put its output under `components.schemas`,
where the generator refuses whatever falls outside the subset. A wrapper in the helper
would add little to that. It also couldn't fix the cases where the export succeeds and
the two backends still validate differently. The conformance tests over HTTP stay the
check for those, as the architecture doc says.

What would change this: a second application ported from valibot, which would make a
recipe or a stricter wrapper worth keeping. Such a wrapper would refuse the silent
cases below rather than export them.

The lossy cases, from the exporter's README and docs/generator.md (2026-10-13):

Silent: the export succeeds, and the backends differ.

- `minLength` and `maxLength`. valibot counts UTF-16 code units (JavaScript's
  `length`), and JSON Schema and the generated readers count code points. An emoji
  counts 2 in valibot and 1 in Goose, so Goose accepts strings valibot refuses.
- Transforms, such as `v.trim()`, `v.toLowerCase()`, and `v.transform()`. They have no
  JSON Schema form, so the export throws, or drops them with `errorMode: 'ignore'`. The
  Goose backend then stores `" name "` where the TypeScript one stores `"name"`.
- Formats whose checks differ. `v.isoDateTime()` takes `yyyy-mm-ddThh:mm`, with a
  space allowed for the `T`, no seconds or offset, and days that don't exist
  (`2023-06-31T00:00`). goose-rest's `date-time` takes RFC 3339 with seconds and an
  offset, and checks the day. `v.email()`'s regex and goose-rest's dot-atom check
  haven't been compared case by case.
- Integers beyond 2^53. Goose reads them exactly as `i64`; JavaScript's `number`
  rounds them, unless the schema adds `v.safeInteger()`.
- Custom checks: `v.check()`, `v.custom()`, and cross-field checks such as
  `v.forward()` and `v.partialCheck()`. They have no JSON Schema form.

Refused by the generator, so the error is loud:

- `v.regex()` becomes `pattern`. Pattern-like actions such as `v.hexColor()` and
  `v.digits()` probably do too; not checked.
- `v.union()` and `v.variant()` become `anyOf`/`oneOf`, `v.intersect()` `allOf`, and
  `v.literal()` `const`.
- `v.multipleOf()`, tuples, `v.record()`, `v.objectWithRest()` with a schema for the
  rest, and `v.lazy()` (recursion).
- A default, as in `v.optional(s, value)`.
- Formats outside goose-rest's four, such as `v.url()` and `v.ipv4()`.

The rest maps onto the subset, as far as the exporter's README says: `v.object()`,
`v.strictObject()`, `v.optional()`, `v.nullable()`, `v.nullish()`, `v.picklist()` of
strings, `v.integer()`, and the bounds `v.minValue()`, `v.maxValue()`, `v.gtValue()`, and
`v.ltValue()` on numbers. No schema has been exported and run through the generator yet;
the keywords the exporter writes for `nullable` and `strictObject` are the first thing
to check if this is decided the other way.

Paths, operations, and parameters aren't schemas, so they come from the helper or are
written by hand either way.
