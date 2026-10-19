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
its cells run. Axum, actix-web, ntex, and dusty run in their fastest documented
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
| Tiers A to D, F, R, and M, Goose servers, and instructions per request | `e478ca2` | `v0.3.7` | `v2026.2` | 2026-10-18 | `bench/all.sh` |
| Tiers A to D, F, R, and M, Axum, actix-web, ntex, dusty | `e478ca2` | `v0.3.7` | | 2026-10-18 | `bench/rest.sh run` |

The Goose servers ran in session `2026-10-18T2118`, `bench/all.sh` for both
repositories: their tests, the Goose builds, `bench/rest.sh check`, goose-http's own
runs, `bench/rest.sh run`, and the counts. goose-http's checkout was `edd83c4b`, the
tag `v0.3.7`. The frameworks ran right after it, from 2026-10-18T23:55Z, on the same
machine at the same fixed rates, once the machine was idle again, so comparisons with
them span two runs of one night. Competitors: axum 0.8.9, actix-web 4.16.0, ntex 4.3.0,
dusty `ae164fa` with zio 0.19.1 on Zig 0.16.0, hyper 1.12.0, rustc 1.99.0.

```sh
GOOSE_HTTP=<goose-http checkout> bench/all.sh
SERVERS="axum actix-web ntex dusty-routes dusty hyper" EXTRA="axum actix-web ntex dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
```

The results are in `bench/results/`: the Goose servers'
[A to D](../bench/results/2026-10-18T2118-rest-Tiamat/summary.md),
[F, R, M](../bench/results/2026-10-18T2118-rest-Tiamat/summary-extra.md), and
[counts](../bench/results/2026-10-18T2118-rest-Tiamat/count.txt), and the frameworks'
[A to D](../bench/results/2026-10-18T2118-rest-Tiamat-frameworks/summary.md) and
[F, R, M](../bench/results/2026-10-18T2118-rest-Tiamat-frameworks/summary-extra.md).

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

goose-rest on the io_uring loop and on the epoll loop, against Axum, actix-web, ntex,
and dusty with a route per path (`dusty-routes`). Req/s at saturation.

| Server | A | B | C | C, templates | F, `/id` | F, `/json` | R | M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| dusty-routes (Zig) | 374 K | 166 K | 24.6 K | 138 K | 395 K | 258 K | 359 K | 343 K |
| ntex (Rust) | 332 K | 173 K | 33.5 K | 107 K | 331 K | 263 K | 306 K | 284 K |
| actix-web (Rust) | 276 K | 149 K | 32.5 K | 97.3 K | 278 K | 223 K | 148 K | 227 K |
| Axum (Rust) | 253 K | 142 K | 35.2 K | 92.4 K | 266 K | 210 K | 264 K | 198 K |
| goose-rest, io_uring | **600 K** | **318 K** | **62.7 K** | **148 K** | **508 K** | **439 K** | **475 K** | **504 K** |
| goose-rest, epoll | 449 K | 250 K | 61.3 K | 138 K | 400 K | 343 K | 376 K | 365 K |
| goose-http alone\*, io_uring | 608 K | 316 K | 64.0 K | 153 K | 519 K | 443 K | | |
| goose-http alone\*, epoll | 469 K | 247 K | 62.9 K | 145 K | 403 K | 345 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads every column: 1.6 times dusty-routes on A, 1.8
  times ntex on B serialized, 1.8 times Axum on C serialized, 1.3-1.7 times the best
  other framework on F, R, and M, and 7% ahead of dusty-routes on C templated.
- On the epoll loop, goose-rest leads every framework on A to C serialized, F, R, and
  M, and trails dusty-routes on C templated, 137.6 K against 138.3 K, and on B
  templated, 308 K against 311 K.
- Tier M's stack costs goose-rest 15.0% of tier A's rate on io_uring and 19.3% on
  epoll; it costs dusty-routes 6.0%, ntex 14.9%, actix-web 17.8%, and Axum 22.7%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads / beside forms |
|---|---:|---:|---:|---:|
| dusty-routes (Zig) | 1,230/s | 25-35/s, 3.0-3.1 K/s | 0.65-3.20 ms | 15 / 216 / 241 / 31 / 781 MB |
| ntex (Rust) | 1,198/s | 100-102/s, 4.6-4.7 K/s | 1.83-4.83 ms | 42 / 206 / 328 / 86 / 268 MB |
| actix-web (Rust) | 1,201/s | 94-95/s, 4.7-4.8 K/s | 16.7-19.6 ms | 19 / 332 / 384 / 57 / 196 MB |
| Axum (Rust) | 1,168/s | 35-36/s, 5.1-5.2 K/s | 8.52-10.5 ms | 26 / 482 / 584 / 162 / 261 MB |
| goose-rest, io_uring | 1,142/s | 154-157/s, 6.9-7.0 K/s | 5.61-8.41 ms | 13 / 71 / 58 / 71 / 121 MB |
| goose-rest, epoll | 1,163/s | 114-119/s, 7.3-7.4 K/s | 0.51-1.43 ms | 8 / 69 / 58 / 69 / 150 MB |
| goose-http alone\*, io_uring | 1,182/s | 168-169/s, 7.5-7.6 K/s | 5.18-8.36 ms | 13 / 71 / 58 / 71 / 126 MB |
| goose-http alone\*, epoll | 1,192/s | 123-124/s, 7.8-7.9 K/s | 0.38-1.29 ms | 8 / 69 / 58 / 69 / 133 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, the Goose
servers' reads have a p99 of 0.14-0.94 ms, and the frameworks' 0.16-1.84 ms. Every
server reached every fixed rate.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 608 K | 600 K (-1.3%) | 469 K | 449 K (-4.3%) |
| A | template | 615 K | 608 K (-1.2%) | 482 K | 473 K (-2.0%) |
| B | serialize | 316 K | 318 K (+0.6%) | 247 K | 250 K (+0.8%) |
| B | template | 396 K | 397 K (+0.2%) | 304 K | 308 K (+1.3%) |
| C | serialize | 64.0 K | 62.7 K (-2.0%) | 62.9 K | 61.3 K (-2.5%) |
| C | template | 153 K | 148 K (-3.8%) | 145 K | 138 K (-5.2%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 529 K, 517 K (-2.2%) | 414 K, 410 K (-1.1%) |
| F | `GET /id/{id}?name=` | 519 K, 508 K (-2.2%) | 403 K, 400 K (-0.9%) |
| F | `POST /json` | 443 K, 439 K (-0.9%) | 345 K, 343 K (-0.7%) |
| R | 203 routes: if chain, generated router | 333 K, 475 K (+43%) | 265 K, 376 K (+42%) |
| M | tier A, then with the stack | 593 K, 504 K (-15.0%), 6.7 → 7.9 µs | 453 K, 365 K (-19.3%), 8.8 → 11.0 µs |

- goose-rest is within 5.2% of goose-http's rate on every tier, and level with it or
  ahead on B.
- The generated router serves tier R 42-43% faster than the if chain, which pays about
  179 instructions per route it passes, 35,889 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,182/s | 1,142/s |
| Reads p99 beside uploads | 5.18-8.36 ms | 5.61-8.41 ms |
| Peak RSS, tier A | 13 MB | 13 MB |
| Peak RSS, tier B | 30 MB | 30 MB |
| Peak RSS, tier C | 71 MB | 71 MB |
| Peak RSS, tier C templated | 58 MB | 58 MB |
| Peak RSS, uploads alone | 71 MB | 71 MB |

On epoll, uploads alone ran at 1,192 a second on goose-http and 1,163 on goose-rest, and
the reads beside them had a p99 of 0.38-1.29 ms against 0.51-1.43 ms.

### Instructions per request

User instructions per request:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 4,107 | 4,238 |
| Tier A `GET /api/me` without a user, 401 | 4,077 | 4,552 |
| Tier A `GET /nothing`, 404 | 2,589 | 3,176 |
| Tier M `GET /api/items/1` without a token, 401 | | 5,886 |
| Tier F `GET /` | 2,385 (bare) | 2,326 |
| Tier F `GET /id/1?name=bun` | 2,961 (bare) | 3,251 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,199, 2,835 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 39,088, 3,309 |

- A tier A item costs 131 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 475 and 587 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 290 more than goose-http's router and query; goose-rest's `/`
  costs 59 fewer.
- Tier M's stack costs 1,334 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the runs in this file:

- **Tiers A and C**, to goose-http alone: 1.2-5.2% behind, the most on C templated,
  3.8% on io_uring and 5.2% on epoll, and on A serialized on epoll, 4.3%.
- **Uploads alone**: 1,142 a second on io_uring and 1,163 on epoll, 3.4% and 2.4%
  behind goose-http alone, and behind every framework: dusty-routes's 1,230,
  actix-web's 1,201, ntex's 1,198, and Axum's 1,168.
- **Uploads beside forms**: 154-157 a second on io_uring against goose-http's 168-169,
  with forms at 6.9-7.0 K/s against 7.5-7.6 K/s.
- **Reads beside uploads on io_uring**: p99 5.61-8.41 ms, as on goose-http's io_uring
  loop, against dusty-routes's 0.65-3.20 ms, ntex's 1.83-4.83 ms, and goose-rest's own
  0.51-1.43 ms on epoll.
- **Memory on uploads**: 69-71 MB, more than dusty-routes's 31 MB and actix-web's 57,
  less than ntex's 86 and Axum's 162. On tiers A, C, and C templated, and on uploads
  beside forms, it holds the least of the frameworks.
- **Tier M's stack**: 15.0-19.3% of tier A's rate, against dusty-routes's 6.0% and
  ntex's 14.9%.
- **On the epoll loop**, to dusty-routes on B templated, 308 K against 311 K, and C
  templated, 137.6 K against 138.3 K.
