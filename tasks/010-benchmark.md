# 010: Benchmark against goose-http, Axum, and actix-web

Status: todo

The framework's overhead is the number this design exists to keep small. Serve
goose-http's task 021 tiers on goose-rest.

## Acceptance criteria

- [ ] The tiers pass goose-http's `bench/rest/check.py`
- [ ] Measured against goose-http alone, and Axum and actix-web in their fastest
      documented configuration, with the same worker count
- [ ] Results recorded in `docs/results.md` with how they were measured
