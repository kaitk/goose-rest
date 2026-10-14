# 012: Serve the benchmark from goose-http's application module

Status: todo (asked for 2026-10-14; waits on goose-http's task 031)

`bench/rest/goose-rest/main.goose` copies goose-http's `bench/rest/goose/rest.goose` at
`e27ab21`, apart from its routes: about 2,450 of its 2,883 lines. The copy missed
goose-http's task 025, which loads the records on a thread that exits once the workers
start and keeps strings in one pool: on tier C with 4 workers, peak RSS fell from 140 to
104 MB serialized and from 387 to 176 MB templated. Task 010's RSS column would compare
that against goose-rest's copy without it. goose-http's task 031 moves the shared part
into `bench/rest/goose/app.goose`, which goose-rest imports at its pin as
`http.bench.rest.goose.app`, so both Goose servers do the same work outside the
framework and only routing, extractors, and middleware differ.

`bench/rest/rust-app` copies goose-http's `bench/rest/rust` the same way. Cargo can
depend on it by path or git commit; that waits until the copy drifts.

## Acceptance criteria

- [ ] goose-rest's goose-http pin is at a commit with task 031
- [ ] `main.goose` imports `http.bench.rest.goose.app` and holds only its routes, its
      extractors' types, its middleware, its error shapes, the `thread_fn`s, and a
      loader thread that spawns them
- [ ] `bench/rest.sh check` passes on every tier for `goose-uring-rest` and
      `goose-epoll-rest`, and `scripts/test.sh` passes
- [ ] Idle VmRSS per worker on tiers A and C within a few MB of goose-http alone, before
      task 010's run
