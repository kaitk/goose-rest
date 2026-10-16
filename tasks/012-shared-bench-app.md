# 012: Serve the benchmark from goose-http's application module

Status: in-progress (asked for 2026-10-14). The server imports goose-http's module on
`main`, checked on Linux in Docker on a Mac; the Linux desktop's idle memory recheck
remains (below).

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

- [x] goose-rest's goose-http pin is at a commit with task 031
- [x] `main.goose` imports `http.bench.rest.goose.app` and holds only its routes, its
      extractors' types, its middleware, its error shapes, the `thread_fn`s, and a
      loader thread that spawns them (as in goose-http's `rest.goose`, the loader loads
      and returns, and `main` spawns the workers)
- [x] `bench/rest.sh check` passes on every tier for `goose-uring-rest` and
      `goose-epoll-rest`, and `scripts/test.sh` passes
- [x] Idle VmRSS per worker on tiers A and C within a few MB of goose-http alone, before
      task 010's run (in Docker on a Mac; the desktop's figures are pending, below)

## What was done (2026-10-16)

The goose-http pin moved from `v0.3.5` to `6e57c42`, goose-http's `main` with task 031,
which no release has yet. `main.goose` went from 3,211 lines to 1,063. It imports
`http.bench.rest.goose.app` and `http.store`, and keeps what goose-rest serves through
its own API: the tiers' routes, the query, cookie, header, and bearer checks, tier B's
and tier C's error shapes, tier D's routes over `rest::body_in_pieces` and `rest::body`,
tiers F, R, and M, the workers, the distributor, the loader, and `main`. Two changes
beside the deletions:

- Tier D's answers come from `app.goose` and return their status, or 0 for a malformed
  body. `answer` sends the JSON, or `bad_request` for 0, after the spool is released.
  The bytes sent are the same.
- The loader prints `app.goose`'s `print_lens` under `REST_LENS`, and `main` sets glibc's
  `M_MMAP_THRESHOLD` with `mallopt` before the loader starts, as goose-http's server does.
  The server then builds only on Linux, so `bench/rest.sh build` skips it on macOS.

`app.goose` can't import `http.store` itself when a package imports it, so
`main.goose` imports it (`docs/goose-findings.md`, "A package's module can't import
another module of its package").

### Checks

- `scripts/test.sh` passes on macOS (M1 Pro, macOS 26.3.1), Goose `v2026.2`, at the new
  pin, before and after the rewrite.
- In Docker Desktop's arm64 VM on the same Mac: `ubuntu:26.04`, kernel 7.0.14-linuxkit,
  gcc, Goose `v2026.2` built from source by `scripts/goose.sh`,
  `--security-opt seccomp=unconfined`, goose-http's datasets from its
  `bench/rest/gen.goose`, goose-http at `6e57c42`. `OWN=1 ONLY=goose bench/rest.sh
  build`, then `SERVERS="goose-uring-rest goose-epoll-rest"
  EXTRA="goose-uring-rest goose-epoll-rest" bench/rest.sh check`: tiers A to D, both
  JSON ways (D serialized), both loops, 4 workers, and tiers F (with `goose-*-bare`),
  R (with `goose-*-rest-gen`, 203 routes), and M, all ok.
- Idle memory in the same container: epoll, no request sent, VmRSS 3 s after
  listening, 1, 2, and 4 workers, 3 rounds, goose-http's `rest` at `6e57c42` and
  goose-rest's server in turn for each cell, each built with
  `goose build --cc gcc --standalone`. Medians, in KB:

| Tier, JSON | goose-http, 1 / 2 / 4 workers | goose-rest, 1 / 2 / 4 workers | Per worker, goose-http / goose-rest |
|---|---|---|---:|
| A, serialize | 7,212 / 10,008 / 15,652 | 7,448 / 10,252 / 15,848 | 2.8 / 2.8 MB |
| A, template | 6,608 / 8,796 / 13,160 | 6,828 / 9,012 / 13,380 | 2.2 / 2.2 MB |
| C, serialize | 18,416 / 32,284 / 60,024 | 17,520 / 30,368 / 56,052 | 13.9 / 12.8 MB |
| C, template | 25,616 / 29,548 / 37,476 | 25,756 / 29,692 / 37,588 | 4.0 / 3.9 MB |

Per worker is (4 workers less 1) / 3. On tier A and tier C templated, goose-rest's
process holds 0.1 to 0.2 MB more at every worker count, the same at 1 worker as at 4,
so per worker the two match. On tier C
serialized goose-rest's worker holds 1.0 MB less than goose-http's; why isn't measured.
Every round was within 0.1 MB of its cell's median. These are the VM's figures, with its
default huge pages, not the desktop's.

### Pending on Linux

On the desktop (WSL2), at the commit after this change: `bench/rest.sh build`, then the
idle VmRSS with 4 workers, epoll, 3 s after listening, of goose-http alone and
goose-rest, tiers A and C, both JSON ways, before task 010's run.
