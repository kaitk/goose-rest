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
whose `bench/rest.sh` is wrapped by this repository's script of the same name.

## Pins

| Workload | goose-rest | goose-http | Goose compiler | Date | Command |
|---|---|---|---|---|---|
| Tiers A to D, F, R, and M, and instructions per request, every server | `v0.1.1` | `v0.3.4` | `v2026.1` | 2026-10-16 | `bench/all.sh`, then `bench/rest.sh run` |

One session ran every number in this file: the Goose servers through `bench/all.sh`,
then the frameworks at the same fixed rates. goose-http's checkout was `f875101a`, whose
code is `v0.3.4`'s. Competitors: axum 0.8.9, actix-web 4.16.0, dusty `ae164fa` with zio
0.19.1 on Zig 0.16.0, hyper 1.12.0, rustc 1.99.0.

```sh
GOOSE_HTTP=<goose-http checkout> bench/all.sh
SERVERS="axum actix-web dusty-routes dusty hyper" EXTRA="axum actix-web dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
```

The results are in `bench/results/`: the Goose servers'
[A to D](../bench/results/2026-10-16T0547-rest-Tiamat/summary.md),
[F, R, M](../bench/results/2026-10-16T0547-rest-Tiamat/summary-extra.md), and
[counts](../bench/results/2026-10-16T0547-rest-Tiamat/count.txt), and the frameworks'
[A to D](../bench/results/2026-10-16T0547-rest-Tiamat-frameworks/summary.md) and
[F, R, M](../bench/results/2026-10-16T0547-rest-Tiamat-frameworks/summary-extra.md).

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
tier A's with an `Origin` field. Comparing it with tier A measures the cost of the stack.

## Against other frameworks

goose-rest on the io_uring loop and on the epoll loop, against Axum, actix-web, and
dusty with a route per path (`dusty-routes`). Req/s at saturation.

| Server | A | B | C | C, templates | F, `/id` | F, `/json` | R | M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| dusty-routes (Zig) | 349 K | 163 K | 23.8 K | 133 K | 372 K | 258 K | 360 K | 334 K |
| actix-web (Rust) | 262 K | 143 K | 31.9 K | 92.6 K | 271 K | 220 K | 145 K | 221 K |
| Axum (Rust) | 242 K | 139 K | 34.6 K | 89.1 K | 256 K | 200 K | 253 K | 184 K |
| goose-rest, io_uring | **586 K** | **311 K** | **61.8 K** | **142 K** | **494 K** | **430 K** | **466 K** | **489 K** |
| goose-rest, epoll | 441 K | 240 K | 60.5 K | 133 K | 390 K | 342 K | 369 K | 358 K |
| goose-http alone\*, io_uring | 602 K | 311 K | 62.4 K | 148 K | 498 K | 431 K | | |
| goose-http alone\*, epoll | 450 K | 243 K | 61.2 K | 138 K | 397 K | 343 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads every column: 1.7 times the next framework on A,
  1.9 times on B serialized, 1.8 times Axum on C serialized, 1.3-1.7 times dusty-routes
  on F, R, and M, and 7% ahead of dusty-routes on C templated.
- On the epoll loop, goose-rest leads dusty-routes on R, 369 K against 360 K, ties it
  on C templated, 133 K each, and trails it on B templated, 290 K against 299 K.
- Tier M's stack costs goose-rest 15.8% of tier A's rate on io_uring and 18.8% on
  epoll; it costs dusty-routes 6.0%, actix-web 16.7%, and Axum 24.5%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads / beside forms |
|---|---:|---:|---:|---:|
| dusty-routes (Zig) | 1,225/s | 31-37/s, 3.0 K/s | 0.60-3.31 ms | 15 / 216 / 242 / 31 / 781 MB |
| actix-web (Rust) | 1,142/s | 93/s, 4.7 K/s | 18.1-22.0 ms | 20 / 338 / 395 / 56 / 182 MB |
| Axum (Rust) | 1,153/s | 33-35/s, 5.0 K/s | 9.6-11.3 ms | 27 / 491 / 579 / 148 / 256 MB |
| goose-rest, io_uring | 1,127/s | 165-175/s, 7.2-7.6 K/s | 6.47-8.88 ms | 13 / 72 / 57 / 72 / 133 MB |
| goose-rest, epoll | 1,125/s | 122-126/s, 7.7-8.1 K/s | 0.50-1.39 ms | 8 / 70 / 58 / 70 / 158 MB |
| goose-http alone\*, io_uring | 1,135/s | 164-165/s, 7.4-7.5 K/s | 6.03-10.6 ms | 12 / 70 / 58 / 70 / 125 MB |
| goose-http alone\*, epoll | 1,134/s | 119-121/s, 7.5 K/s | 0.47-1.29 ms | 8 / 69 / 58 / 69 / 132 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, the Goose
servers' reads have a p99 of 0.14-0.86 ms, and the frameworks' 0.16-1.91 ms. Every
server reached every fixed rate.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 602 K | 586 K (-2.7%) | 450 K | 441 K (-2.1%) |
| A | template | 609 K | 584 K (-4.1%) | 457 K | 451 K (-1.2%) |
| B | serialize | 311 K | 311 K (-0.1%) | 243 K | 240 K (-0.9%) |
| B | template | 398 K | 392 K (-1.5%) | 299 K | 290 K (-3.1%) |
| C | serialize | 62.4 K | 61.8 K (-1.0%) | 61.2 K | 60.5 K (-1.1%) |
| C | template | 148 K | 142 K (-3.9%) | 138 K | 133 K (-3.4%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 505 K, 508 K (+0.6%) | 410 K, 404 K (-1.4%) |
| F | `GET /id/{id}?name=` | 498 K, 494 K (-0.9%) | 397 K, 390 K (-1.8%) |
| F | `POST /json` | 431 K, 430 K (-0.3%) | 343 K, 342 K (-0.2%) |
| R | 203 routes: if chain, generated router | 332 K, 466 K (+40%) | 265 K, 369 K (+39%) |
| M | tier A, then with the stack | 581 K, 489 K (-15.8%), 6.8 → 8.2 µs | 441 K, 358 K (-18.8%), 9.1 → 11.2 µs |

- goose-rest is within 0.1-4.1% of goose-http's rate on every tier.
- The generated router serves tier R 39-40% faster than the if chain, which pays about
  176 instructions per route it passes, 35,250 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,135/s | 1,127/s |
| Reads p99 beside uploads | 6.03-10.6 ms | 6.47-8.88 ms |
| Peak RSS, tier A | 12 MB | 13 MB |
| Peak RSS, tier B | 30 MB | 32 MB |
| Peak RSS, tier C | 70 MB | 72 MB |
| Peak RSS, tier C templated | 58 MB | 57 MB |
| Peak RSS, uploads alone | 70 MB | 72 MB |

On epoll, uploads alone ran at 1,134 a second on goose-http and 1,125 on goose-rest, and
the reads beside them had a p99 of 0.47-1.29 ms against 0.50-1.39 ms.

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
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,195, 2,829 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 38,445, 3,314 |

- A tier A item costs 145 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 481 and 594 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 283 more than goose-http's router and query; goose-rest's `/`
  costs 54 fewer.
- Tier M's stack costs 1,339 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the run in this file:

- **Templated tiers**, to goose-http alone: 1.2-4.1% behind on A, B, and C templated.
- **Uploads alone**: 1,125-1,127 a second, behind dusty-routes's 1,225 and 1-2% behind
  Axum's 1,153 and actix-web's 1,142.
- **Reads beside uploads on io_uring**: p99 6.47-8.88 ms, as on goose-http's io_uring
  loop, against dusty-routes's 0.60-3.31 ms and goose-rest's own 0.50-1.39 ms on epoll.
- **Memory on uploads**: 70-72 MB, more than dusty-routes's 31 MB and actix-web's 56,
  less than Axum's 148. On tiers A, C, and C templated, and on uploads beside forms, it
  holds the least of the frameworks.
- **Tier M's stack**: 15.8-18.8% of tier A's rate, against dusty-routes's 6.0%.
- **On the epoll loop**, to dusty-routes on B templated, 290 K against 299 K.
