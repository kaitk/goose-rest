# 027: A helper for read-only data every worker shares

Status: todo (asked for 2026-10-15)

Data a program loads in `main`, such as records or prebuilt JSON, is copied into every
worker by `thread_spawn`, so it costs its size once per worker. Task 020 found this to
be most of goose-rest's extra memory on tiers A to C: the tier server keeps 4.5 to 71 MiB
per worker that goose-http's keeps once. goose-http's shared store, `import http.store`,
keeps one copy that every worker reads, but a goose-rest program has to wire it up
itself, and nothing in goose-rest's docs points a reader to it.

## Acceptance criteria

- [ ] A goose-rest helper loads read-only data once and gives each worker's `cx.app` a
      view of the shared copy, built on `http::store`, with a program that uses it and
      a test that the data isn't copied per worker
- [ ] The tutorial's page 8, "Per worker", and page 1, "Workers and `main`", say what
      copying into every worker costs, and point to the helper
- [ ] The reference documents it, with what may and may not go in it (read-only, built
      before the workers start)
