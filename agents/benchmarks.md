# Benchmarks

- Every number comes with how it was measured: machine, kernel, command, worker and
  connection counts, and run count. A result without them doesn't go in a doc.
- goose-rest is measured on goose-http's REST tiers and its own (`docs/benchmarks.md`), against goose-http alone and
  against Axum, actix-web, ntex, dusty (Zig), and, from task 048, Aegon (C++, 2026-10-19)
  in their fastest documented configuration,
  built in release mode, with the same worker count. Each framework serves through its
  own router, extractors, and middleware, not one catch-all handler. Losses are recorded as plainly as wins.
- A framework that fails a cell's checks isn't measured there: the README's cell says
  "fails" and links to its row in `docs/benchmarks.md`'s "Failed checks", which says
  why (2026-10-20).
- A setting one rival's documented configuration has, and the others take as idiomatically
  (a release profile flag, a CPU target), goes to all of them, and each `NOTES.md` says
  where it departs from the entry it follows (2026-10-17).
