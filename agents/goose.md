# Writing Goose, and recording what it lacks

- Write Goose the way the pinned release's `samples/` and `stdlib/` do: flat data,
  references into growing arrays, `return ... from` for errors, untyped parameters for
  generics.
- When the compiler rejects something it should accept, miscompiles, or the stdlib
  lacks something, reduce it to a minimal program, record it in
  `docs/goose-findings.md`, and work around it here.
- Every finding names the Goose commit it was found on, the pin at the time (for a
  release, its commit). When one lacks it, recover it from this repository's history:
  the pin in the commit that added the entry.
- `docs/goose-findings.md` lists bugs first and feature requests after, each part from
  the least work a fix is expected to take to the most. Place a new entry by that
  order, and delete an entry once the pin has its fix (2026-10-14).
