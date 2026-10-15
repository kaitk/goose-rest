# 010: Benchmark against goose-http, Axum, actix-web, and dusty

Status: in-progress

The framework's overhead is the number this design exists to keep small. Serve
goose-http's task 021 tiers on goose-rest, and on three frameworks used as their own
documentation shows: Axum and actix-web in Rust, and dusty in Zig (asked for
2026-10-13). goose-http's own REST server is the baseline without a framework.

Each framework uses its own router with a route per path, its own extractors or body
readers, and its own JSON, so that the run measures what a framework costs. goose-http's
`bench/rest/dusty` doesn't: one handler takes every path (`router.any("/*path")`) and
matches them itself. The framework entry starts from its records and handlers, and its
pins (dusty `ae164fa`, zio 0.19.1, Zig 0.16.0).

## Decided (2026-10-13)

- The servers: goose-http alone on both loops (`goose-epoll`, `goose-uring`), goose-rest
  on both (`goose-epoll-rest`, `goose-uring-rest`, the binary `rest-goose-rest`), Axum,
  actix-web, dusty with a route per path (`dusty-routes`), and goose-http's catch-all
  dusty and hyper as anchors to goose-http's 2026-10-13 tables. The pair of dusty entries
  prices dusty's router, its middleware, and its query and cookie readers, which the
  routed one uses and the catch-all doesn't (`bench/rest/dusty/NOTES.md`); the records,
  JSON, and body readers are the same.
- Axum and actix-web run in their TechEmpower entries' configuration: runtime layout,
  allocator, and release profile, each recorded with the commit it follows. goose-http's
  xitca-web entry follows its TechEmpower flags the same way.
- goose-rest answers errors in the shape a program chooses, so that tiers C and D, which
  want `{"error", "status"}`, pass as the frameworks' custom error types do. The default
  stays `{"error"}`.
- goose-rest gathers a body larger than goose-http's read buffer up to a limit the route
  sets, answers 413 from the head when `Content-Length` is over it, and then runs the
  route with the whole body. Until then such a body reached the route empty. Its tier D
  reads bodies whole, as tokio and odin-http do.
- Beyond tiers A to D, three tiers of goose-rest's own, run at saturation only, and
  `count.sh` on Goose builds. The tiers are below.

## Tier F: per-request framework cost

From the three tests of the bun-http-framework-benchmark, whose chart Elysia's README
shows. Small requests and answers, so routing, parameters, fields, and a JSON body
dominate. Each route is a cell of its own.

| Request | Response |
|---|---|
| `GET /` | 200 `text/plain`, `Hi` |
| `GET /id/{id}?name={name}` | 200 `text/plain`, `{id} {name}` with `name` decoded, and `x-powered-by: benchmark` |
| `POST /json`, a JSON object of about 200 bytes | 200 `application/json`, the body read into the language's JSON value and written back, members in order |

goose-http alone serves it too, as the baseline.

## Tier R: routing at scale

The GitHub API's 203 routes from julienschmidt's go-http-routing-benchmark, each answering
200 `text/plain` with the route's number and its parameters, separated by spaces. The
load requests every route in a fixed shuffled order. goose-rest serves it twice: through
an `http::router` if chain in the list's order, and through the router the generator
writes from an OpenAPI document of the same routes.

## Tier M: a middleware stack

Tier A with three middlewares around every route, each the framework's own: a
`Server-Timing: app;dur=<ms>` field without an access log, CORS for
`https://app.example`, and a bearer check that answers 401 without a token. The load is
tier A's with an `Origin` field. Compared with tier A, it prices the stack.

## Instruction counts

`count.sh`, on Linux, on goose-http and goose-rest serving the same request: a tier A
item (200), `/api/me` without a user (401), an unknown path (404), a malformed path
parameter (400), and tier M's item. Both share the HTTP layer, so the difference is the
framework's. It compares Goose builds only.

## macOS preview (2026-10-14)

Not results: macOS has no `perf`, so these counts include the kernel's instructions and
spread by about 30 per request between runs (goose-http's development.md, "macOS"). They
show where to look on Linux. Apple M1 Pro, macOS 26.3.1 (Darwin 25.3.0), load average
5-6; goose-rest `fe6cbf2`, Goose `0bdbd18`, both servers built with `goose build --cc
gcc --standalone` (Apple clang 21); one worker, epoll loop. Each case: h2load 1.70.0
`--h1 -n 2000000 -c 256 -m 16 -t 8` with count.sh's headers, the server under
`/usr/bin/time -l`, instructions retired divided by the requests, the median of 3
interleaved runs:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 20,151 | 20,126 |
| Tier A `GET /api/me` without a user, 401 | 20,362 | 20,657 |
| Tier A `GET /nothing`, 404 | 18,704 | 19,045 |
| Tier M `GET /api/items/1` without a token, 401 | | 24,871 |
| Tier F `GET /` | 17,980 (bare) | 18,007 |
| Tier F `GET /id/1?name=bun` | 18,667 (bare) | 18,940 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 19,038, 18,604 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 61,284, 19,291 |

- On a tier A item, goose-rest costs nothing measurable over goose-http alone.
- Its 401 and 404 cost about 300 more, but answer with a JSON body where goose-http's
  server sends none, so the two aren't the same answer.
- Tier F's `/id` costs about 270 more through `rest::param` and `rest::query` than
  through goose-http's router and query; look at it with perf.
- The if chain pays about 210 instructions per route it passes, 42,000 more at route 201
  of 203, where the generated router stays flat; it costs 430 less on the first route
  too.
- Tier M's stack adds about 4,200 to a 401. `sample` puts it in the inlined middleware
  (Server-Timing's insertion and formatting, CORS), in field lookups
  (`http::authorization`, `http::field_in`) for the bearer token and Origin, and in
  reading the clock twice (`mach_absolute_time`).

## Goose servers on Linux (2026-10-14 and 2026-10-15)

goose-rest against goose-http alone, before any framework's run. `bench/all.sh`
measured tiers A to D in session `2026-10-14T2039`; it stopped before tiers F, R, and
M, whose checker rejected Server-Timing's trailing spaces (fixed in `e44f653`). They
ran on 2026-10-15 from the same binaries:

```sh
SERVERS="goose-uring goose-epoll goose-uring-rest goose-epoll-rest" \
    EXTRA="goose-uring-rest goose-epoll-rest" bench/rest.sh run   # A to D, 2026-10-14
SERVERS=none EXTRA="goose-uring-rest goose-epoll-rest" STEPS=none bench/rest.sh run
bench/rest.sh count
```

The desktop, machine name Tiamat: AMD Ryzen 7 5800X3D, 16 logical CPUs, WSL2 kernel
6.18.54.1-microsoft-standard-WSL2, gcc 15.2.0. goose-rest `b1226e4` (A to D) and
`e44f653` (F, R, M; the same server code), goose-http `de19e3b` (code as `v0.3.1`),
Goose compiler built from `bc3c1f1` (`env.txt` says `46356c2`, which differs only by a
logo). 4 workers on CPUs 0-3; wrk 4.1.0 with 8 threads and 256 connections on CPUs
4-15; 3 interleaved runs of 15 s after 5 s of warm-up, a fresh server per cell,
medians. The summaries:
[A to D](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat/summary.md),
[F, R, M](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat-frm/summary-extra.md),
and [counts](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat-frm/count.txt).

Tiers A to C at saturation, req/s, goose-rest against goose-http alone on the same
loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 598 K | 585 K (-2.2%) | 444 K | 436 K (-1.8%) |
| A | template | 603 K | 594 K (-1.5%) | 467 K | 452 K (-3.2%) |
| B | serialize | 315 K | 279 K (-11.2%) | 244 K | 224 K (-8.2%) |
| B | template | 394 K | 387 K (-1.8%) | 291 K | 287 K (-1.3%) |
| C | serialize | 62.4 K | 53.4 K (-14.4%) | 60.9 K | 52.0 K (-14.6%) |
| C | template | 147 K | 142 K (-3.1%) | 137 K | 133 K (-3.1%) |

Tiers F, R, and M, req/s and CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 517 K, 514 K (-0.7%) | 405 K, 401 K (-1.0%) |
| F | `GET /id/{id}?name=` | 509 K, 504 K (-1.1%) | 396 K, 389 K (-1.7%) |
| F | `POST /json` | 440 K, 434 K (-1.4%) | 345 K, 341 K (-1.2%) |
| R | 203 routes: if chain, generated router | 325 K, 458 K (+41%) | 259 K, 362 K (+39%) |
| M | tier A, then with the stack | 578 K, 489 K (-15.3%), 6.9 → 8.2 µs | 432 K, 354 K (-18.1%), 9.3 → 11.3 µs |

`count.sh`'s user instructions per request: one worker on CPU 0, the epoll loop,
h2load with 256 connections and 16 requests in flight on each, 10 million requests,
one run per case:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 4,061 | 4,239 |
| Tier A `GET /api/me` without a user, 401 | 4,047 | 4,517 |
| Tier A `GET /nothing`, 404 | 2,569 | 3,144 |
| Tier M `GET /api/items/1` without a token, 401 | | 5,830 |
| Tier F `GET /` | 2,376 (bare) | 2,278 |
| Tier F `GET /id/1?name=bun` | 2,956 (bare) | 3,204 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,168, 2,852 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 38,422, 3,299 |

- Where routing and middleware are the work, goose-rest costs 0.7-3.2% of goose-http's
  rate: tiers A, F, and the templated tiers. A tier A item costs 178 instructions more.
- Serialized B and C lose 8-15%, and tier C serialized takes 74.9 µs of CPU per request
  against 64.2. The templated tiers, whose JSON is prebuilt, lose 1.3-3.1%, so the
  loss is in serializing. goose-http's tier server looks for a string's escapes with
  std's `find_any` before calling `json::format_string`, which made its B and C 11-23%
  faster (its `b03a446`); goose-rest's tier server (`bench/rest/goose-rest/main.goose`)
  calls `json::format_string` on every string. That is the likely cause; it isn't
  measured yet.
- goose-rest holds 2.0-6.7 times goose-http's peak memory at saturation on io_uring: 33
  MB against 12 on A, 96 against 30 on B, 140 against 71 on C, and 387 against 58 on C
  with templates. Uploads alone: 385-422 MB against 69-70, at 992-993 uploads a second
  against 1,120-1,128.
- Reads beside uploads, tier C at 1,700 a second: p99 20.4-28.1 ms on goose-uring-rest
  against 4.8-7.5 ms on goose-http alone, and 13.8-16.1 ms on goose-epoll-rest against
  0.40-1.35 ms. Alone, the reads' p99 is 0.14-0.96 ms on all four.
- The generated router serves tier R 39-41% faster than the if chain, which pays about
  175 instructions per route it passes, 35,100 more at route 201.
- Tier M's stack costs 15-18% of tier A's rate and 1,313 instructions on a 401, against
  tier A's 401.
- goose-rest's 401 and 404 cost 470 and 575 instructions more than goose-http's, and
  answer with a JSON body where goose-http's server sends none.
- Tier F's `/id` costs 248 more than goose-http's router and query; goose-rest's `/`
  costs 98 fewer.

## Acceptance criteria

- [x] goose-rest answers errors in a shape the program chooses
- [x] goose-rest gathers bodies larger than the read buffer up to a route's limit
- [x] goose-rest serves tiers A to D, and passes goose-http's `bench/rest/check.py`
      (macOS, 2026-10-14, both loops and both JSON ways)
- [x] Axum, actix-web, and dusty serve them through their routers, extractors, and
      middleware, built in release mode (`ReleaseFast` for dusty) in their fastest
      documented configuration, with the same worker count (macOS checks, 2026-10-14;
      each entry's `NOTES.md` has its configuration and the TechEmpower commit it follows)
- [ ] Where a framework answers an error before the handler (a 404, 405, or bad query)
      differently from the checker's expectation, the difference is recorded beside its
      rows, not worked around with a catch-all route (recorded in each entry's
      `NOTES.md`; goes beside the rows once there are results)
- [x] Tiers F, R, and M served by every framework, each with a checker
- [ ] Measured against goose-http alone with goose-http's `bench/rest.sh`, wrapped by
      goose-rest's `bench/rest.sh`, which runs tiers F, R, and M itself, after task 012
      so both Goose servers share the application code (the Goose servers on
      2026-10-14 and 2026-10-15, above; the frameworks not yet)
- [x] Instruction counts from `count.sh` (Linux, 2026-10-15, above)
- [ ] Results in `docs/results.md`, with how they were measured, losses as plainly as
      wins, and a summary in the README
