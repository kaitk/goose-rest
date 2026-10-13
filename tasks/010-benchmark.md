# 010: Benchmark against goose-http, Axum, actix-web, and dusty

Status: todo

The framework's overhead is the number this design exists to keep small. Serve
goose-http's task 021 tiers on goose-rest, and on three frameworks used as their own
documentation shows: Axum and actix-web in Rust, and dusty in Zig (asked for
2026-10-13). goose-http's own REST server is the baseline without a framework.

Each framework uses its own router with a route per path, its own extractors or body
readers, and its own JSON, so that the run measures what a framework costs. goose-http's
`bench/rest/dusty` doesn't: one handler takes every path (`router.any("/*path")`) and
matches them itself. The framework entry starts from its records and handlers, and its
pins (dusty `ae164fa`, zio 0.19.1, Zig 0.16.0).

## Acceptance criteria

- [ ] goose-rest serves tiers A to D, and passes goose-http's `bench/rest/check.py`
- [ ] Axum, actix-web, and dusty serve them through their routers, extractors, and
      middleware, built in release mode (`ReleaseFast` for dusty) in their fastest
      documented configuration, with the same worker count
- [ ] Where a framework answers an error before the handler (a 404, 405, or bad query)
      differently from the checker's expectation, the difference is recorded beside its
      rows, not worked around with a catch-all route
- [ ] Measured against goose-http alone with goose-http's `bench/rest.sh`, extended or
      wrapped to take these servers
- [ ] Results in `docs/results.md`, with how they were measured, losses as plainly as
      wins
