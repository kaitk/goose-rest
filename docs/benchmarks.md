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
| Tiers A to D, F, R, and M, Goose servers, and instructions per request | `v0.1.0` | `v0.3.3` | `v2026.1` | 2026-10-15 | `bench/all.sh` |
| Tiers A to D, F, R, and M, Axum, actix-web, dusty | | | | 2026-10-15 | `bench/rest.sh run` |

goose-rest's binary was built from `9cfcb73`, which differs from `v0.1.0` only in an
example. goose-http's measured code is `v0.3.3`'s. The frameworks' cells come from the
earlier session of the same day on the same machine, at the same fixed rates: axum
0.8.9, actix-web 4.16.0, dusty `ae164fa` with zio 0.19.1 on Zig 0.16.0, hyper 1.12.0,
rustc 1.99.0.

```sh
GOOSE_HTTP=<goose-http checkout> bench/all.sh
SERVERS="axum actix-web dusty-routes dusty hyper" EXTRA="axum actix-web dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
```

The Goose servers' run is in `bench/results/`:
[A to D](../bench/results/2026-10-15T2102-rest-Tiamat/summary.md),
[F, R, M](../bench/results/2026-10-15T2102-rest-Tiamat/summary-extra.md), and
[counts](../bench/results/2026-10-15T2102-rest-Tiamat/count.txt). The frameworks' run is
in goose-http's `bench/results/`:
[A to D](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-15T1539-rest-Tiamat/summary.md) and
[F, R, M](https://github.com/kaitk/goose-http/blob/main/bench/results/2026-10-15T1539-rest-Tiamat/summary-extra.md).

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
| goose-rest, io_uring | **584 K** | **312 K** | **61.3 K** | **139 K** | **508 K** | **441 K** | **447 K** | **494 K** |
| goose-rest, epoll | 432 K | 242 K | 60.2 K | 130 K | 390 K | 342 K | 354 K | 357 K |
| goose-http alone\*, io_uring | 600 K | 318 K | 62.0 K | 145 K | 514 K | 440 K | | |
| goose-http alone\*, epoll | 454 K | 243 K | 60.9 K | 135 K | 401 K | 349 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads every column: 1.7 times the next framework on A,
  1.9 times on B serialized, 1.8 times Axum on C serialized, 1.3-1.8 times dusty-routes
  on F, R, and M, and 7% ahead of dusty-routes on C templated.
- On the epoll loop, goose-rest and dusty-routes tie on R (354 K against 355 K), C
  templated (130 K each), and B templated (292 K against 291 K).
- Tier M's stack costs goose-rest 16.7% of tier A's rate on io_uring and 17.0% on
  epoll; it costs dusty-routes 6.7%, actix-web 16.1%, and Axum 24.3%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads / beside forms |
|---|---:|---:|---:|---:|
| dusty-routes (Zig) | 1,191/s | 30-45/s, 2.9 K/s | 0.58-3.23 ms | 15 / 216 / 242 / 31 / 781 MB |
| actix-web (Rust) | 1,117/s | 92-93/s, 4.6-4.7 K/s | 20.4-21.8 ms | 19 / 334 / 388 / 57 / 196 MB |
| Axum (Rust) | 1,119/s | 33-34/s, 4.8-5.0 K/s | 8.6-11.2 ms | 27 / 477 / 587 / 163 / 259 MB |
| goose-rest, io_uring | 1,090/s | 170-174/s, 7.5-7.6 K/s | 5.92-8.73 ms | 13 / 72 / 58 / 72 / 133 MB |
| goose-rest, epoll | 1,110/s | 122-129/s, 7.7-8.0 K/s | 0.51-1.37 ms | 8 / 71 / 58 / 71 / 160 MB |
| goose-http alone\*, io_uring | 1,097/s | 157-184/s, 7.2-7.4 K/s | 5.52-8.80 ms | 12 / 70 / 58 / 70 / 124 MB |
| goose-http alone\*, epoll | 1,098/s | 117-124/s, 7.5 K/s | 0.44-2.78 ms | 7 / 69 / 58 / 69 / 132 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, the Goose
servers' reads have a p99 of 0.14-0.87 ms, and the frameworks' 0.15-1.88 ms. Every
server reached every fixed rate.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs. Both ran in the Goose servers'
session.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 600 K | 584 K (-2.7%) | 454 K | 432 K (-4.9%) |
| A | template | 607 K | 594 K (-2.1%) | 473 K | 453 K (-4.1%) |
| B | serialize | 318 K | 312 K (-2.1%) | 243 K | 242 K (-0.3%) |
| B | template | 391 K | 391 K (0.0%) | 294 K | 292 K (-0.8%) |
| C | serialize | 62.0 K | 61.3 K (-1.1%) | 60.9 K | 60.2 K (-1.1%) |
| C | template | 145 K | 139 K (-3.9%) | 135 K | 130 K (-3.8%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 523 K, 524 K (+0.2%) | 410 K, 407 K (-0.8%) |
| F | `GET /id/{id}?name=` | 514 K, 508 K (-1.2%) | 401 K, 390 K (-2.7%) |
| F | `POST /json` | 440 K, 441 K (+0.3%) | 349 K, 342 K (-2.1%) |
| R | 203 routes: if chain, generated router | 333 K, 447 K (+34%) | 264 K, 354 K (+34%) |
| M | tier A, then with the stack | 593 K, 494 K (-16.7%), 6.7 → 8.1 µs | 430 K, 357 K (-17.0%), 9.3 → 11.2 µs |

- goose-rest is within 0.0-3.9% of goose-http's rate on every tier but A on epoll,
  4.1-4.9% behind.
- The generated router serves tier R 34% faster than the if chain, which pays about
  176 instructions per route it passes, 35,250 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,097/s | 1,090/s |
| Reads p99 beside uploads | 5.52-8.80 ms | 5.92-8.73 ms |
| Peak RSS, tier A | 12 MB | 13 MB |
| Peak RSS, tier B | 30 MB | 32 MB |
| Peak RSS, tier C | 70 MB | 72 MB |
| Peak RSS, tier C templated | 58 MB | 58 MB |
| Peak RSS, uploads alone | 70 MB | 72 MB |

On epoll, uploads alone ran at 1,098 a second on goose-http and 1,110 on goose-rest, and
the reads beside them had a p99 of 0.44-2.78 ms against 0.51-1.37 ms.

### Instructions per request

User instructions per request:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 4,084 | 4,229 |
| Tier A `GET /api/me` without a user, 401 | 4,046 | 4,527 |
| Tier A `GET /nothing`, 404 | 2,567 | 3,161 |
| Tier M `GET /api/items/1` without a token, 401 | | 5,866 |
| Tier F `GET /` | 2,362 (bare) | 2,308 |
| Tier F `GET /id/1?name=bun` | 2,942 (bare) | 3,225 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,195, 2,958 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 38,445, 3,403 |

- A tier A item costs 145 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 481 and 594 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 283 more than goose-http's router and query; goose-rest's `/`
  costs 54 fewer.
- Tier M's stack costs 1,339 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the run in this file:

- **Tier A on epoll**, to goose-http alone: 4.1-4.9% behind, where every other tier is
  within 3.9%.
- **Uploads alone**: 1,090-1,110 a second, behind dusty-routes's 1,191 and level with
  Axum's and actix-web's 1,117-1,119.
- **Reads beside uploads on io_uring**: p99 5.92-8.73 ms, as on goose-http's io_uring
  loop, against dusty-routes's 0.58-3.23 ms and goose-rest's own 0.51-1.37 ms on epoll.
- **Memory on uploads**: 71-72 MB, more than dusty-routes's 31 MB and actix-web's 57,
  less than Axum's 163. On tiers A, C, and C templated, and on uploads beside forms, it
  holds the least of the frameworks.
- **Tier M's stack**: 16.7-17.0% of tier A's rate, against dusty-routes's 6.7%.
- **On the epoll loop**, level with dusty-routes on R, B templated, and C templated,
  within 0.3% either way.
