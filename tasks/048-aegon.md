# 048: Aegon in the REST benchmark

Status: in-progress (asked for 2026-10-19; built, checked, and measured 2026-10-19;
the ideas below remain)

[Aegon](https://github.com/UdayKhare09/Aegon) (C++23, MIT, created 2026-09-07) is a
thread-per-core framework on io_uring, epoll, and IOCP, with coroutine handlers, a
radix-tree router, middleware, Glaze for JSON, and HTTP/1.1, h2, h3, and WebSocket. It
leads most of HttpArena's throughput profiles it enters, so it belongs beside Axum,
actix-web, ntex, and dusty in `bench/rest/`. It is also a source of ideas for goose-http
and goose-rest.

## On HttpArena

From `site/data/results/` at HttpArena `2d85137` (2026-10-18), Aegon's entry at Aegon
`e649022`, 64 threads on the 64-core Threadripper. Memory is HttpArena's reading for
the container:

| Profile | Aegon | actix | ntex | dusty |
|---|---:|---:|---:|---:|
| baseline, 4,096 connections | 4.05 M/s, 4.3 GiB | 2.78 M/s, 154 MiB | 2.17 M/s, 148 MiB | 3.31 M/s, 198 MiB |
| limited-conn, 4,096 | 2.60 M/s, 4.4 GiB | 1.14 M/s, 72 MiB | 1.45 M/s, 142 MiB | 1.93 M/s, 64 MiB |
| json-comp, 4,096 | 0.96 M/s, 4.3 GiB | 0.54 M/s, 210 MiB | 0.59 M/s, 174 MiB | 0.40 M/s, 165 MiB |
| async, 32,000 | 2.65 M/s, 5.4 GiB | 2.11 M/s, 1,009 MiB | 0.96 M/s, 775 MiB | 2.04 M/s, 1.3 GiB |
| latency-1m: CPU per request | 14.9 µs, 4.2 GiB | 24.9 µs, 83 MiB | 35.0 µs, 59 MiB | 27.4 µs, 69 MiB |
| latency-10k: CPU per request | 30.4 µs, 4.2 GiB | 27.4 µs, 78 MiB | 36.4 µs, 59 MiB | 26.6 µs, 69 MiB |
| 8gbit: CPU per request | 69.9 µs, 4.3 GiB | 45.0 µs, 93 MiB | 61.2 µs, 63 MiB | 67.1 µs, 133 MiB |

Aegon's memory is about the same at 10K requests per second as at 4 M. Its entry
(`frameworks/aegon/main.cpp`) sets 16,384 provided buffers of 4 KB per thread when
`RLIMIT_MEMLOCK` allows, and `src/core/BufferPool.cpp` maps them with `MAP_POPULATE`,
trying 2 MB huge pages first. 16,384 × 4 KB × 64 threads is 4 GiB, faulted in at startup.
With a low memlock limit the entry takes 256 buffers per thread instead. This is read
from the source, not measured.

goose-rest's peak RSS on tier A is 13 MB with 4 workers on io_uring
(`docs/benchmarks.md`). With 4 threads, Aegon's buffers alone would be 256 MB, so it
should lose on memory by a wide margin and lead on rate. HttpArena's memory bonus scores
`sqrt(rps) / MB`, so a large lead in memory is worth points there.

## Ideas to study

Each is a claim from Aegon's README or source, to measure before adopting. Task 056
(2026-10-20) sets which ideas goose-rest takes, and goose-http's task 056 which engine
ideas it measures; multishot accept and receive with provided buffer rings are in
goose-http already.

- io_uring multishot accept and receive with provided buffer rings
  (`io_uring_setup_buf_ring`). Check what goose-http's `uring.goose` uses; a change
  there is goose-http's.
- SIMD scanning in the request parser (`src/core/simd/SimdString.h`).
- h2 and h3 through nghttp2, ngtcp2, and nghttp3, and TLS through OpenSSL. Its 14.4 M
  requests per second on baseline-h2c is with nghttp2, a data point for goose-http's
  task 014, which plans h2 in Goose.
- WebSocket (`src/http/websocket/`), JWT (`src/http/jwt/`), and an HTTP client with a
  per-core connection pool: the features task 047 plans, in one framework.

## Steps

1. `bench/rest/aegon/`: a CMake project that fetches Aegon at a pinned commit and serves
   tiers A to D, F, R, and M through Aegon's `Router`, route groups, middleware, and
   `bind_json`, with the records loaded as the Rust servers load them. `NOTES.md`
   records the configuration and where it departs from HttpArena's entry.
2. Configuration: the HttpArena entry's, which is Aegon's fastest documented one (8,192
   ring entries and 16,384 buffers per thread with memlock unlimited), with
   `WORKERS` threads. Record `vm.nr_hugepages` with each run: pages from the huge-page
   pool are left out of VmRSS, so peak RSS can't be compared without it.
3. A second build at the low-memlock setting (256 buffers), run as `aegon-small`, to
   show what its memory costs it in rate.
4. Build it in `bench/rest.sh build`, and pass `bench/rest.sh check` on Linux. Aegon
   targets Linux and Windows, and its entry builds on `archlinux:latest`, which has no
   arm64 image, so the Mac's arm64 Linux container needs another base with GCC 14 and
   liburing.
5. Run it beside the others on the Linux desktop and add it to `docs/benchmarks.md`.

## Acceptance criteria

- [x] `bench/rest/aegon/` with `NOTES.md`, and `bench/README.md` listing it
- [x] `bench/rest.sh check` passes Aegon and `aegon-small` on tiers A to C, F, R, and M.
      Tier D is left out (2026-10-19): Aegon reads a body whole before a route runs, so
      it can't refuse a batch declared over 1 MB until the body arrives, and
      `check.py` wants a 413 at once. goose-http's `no_d` names both servers, and its
      run skips them on tier D, as it skips may-minihttp and Tina
- [x] Both measured on the desktop with the others, with peak RSS and
      `vm.nr_hugepages` recorded, in `docs/benchmarks.md` (session `2026-10-19T2043`:
      Aegon leads the other frameworks everywhere but C templated, trails goose-rest's
      io_uring loop on A, B, C, F `/json`, and M, and leads it on R; `aegon-small`
      matches its rate at a tenth of its memory)
- [ ] Each idea above measured or set aside, and the result recorded in the task of the
      repository it belongs to
