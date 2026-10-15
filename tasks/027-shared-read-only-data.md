# 027: A helper for read-only data every worker shares

Status: todo (asked for 2026-10-15)

Data a program loads in `main`, such as records or prebuilt JSON, is copied into every
worker by `thread_spawn`, so it costs its size once per worker. Task 020 found this to
be most of goose-rest's extra memory on tiers A to C: the tier server keeps 4.5 to 71 MiB
per worker that goose-http's keeps once. goose-http's shared store, `import http.store`,
keeps one copy that every worker reads, but a goose-rest program has to wire it up
itself, and nothing in goose-rest's docs points a reader to it.

## How the records are laid out (2026-10-15)

Records in memory pay for how their strings are stored. A generated type's string with
`maxLength` is a limited array, which takes its full capacity, 4 bytes per code point
(task 033 cuts it to 1 for ASCII). One without it is a `u8[]`, exact, but it makes the
record variable-size: such records can't be elements of an array that's indexed or
shrunk, only of a sequential `T[]` or `T[>..]`, and can't be changed after they're built
(spec §3.3, §3.4, §4.4). The options, in the order to try them:

1. **Prebuilt JSON in `http::store`**, as the benchmark's template mode keeps it: the
   most compact, for data sent as it is rather than queried by field.
2. **A sequential array of exact records, with an index**: spec §3.3's own answer for
   random access to variable-size elements, a second array of references, 4 bytes
   each (`T&<u32 in pool>`). Lookup is O(1) and every string exact; a record can be
   replaced only by pushing another. That suits data built at startup and only read.
3. **A stored companion type**: for each schema type the generator would also write
   one with strings as ranges into one byte pool (`Str`), as the benchmark server keeps
   its records, with a function from the one to the other. Fixed-size, so records can
   be indexed and replaced; the most generator work. Only if programs need to change
   cached records in place.

## Acceptance criteria

- [ ] A goose-rest helper loads read-only data once and gives each worker's `cx.app` a
      view of the shared copy, built on `http::store`, with a program that uses it and
      a test that the data isn't copied per worker
- [ ] The tutorial's page 8, "Per worker", and page 1, "Workers and `main`", say what
      copying into every worker costs, and point to the helper
- [ ] The reference documents it, with what may and may not go in it (read-only, built
      before the workers start)
