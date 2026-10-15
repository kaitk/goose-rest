# Benchmarks

Where goose-rest stands now, one section per workload. Each section holds the latest
accepted run and is replaced, not appended to, when a newer one supersedes it. The
scripts, the servers, and where raw output goes: [bench/README.md](../bench/README.md).

## How these are measured

On the benchmark desktop: AMD Ryzen 7 5800X3D, 8 cores, 16 logical CPUs, Windows 11,
WSL2 Ubuntu 26.04.1 with kernel 6.18.54.1-microsoft-standard-WSL2, gcc 15.2.0. Every
server runs 4 workers on CPUs 0-3, and wrk 4.1.0 runs with 8 threads and 256
connections on CPUs 4-15. Each cell has a fresh server, 5 s of warm-up, and 3
interleaved runs of 15 s; tables show medians. Instruction counts come from
goose-http's `count.sh`: one worker on CPU 0, the epoll loop, h2load with 256
connections and 16 requests in flight on each, 10 million requests, one run per case.

The method behind each number is goose-http's
([its bench/README.md](https://github.com/kaitk/goose-http/blob/main/bench/README.md#method)),
whose `bench/rest.sh` this repository's wraps.

## Pins

| Workload | goose-rest | goose-http | Goose compiler | Date | Command |
|---|---|---|---|---|---|
| Tiers A to D, both loops | `b1226e4` | `de19e3b`, code as `v0.3.1` | `bc3c1f1` | 2026-10-14 | `bench/rest.sh run` |
| Tiers F, R, and M, both loops | `e44f653`, the same server code | `de19e3b` | `bc3c1f1` | 2026-10-15 | `bench/rest.sh run` |
| Instructions per request | `e44f653` | `de19e3b` | `bc3c1f1` | 2026-10-15 | `bench/rest.sh count` |

The runs' `env.txt` names the compiler `46356c2`, which differs from `bc3c1f1` only by
a logo. The commands, with the servers each ran:

```sh
SERVERS="goose-uring goose-epoll goose-uring-rest goose-epoll-rest" \
    EXTRA="goose-uring-rest goose-epoll-rest" bench/rest.sh run   # A to D, 2026-10-14
SERVERS=none EXTRA="goose-uring-rest goose-epoll-rest" STEPS=none bench/rest.sh run
bench/rest.sh count
```

The raw runs are in goose-http's `bench/results/`:
[A to D](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat/summary.md),
[F, R, M](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat-frm/summary-extra.md),
and [counts](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-14T2039-rest-Tiamat-frm/count.txt).

## The tiers

Tiers A to D are goose-http's REST APIs; its benchmarks describe each request and its
share:

- [**A**](https://github.com/kaitk/goose-http/blob/main/docs/benchmarks.md#tier-a):
  HttpArena's `production-stack` API, items of 0.2 KB, behind a bearer token.
- [**B**](https://github.com/kaitk/goose-http/blob/main/docs/benchmarks.md#tier-b): a
  time tracker's hot path, 0.3-13 KB of JSON, behind a session cookie.
- [**C**](https://github.com/kaitk/goose-http/blob/main/docs/benchmarks.md#tier-c): a
  clinic's schedule and records, up to 728 KB, behind a JWT. "Templates" builds each
  record's JSON once at startup.
- [**Uploads**](https://github.com/kaitk/goose-http/blob/main/docs/benchmarks.md#uploads)
  (tier D): CSVs and multipart files up to 8 MB. "Reads beside uploads" sends tier C's
  reads at a fixed 1,700 a second while uploads run.

Tiers F, R, and M are goose-rest's own, in `bench/rest/tiers/`, run at saturation only.

<a id="tier-f"></a>
**F, per-request framework cost.** The three tests of the bun-http-framework-benchmark,
whose chart Elysia's README shows. Small requests and answers, so routing, parameters,
fields, and a JSON body dominate. Each route is a cell of its own, and goose-http alone
serves it too.

| Request | Response |
|---|---|
| `GET /` | 200 `text/plain`, `Hi` |
| `GET /id/{id}?name={name}` | 200 `text/plain`, `{id} {name}` with `name` decoded, and `x-powered-by: benchmark` |
| `POST /json`, a JSON object of about 200 bytes | 200 `application/json`, the body read into the language's JSON value and written back, members in order |

<a id="tier-r"></a>
**R, routing at scale.** The GitHub API's 203 routes from julienschmidt's
go-http-routing-benchmark, each answering 200 `text/plain` with the route's number and
its parameters, separated by spaces. The load requests every route in a fixed shuffled
order. goose-rest serves it twice: through an `http::router` if chain in the list's
order, and through the router the generator writes from an OpenAPI document of the same
routes.

<a id="tier-m"></a>
**M, a middleware stack.** Tier A with three middlewares around every route, each the
framework's own: a `Server-Timing: app;dur=<ms>` field without an access log, CORS for
`https://app.example`, and a bearer check that answers 401 without a token. The load is
tier A's with an `Origin` field. Compared with tier A, it prices the stack.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 598 K | 585 K (-2.2%) | 444 K | 436 K (-1.8%) |
| A | template | 603 K | 594 K (-1.5%) | 467 K | 452 K (-3.2%) |
| B | serialize | 315 K | 279 K (-11.2%) | 244 K | 224 K (-8.2%) |
| B | template | 394 K | 387 K (-1.8%) | 291 K | 287 K (-1.3%) |
| C | serialize | 62.4 K | 53.4 K (-14.4%) | 60.9 K | 52.0 K (-14.6%) |
| C | template | 147 K | 142 K (-3.1%) | 137 K | 133 K (-3.1%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 517 K, 514 K (-0.7%) | 405 K, 401 K (-1.0%) |
| F | `GET /id/{id}?name=` | 509 K, 504 K (-1.1%) | 396 K, 389 K (-1.7%) |
| F | `POST /json` | 440 K, 434 K (-1.4%) | 345 K, 341 K (-1.2%) |
| R | 203 routes: if chain, generated router | 325 K, 458 K (+41%) | 259 K, 362 K (+39%) |
| M | tier A, then with the stack | 578 K, 489 K (-15.3%), 6.9 → 8.2 µs | 432 K, 354 K (-18.1%), 9.3 → 11.3 µs |

- Where routing and middleware are the work, goose-rest costs 0.7-3.2% of goose-http's
  rate: tiers A, F, and the templated tiers.
- The generated router serves tier R 39-41% faster than the if chain, which pays about
  175 instructions per route it passes, 35,100 more at route 201.
- Tier M's stack costs 15-18% of tier A's rate.

### Uploads and memory

On io_uring at saturation, peak RSS:

| Workload | goose-http | goose-rest |
|---|---:|---:|
| Tier A | 12 MB | 33 MB |
| Tier B | 30 MB | 96 MB |
| Tier C | 71 MB | 140 MB |
| Tier C, templates | 58 MB | 387 MB |
| Uploads alone | 69-70 MB | 385-422 MB |

Uploads alone ran at 1,120-1,128 a second on goose-http and 992-993 on goose-rest.
Tier C's reads beside uploads had a p99 of 4.8-7.5 ms on goose-http's io_uring loop
against 20.4-28.1 ms on goose-rest's, and 0.40-1.35 ms on goose-http's epoll loop
against 13.8-16.1 ms. Alone, the reads' p99 is 0.14-0.96 ms on all four.

### Instructions per request

User instructions per request:

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

- A tier A item costs 178 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 470 and 575 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 248 more than goose-http's router and query; goose-rest's `/`
  costs 98 fewer.
- Tier M's stack costs 1,313 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the runs in this file, against goose-http alone:

- **Serialized JSON**: tiers B and C lose 8-15%, and tier C serialized takes 74.9 µs of
  CPU per request against 64.2. The templated tiers, whose JSON is prebuilt, lose
  1.3-3.1%.
- **Memory**: 2.0-6.7 times goose-http's peak RSS at saturation, and 5.5-6.1 times on
  uploads.
- **Uploads**: 11-12% fewer a second.
- **Reads beside uploads**: p99 3-6 times goose-http's on io_uring, and 10-40 times on
  epoll.

## Against other frameworks

Not measured yet. Axum, actix-web, and dusty serve every tier through their own
routers, extractors, and middleware, and pass the checks
([servers](../bench/README.md#servers)). Until they run, goose-http's
[REST APIs](https://github.com/kaitk/goose-http#rest-apis) compare its server, without a
framework, with Rust and Zig servers on tiers A to D.
