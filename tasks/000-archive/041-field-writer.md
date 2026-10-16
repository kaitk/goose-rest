# 041: A JSON writer from a struct's fields

Status: done

Goose `v2026.2` adds `const for` (spec §6, "Specialization-time expansion"), whose
`fields<T>` source gives each field's name and accessor at specialization time. A
hand-written `format` overload that lists every field as a JSON key can become one call,
`rest::format_fields(out, v)`, which can't fall behind the struct the way a hand-written
list can. This is the part of serde's derive that `const for` v1 reaches.

What v1 can't do sets the scope:

- The writer only. A reader needs each field's type to pick how to read it, and v1
  binds a name and an accessor, not a type (the `const for` design's future work: a
  `<N, A, U>` binding). A struct holding a string can't be filled field by field, and
  the expected result type never selects an overload (§7.1), so a generic reader isn't
  reachable. Readers stay hand-written or generated.
- Every field, named as declared. v1 has no annotations, so no renamed key, no left-out
  field, and no `has_` flag. The generator's writers keep doing those, and so does a
  hand-written `format` that needs them.
- The generator stays: its writers rename keys to the schema's spelling and leave out
  unset optional fields, and its readers and router come from the schema.

Dispatching on a field's type is the subtle part. An untyped catch-all, which hands a
struct or enum to the program's own `format`, ranks as a generic exact match, and so
does `T[]` against a resizable array, so the two tie (§7.1 makes a tie an error). A
bounded array (`u8[..256]`) or a fixed one (`u8[16]`) matches no `T[]` pattern exactly
and reaches a slice only through coercion, which also ties with the catch-all. The
catch-all therefore takes its last argument as an `f64`, passed an `i32`: an integer
converted to a float is the last resort (§7.1), so every other candidate wins over it.
Spiked on `v2026.2` (2026-10-16) with `u8[..256]`, `u8[]`, `i64[]`, `u8[16]`,
`u8[..8][]`, a nested struct, an enum, and an optional.

Two more ties came up while building it. A writer for `T?` matches any value by
coercion, so it tied with `i64`'s writer for an `i32` field and with the slice's for a
bounded array; it was dropped, and an optional goes through the catch-all, which
writes `null` or the value by Goose's `format` (an optional string isn't quoted). A
`u64` reached both `f64`'s writer and the catch-all as a last resort, and a `u8` would
widen to both `i64` and `u64`, so each integer type has a writer of its own.

## Acceptance criteria

- [x] `rest::format_fields(out, v)` writes a struct as a JSON object, its fields in
      declaration order, keyed by their names: integers as numbers, `f64` through
      `json::format_number`, `bool`, any `u8` array or slice as a JSON string, other
      arrays and slices as JSON arrays, an optional as `null` or its value, and a
      struct or enum through the program's `format` overload for it.
- [x] A test under `test/` covers each field kind, a nested struct written with
      `format_fields` itself, an empty struct, and a key escaped nowhere (names are
      identifiers): `test/check/format_fields.goose`, whose output Python's `json`
      reads back.
- [x] The tutorial's and examples' hand-written writers whose keys are exactly their
      struct's fields call `format_fields`, and their golden outputs are unchanged:
      tutorials 04, 05, 10, 11, 12, and 13. Writers that rename or leave out a field
      stay as they are: 02's `Project` leaves out `archived`, 14's `Attached` leaves out
      an empty `note`, and each example's writer leaves out a field or computes one.
- [x] `docs/reference.md` documents `format_fields`, what it writes, and what it
      can't (renames, omissions, reading). `docs/architecture.md`'s "No derive" says
      what `const for` gives and what it doesn't. `docs/decisions.md` records the
      decision and the catch-all's ranking.
- [x] `scripts/test.sh` passes on macOS (2026-10-16).

No benchmark: the benchmark servers write through generated writers, which this
leaves unchanged.
