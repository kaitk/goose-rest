# 13: Validation beyond the schema

Status: todo (asked for 2026-10-20)

Aegon's validation ([its guide](https://udaykhare09.github.io/Aegon/guide/validation),
read 2026-10-20) runs a struct's `validate` method when a body, query, or path is bound,
and answers 422 with every violation. Its rules: required, minimum and maximum length,
email, minimum and maximum, positive, not nil (UUID), past and future (timestamps), and
a custom predicate with its message. Nested objects, optional ones, and arrays prefix
their violations (`shipping_address.zip`, `items[1].quantity`). The same rules run on
their own, outside a request.

goose-rest's generated readers already check most of these from the schema
(`docs/generator.md`, §4): lengths, bounds (exclusive ones included, so positive is
`exclusiveMinimum: 0`), `email`, `uuid`, `date`, `date-time`, enums, and the
parameters' bounds. Collecting every violation is subtask 02. What's left:

- **Checks the schema can't say.** Past and future timestamps, a field required only
  when another is set, an end date after the start, a slug without spaces. A
  handler-side hook, such as a `fn check(v&, x: const T&)` that the generated reader
  calls after its own checks, found by name as `format` is. Its violations join the
  generated ones, with JSON pointers.
- **Hand-written structs.** A program without OpenAPI binds a body with its own reader.
  The same checks, and the same violation list and answer, should be available to it.
- **Binding a query or a form into a struct.** Aegon's `bind_query<T>`, `bind_form<T>`,
  and `bind_path<T>` fill a struct and validate it. goose-rest reads each parameter
  with its own extractor. A struct reader generated for a query or form, as the
  generator writes one for a body, would give the same in one call.
- **Validation outside a request.** A configuration file (subtask 12), a message from a
  queue, or a test checks a struct with the same functions and gets the same list.
- **`pattern`.** Refused until Goose's `regex` has anchors (`docs/goose-findings.md`).
  Recheck at each Goose release.
- **Not nil.** A UUID of zeros, which the schema can't refuse without `pattern` or
  `not`.

## Acceptance criteria

- [ ] A check hook for generated structs, its violations merged with the generated ones
- [ ] The same violation list and answer for hand-written structs, and outside a request
- [ ] Past, future, and cross-field checks shown in a best-practices program
- [ ] `docs/reference.md` updated, with golden tests for each case
