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
| Tiers A to D, F, R, and M, Goose servers, and instructions per request | `v0.1.2` | `v0.3.6` | `v2026.2` | 2026-10-16 | `bench/all.sh`'s steps for this repository |
| Tiers A to D, F, R, and M, Axum, actix-web, dusty | | | | 2026-10-16 | `bench/rest.sh run` |

The Goose servers ran in session `2026-10-16T1525`: `bench/all.sh`'s steps for this
repository, its tests, the Goose builds, `bench/rest.sh check`, `run`, and `count`,
right after goose-http's steps had run in a session of their own. goose-http's checkout
was `032d630d`, whose code is `v0.3.6`'s. The frameworks' cells come from the
morning's session, `2026-10-16T0547`, on the same machine at the same fixed rates, so
comparisons with them span sessions, which have drifted by up to 5%. Competitors: axum
0.8.9, actix-web 4.16.0, dusty `ae164fa` with zio 0.19.1 on Zig 0.16.0, hyper 1.12.0,
rustc 1.99.0.

```sh
GOOSE_HTTP=<goose-http checkout> bench/all.sh
SERVERS="axum actix-web dusty-routes dusty hyper" EXTRA="axum actix-web dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
```

The results are in `bench/results/`: the Goose servers'
[A to D](../bench/results/2026-10-16T1525-rest-Tiamat/summary.md),
[F, R, M](../bench/results/2026-10-16T1525-rest-Tiamat/summary-extra.md), and
[counts](../bench/results/2026-10-16T1525-rest-Tiamat/count.txt), and the frameworks'
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
| goose-rest, io_uring | **579 K** | **311 K** | **61.3 K** | **140 K** | **505 K** | **429 K** | **470 K** | **492 K** |
| goose-rest, epoll | 421 K | 241 K | 59.7 K | 131 K | 396 K | 345 K | 373 K | 365 K |
| goose-http alone\*, io_uring | 588 K | 311 K | 62.1 K | 147 K | 511 K | 439 K | | |
| goose-http alone\*, epoll | 429 K | 240 K | 61.4 K | 136 K | 403 K | 345 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads every column: 1.7 times the next framework on A,
  1.9 times on B serialized, 1.8 times Axum on C serialized, 1.3-1.7 times dusty-routes
  on F, R, and M, and 6% ahead of dusty-routes on C templated.
- On the epoll loop, goose-rest leads dusty-routes on R, 373 K against 360 K, and
  trails it on C templated, 131 K against 133 K, and on B templated, 286 K against
  299 K.
- Tier M's stack costs goose-rest 17.0% of tier A's rate on io_uring and 15.7% on
  epoll; it costs dusty-routes 6.0%, actix-web 16.7%, and Axum 24.5%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads / beside forms |
|---|---:|---:|---:|---:|
| dusty-routes (Zig) | 1,225/s | 31-37/s, 3.0 K/s | 0.60-3.31 ms | 15 / 216 / 242 / 31 / 781 MB |
| actix-web (Rust) | 1,142/s | 93/s, 4.7 K/s | 18.1-22.0 ms | 20 / 338 / 395 / 56 / 182 MB |
| Axum (Rust) | 1,153/s | 33-35/s, 5.0 K/s | 9.6-11.3 ms | 27 / 491 / 579 / 148 / 256 MB |
| goose-rest, io_uring | 1,120/s | 159-160/s, 7.1 K/s | 5.51-8.42 ms | 13 / 71 / 58 / 71 / 123 MB |
| goose-rest, epoll | 1,144/s | 116-121/s, 7.4-7.5 K/s | 0.46-1.26 ms | 8 / 69 / 58 / 69 / 149 MB |
| goose-http alone\*, io_uring | 1,152/s | 175-178/s, 7.7-7.8 K/s | 4.95-7.92 ms | 12 / 71 / 58 / 71 / 125 MB |
| goose-http alone\*, epoll | 1,180/s | 124-126/s, 8.1-8.3 K/s | 0.39-1.34 ms | 7 / 69 / 58 / 69 / 134 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, the Goose
servers' reads have a p99 of 0.14-0.88 ms, and the frameworks' 0.16-1.91 ms. Every
server reached every fixed rate.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 588 K | 579 K (-1.5%) | 429 K | 421 K (-1.9%) |
| A | template | 606 K | 592 K (-2.2%) | 455 K | 443 K (-2.6%) |
| B | serialize | 311 K | 311 K (+0.1%) | 240 K | 241 K (+0.2%) |
| B | template | 380 K | 382 K (+0.3%) | 289 K | 286 K (-0.8%) |
| C | serialize | 62.1 K | 61.3 K (-1.3%) | 61.4 K | 59.7 K (-2.8%) |
| C | template | 147 K | 140 K (-4.5%) | 136 K | 131 K (-3.7%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 518 K, 517 K (-0.2%) | 413 K, 405 K (-1.9%) |
| F | `GET /id/{id}?name=` | 511 K, 505 K (-1.3%) | 403 K, 396 K (-1.7%) |
| F | `POST /json` | 439 K, 429 K (-2.3%) | 345 K, 345 K (-0.1%) |
| R | 203 routes: if chain, generated router | 325 K, 470 K (+44%) | 263 K, 373 K (+42%) |
| M | tier A, then with the stack | 592 K, 492 K (-17.0%), 6.7 → 8.1 µs | 433 K, 365 K (-15.7%), 9.2 → 11.0 µs |

- goose-rest is within 4.5% of goose-http's rate on every tier, and level with it on
  B.
- The generated router serves tier R 42-44% faster than the if chain, which pays about
  179 instructions per route it passes, 35,889 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,152/s | 1,120/s |
| Reads p99 beside uploads | 4.95-7.92 ms | 5.51-8.42 ms |
| Peak RSS, tier A | 12 MB | 13 MB |
| Peak RSS, tier B | 30 MB | 30 MB |
| Peak RSS, tier C | 71 MB | 71 MB |
| Peak RSS, tier C templated | 58 MB | 58 MB |
| Peak RSS, uploads alone | 71 MB | 71 MB |

On epoll, uploads alone ran at 1,180 a second on goose-http and 1,144 on goose-rest, and
the reads beside them had a p99 of 0.39-1.34 ms against 0.46-1.26 ms.

### Instructions per request

User instructions per request:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 4,122 | 4,250 |
| Tier A `GET /api/me` without a user, 401 | 4,090 | 4,564 |
| Tier A `GET /nothing`, 404 | 2,602 | 3,188 |
| Tier M `GET /api/items/1` without a token, 401 | | 5,898 |
| Tier F `GET /` | 2,397 (bare) | 2,338 |
| Tier F `GET /id/1?name=bun` | 2,973 (bare) | 3,263 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,211, 2,847 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 39,100, 3,321 |

- A tier A item costs 128 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 474 and 586 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 290 more than goose-http's router and query; goose-rest's `/`
  costs 59 fewer.
- Tier M's stack costs 1,334 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the runs in this file:

- **Tier C and templated tier A**, to goose-http alone: 1.3-4.5% behind, the most on
  C templated, 4.5% on io_uring and 3.7% on epoll.
- **Uploads alone**: 1,120 a second on io_uring and 1,144 on epoll, 2.8% and 3.1%
  behind goose-http alone, and behind dusty-routes's 1,225 and Axum's 1,153.
- **Uploads beside forms**: 159-160 a second on io_uring against goose-http's 175-178,
  with forms at 7.1 K/s against 7.7-7.8 K/s.
- **Reads beside uploads on io_uring**: p99 5.51-8.42 ms, as on goose-http's io_uring
  loop, against dusty-routes's 0.60-3.31 ms and goose-rest's own 0.46-1.26 ms on epoll.
- **Memory on uploads**: 69-71 MB, more than dusty-routes's 31 MB and actix-web's 56,
  less than Axum's 148. On tiers A, C, and C templated, and on uploads beside forms, it
  holds the least of the frameworks.
- **Tier M's stack**: 15.7-17.0% of tier A's rate, against dusty-routes's 6.0%.
- **On the epoll loop**, to dusty-routes on B templated, 286 K against 299 K, and C
  templated, 131 K against 133 K.
