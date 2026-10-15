# Benchmarks

Where goose-rest stands now, one section per workload. Each section holds the latest
accepted run and is replaced, not appended to, when a newer one supersedes it. The
scripts, the servers, and where raw output goes: [bench/README.md](../bench/README.md).

## How these are measured

On the benchmark desktop: AMD Ryzen 7 5800X3D, 8 cores, 16 logical CPUs, Windows 11,
WSL2 Ubuntu 26.04.1 with kernel 6.18.54.1-microsoft-standard-WSL2, gcc 15.2.0. Every
server runs 4 workers on CPUs 0-3, and wrk 4.1.0 runs with 8 threads and 256
connections on CPUs 4-15. Each cell has a fresh server, 5 s of warm-up, and 3
interleaved runs of 15 s; tables show medians. Every server passes the checks before
its cells run. Axum, actix-web, and dusty run in their fastest documented
configuration, built in release mode; each serves through its own router, extractors,
and middleware ([servers](../bench/README.md#servers)).

Instruction counts come from goose-http's `count.sh`: one worker on CPU 0, the epoll
loop, h2load with 256 connections and 16 requests in flight on each, 10 million
requests, one run per case.

The method behind each number is goose-http's
([its bench/README.md](https://github.com/kaitk/goose-http/blob/main/bench/README.md#method)),
whose `bench/rest.sh` this repository's wraps.

## Pins

| Workload | goose-rest | goose-http | Goose compiler | Date | Command |
|---|---|---|---|---|---|
| Tiers A to D, F, R, and M, every server | `v0.0.1` | `v0.3.1` | `bc3c1f1` | 2026-10-15 | `bench/rest.sh run` |
| Instructions per request | `v0.0.1` | `v0.3.1` | `bc3c1f1` | 2026-10-15 | `bench/rest.sh count` |

goose-rest's binary was built from `b1226e4`, which differs from `v0.0.1` only in
`waiting.goose`, which the tier server doesn't use, and in comments. goose-http's
measured code is `v0.3.1`'s. Goose `bc3c1f1` is four commits before `v2026.1`, which
add release packaging; the runs' `env.txt` names it `46356c2`, which differs only by a
logo. Competitors: axum 0.8.9, actix-web 4.16.0, dusty `ae164fa` with zio 0.19.1 on Zig
0.16.0, hyper 1.12.0, rustc 1.99.0.

```sh
SERVERS="goose-uring goose-epoll goose-uring-rest goose-epoll-rest axum actix-web dusty-routes dusty hyper" \
    EXTRA="goose-uring-rest goose-epoll-rest axum actix-web dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
bench/rest.sh count
```

The raw run is in goose-http's `bench/results/`:
[A to D](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-15T1539-rest-Tiamat/summary.md),
[F, R, M](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-15T1539-rest-Tiamat/summary-extra.md),
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

## Against other frameworks

goose-rest on the io_uring loop and on the epoll loop, against Axum, actix-web, and
dusty with a route per path (`dusty-routes`). Req/s at saturation.

| Server | A | B | C | C, templates | F, `/id` | F, `/json` | R | M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| dusty-routes (Zig) | 339 K | 160 K | 24.0 K | 130 K | 361 K | 249 K | 355 K | 321 K |
| actix-web (Rust) | 260 K | 142 K | 31.3 K | 91.6 K | 269 K | 217 K | 143 K | 218 K |
| Axum (Rust) | 244 K | 135 K | 34.3 K | 87.3 K | 250 K | 190 K | 245 K | 180 K |
| goose-rest, io_uring | **582 K** | **277 K** | **52.7 K** | **141 K** | **506 K** | **435 K** | **462 K** | **494 K** |
| goose-rest, epoll | 430 K | 221 K | 51.3 K | 132 K | 378 K | 340 K | 358 K | 354 K |
| goose-http alone\*, io_uring | 586 K | 313 K | 61.8 K | 144 K | 512 K | 439 K | | |
| goose-http alone\*, epoll | 432 K | 243 K | 60.3 K | 136 K | 398 K | 347 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads every column: 1.7 times the next framework on A and
  B serialized, 1.5 times Axum on C serialized, 1.3-1.7 times dusty-routes on F, R,
  and M, and 8% ahead of dusty-routes on C templated.
- On the epoll loop, dusty-routes ties goose-rest on R (355 K against 358 K) and C
  templated (130 K against 132 K), and leads on B templated, 291 K against 287 K.
- Tier M's stack costs goose-rest 14.5% of tier A's rate on io_uring and 17.9% on
  epoll; it costs dusty-routes 6.7%, actix-web 16.1%, and Axum 24.3%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads |
|---|---:|---:|---:|---:|
| dusty-routes (Zig) | 1,191/s | 30-45/s, 2.9 K/s | 0.58-3.23 ms | 15 / 216 / 242 / 31 MB |
| actix-web (Rust) | 1,117/s | 92-93/s, 4.6-4.7 K/s | 20.4-21.8 ms | 19 / 334 / 388 / 57 MB |
| Axum (Rust) | 1,119/s | 33-34/s, 4.8-5.0 K/s | 8.6-11.2 ms | 27 / 477 / 587 / 163 MB |
| goose-rest, io_uring | 972/s | 151-158/s, 6.7-6.8 K/s | 21.8-27.4 ms | 33 / 140 / 387 / 385 MB |
| goose-rest, epoll | 983/s | 111-113/s, 7.1-7.2 K/s | 13.6-15.4 ms | 27 / 129 / 376 / 395 MB |
| goose-http alone\*, io_uring | 1,125/s | 159-165/s, 6.9-7.1 K/s | 5.59-8.51 ms | 12 / 70 / 58 / 70 MB |
| goose-http alone\*, epoll | 1,154/s | 112-123/s, 7.4-7.5 K/s | 0.52-1.53 ms | 8 / 69 / 58 / 69 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, every
server's reads have a p99 of 0.15-1.88 ms. Every server reached every fixed rate.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs. Both ran in the session above.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 586 K | 582 K (-0.8%) | 432 K | 430 K (-0.5%) |
| A | template | 594 K | 592 K (-0.4%) | 444 K | 442 K (-0.4%) |
| B | serialize | 313 K | 277 K (-11.6%) | 243 K | 221 K (-9.1%) |
| B | template | 383 K | 383 K (-0.1%) | 296 K | 287 K (-3.0%) |
| C | serialize | 61.8 K | 52.7 K (-14.7%) | 60.3 K | 51.3 K (-14.9%) |
| C | template | 144 K | 141 K (-2.3%) | 136 K | 132 K (-3.2%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 515 K, 517 K (+0.3%) | 407 K, 402 K (-1.3%) |
| F | `GET /id/{id}?name=` | 512 K, 506 K (-1.2%) | 398 K, 378 K (-5.1%) |
| F | `POST /json` | 439 K, 435 K (-0.9%) | 347 K, 340 K (-1.8%) |
| R | 203 routes: if chain, generated router | 323 K, 462 K (+43%) | 258 K, 358 K (+39%) |
| M | tier A, then with the stack | 578 K, 494 K (-14.5%), 6.9 → 8.1 µs | 431 K, 354 K (-17.9%), 9.3 → 11.3 µs |

- Where routing and middleware are the work, goose-rest is within 0.1-3.2% of
  goose-http's rate: tiers A, F, and the templated tiers, except F's `/id` on epoll,
  5.1% behind.
- The generated router serves tier R 39-43% faster than the if chain, which pays about
  175 instructions per route it passes, 35,100 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,125/s | 972/s |
| Reads p99 beside uploads | 5.6-8.5 ms | 21.8-27.4 ms |
| Peak RSS, tier A | 12 MB | 33 MB |
| Peak RSS, tier B | 30 MB | 96 MB |
| Peak RSS, tier C | 70 MB | 140 MB |
| Peak RSS, tier C templated | 58 MB | 387 MB |
| Peak RSS, uploads alone | 70 MB | 385 MB |

On epoll, uploads alone ran at 1,154 a second on goose-http and 983 on goose-rest, and
the reads beside them had a p99 of 0.52-1.53 ms against 13.6-15.4 ms.

The extra memory and the slow reads are the `v0.0.1` tier server's, not the
framework's. That server loads its records in `main`, where `thread_spawn` copies them
into every worker and each keeps two copies, holds strings in fixed-capacity fields,
and builds the templates' JSON once per worker. goose-http's server loads on a thread
that hands each worker one set and keeps the templates once per process in
`http::store`. On uploads, the `v0.0.1` tier server gathers each body whole with
`rest::body`, so each worker keeps memory for the bodies it held at once, about 240 MB
in all, and answers nothing else while it parses a body of up to 8 MB. goose-http's
server parses the same bodies in pieces as they arrive.

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

From the run in this file:

- **Serialized JSON**, to goose-http alone: tiers B and C lose 9-15%, and tier C
  serialized takes 75.8 µs of CPU per request against 64.6. The templated tiers lose
  0.1-3.2%.
- **Uploads alone**: 972-983 a second, the fewest of every server; dusty-routes takes
  1,191, Axum and actix-web 1,117-1,119, and goose-http 1,125-1,154.
- **Reads beside uploads**: p99 13.6-27.4 ms, the slowest with actix-web's 20.4-21.8 ms,
  against dusty-routes's 0.58-3.23 ms and goose-http's 0.52-8.5 ms.
- **Memory**: the most of every server on uploads, 385-395 MB against 31-163 MB, and
  on tier A, 33 MB against 15-27 MB, and on C templated more than dusty-routes, 387 MB
  against 242. On tier C serialized it holds the least of the frameworks, 140 MB against
  216-477.
- **Tier M's stack**: 14.5-17.9% of tier A's rate, against dusty-routes's 6.7%.
- **On the epoll loop**, to dusty-routes on B templated, 287 K against 291 K, and
  within 1.5% of it on C templated and R.
