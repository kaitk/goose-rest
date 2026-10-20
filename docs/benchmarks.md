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
its cells run. Axum, actix-web, ntex, dusty, and Aegon run in their fastest documented
configuration, built in release mode; each serves through its own router, extractors,
and middleware ([servers](../bench/README.md#servers)). A server that fails a tier's
checks isn't measured on it; [Failed checks](#failed-checks) lists each, and why.

Instruction counts come from goose-http's `count.sh`: one worker on CPU 0, the epoll
loop, h2load with 256 connections and 16 requests in flight on each, 10 million
requests, one run per case.

The method behind each number is goose-http's
([its bench/README.md](https://github.com/kaitk/goose-http/blob/main/bench/README.md#method)),
whose `bench/rest.sh` is wrapped by this repository's script of the same name.

## Failed checks

| Server | Tier | Why |
|---|---|---|
| Aegon, both builds | D, uploads | Aegon reads a body whole before a route runs, and its only early refusal is the server's 16 MB limit. A batch that declares more than its route's 1 MB and never sends the body gets no answer, where goose-http's checker wants a 413 at once ([its NOTES.md](../bench/rest/aegon/NOTES.md#tier-d-isnt-measured)). |

## Pins

| Workload | goose-rest | goose-http | Goose compiler | Date | Command |
|---|---|---|---|---|---|
| Tiers A to D, F, R, and M, Goose servers, and instructions per request | `v0.2.1` (`62c340d`) | `v0.4.3` (`0a016bb0`) | master `f114b5a` | 2026-10-20 | `bench/all.sh` |
| Tiers A to C, F, R, and M, Aegon | `85f5542` (`v0.2.0`) | `v0.4.0` | master `f114b5a` | 2026-10-19 | `bench/rest.sh run` |
| Tiers A to D, F, R, and M, Axum, actix-web, ntex, dusty | `e478ca2` | `v0.3.7` | | 2026-10-18 | `bench/rest.sh run` |

The Goose servers ran in session `2026-10-20T0854` after the machine passed the idle
check. Both repositories' tests had passed on WSL before the session. Aegon's cells
are from `2026-10-19T2043`, and the other frameworks' from 2026-10-18 from 23:55Z,
on the same machine and kernel at the same fixed rates. Comparisons with them span
sessions. Competitors: axum 0.8.9, actix-web 4.16.0,
ntex 4.3.0, dusty `ae164fa` with zio 0.19.1 on Zig 0.16.0, hyper 1.12.0, rustc 1.99.0,
and Aegon `8500057` with glaze 9.0.0, built by GCC 16 (`16-20260322`). The memlock limit
was unlimited and `vm.nr_hugepages` 0, so Aegon's buffers count in its peak RSS.

```sh
bench/all.sh
# Earlier competitor runs:
SERVERS="goose-uring goose-epoll goose-uring-rest goose-epoll-rest aegon aegon-small" \
    EXTRA="goose-uring-rest goose-epoll-rest aegon aegon-small" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
SERVERS="axum actix-web ntex dusty-routes dusty hyper" EXTRA="axum actix-web ntex dusty-routes" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
```

The results are in `bench/results/`: the Goose servers'
[A to D](../bench/results/2026-10-20T0854-rest-Tiamat/summary.md),
[F, R, M](../bench/results/2026-10-20T0854-rest-Tiamat/summary-extra.md),
[counts](../bench/results/2026-10-20T0854-rest-Tiamat/count.txt), and
[measurement notes](../bench/results/2026-10-20T0854-rest-Tiamat/notes.md), Aegon's
[A to C](../bench/results/2026-10-19T2043-rest-Tiamat/summary.md) and
[F, R, M](../bench/results/2026-10-19T2043-rest-Tiamat/summary-extra.md), and the other
frameworks' [A to D](../bench/results/2026-10-18T2118-rest-Tiamat-frameworks/summary.md)
and [F, R, M](../bench/results/2026-10-18T2118-rest-Tiamat-frameworks/summary-extra.md).

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
dusty with a route per path (`dusty-routes`), and Aegon. Req/s at saturation.

| Server | A | B | C | C, templates | F, `/id` | F, `/json` | R | M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Aegon (C++) | 513 K | 287 K | 54.0 K | 117 K | **512 K** | 416 K | **497 K** | 402 K |
| Aegon, small buffers | 511 K | 290 K | 54.0 K | 118 K | 510 K | 421 K | 485 K | 404 K |
| dusty-routes (Zig) | 374 K | 166 K | 24.6 K | 138 K | 395 K | 258 K | 359 K | 343 K |
| ntex (Rust) | 332 K | 173 K | 33.5 K | 107 K | 331 K | 263 K | 306 K | 284 K |
| actix-web (Rust) | 276 K | 149 K | 32.5 K | 97.3 K | 278 K | 223 K | 148 K | 227 K |
| Axum (Rust) | 253 K | 142 K | 35.2 K | 92.4 K | 266 K | 210 K | 264 K | 198 K |
| goose-rest, io_uring | **583 K** | **317 K** | **63.2 K** | **155 K** | 498 K | **430 K** | 471 K | **509 K** |
| goose-rest, epoll | 427 K | 243 K | 61.3 K | 144 K | 394 K | 337 K | 375 K | 370 K |
| goose-http alone\*, io_uring | 588 K | 315 K | 63.3 K | 156 K | 500 K | 435 K | | |
| goose-http alone\*, epoll | 438 K | 245 K | 61.7 K | 148 K | 395 K | 339 K | | |

A to C are serialized unless the column says templates. R is goose-rest's generated
router. Bold is the best of the frameworks.  
\* Not a framework: goose-http's REST server answers the same routes with hand-written
routing ([below](#against-goose-http-alone)). It doesn't serve tiers R and M. Where a framework answers differently from goose-http's server, such as Axum's
200 to a CORS preflight, its `NOTES.md` in `bench/rest/` says how and why
([servers](../bench/README.md#servers)).

- goose-rest's io_uring loop leads six of eight columns: 1.14 times Aegon on A, 1.10
  times on B serialized, 1.17 times on C serialized, 1.03 times on F `/json`, and 1.27
  times on M, and 13% ahead of dusty-routes on C templated.
- Aegon leads tier R, 497 K against goose-rest's 471 K, and F `/id`, 512 K against 498
  K. It is the fastest of the other
  frameworks in every column but C templated, where dusty-routes leads it.
- On the epoll loop, goose-rest trails Aegon on A, B, F, R, and M, and leads it on C;
  it leads ntex, actix-web, and Axum everywhere. dusty-routes leads it on F `/id`
  and B templated.
- Aegon's small buffers cost it nothing here: `aegon-small`, 256 buffers a thread
  against 16,384, is within 1.1% of `aegon` in every column but R, where it is 2.4%
  behind, and ahead on B, C templated, F `/json`, and M. Its peak RSS is 27 MB on A
  against 282 MB.
- Tier M's stack costs goose-rest 11.9% of tier A's rate on io_uring and 12.0% on
  epoll, Aegon 16.1%; on 2026-10-18 it cost dusty-routes 6.0%, ntex 14.9%, actix-web
  17.8%, and Axum 22.7%.

Uploads, reads beside them, and peak RSS at saturation:

| Server | Uploads alone | Beside forms: uploads, forms | Reads p99 beside uploads | Peak RSS A / C / C templates / uploads / beside forms |
|---|---:|---:|---:|---:|
| Aegon (C++) | [fails](#failed-checks) | [fails](#failed-checks) | [fails](#failed-checks) | 282 / 578 / 644 MB |
| Aegon, small buffers | [fails](#failed-checks) | [fails](#failed-checks) | [fails](#failed-checks) | 27 / 321 / 388 MB |
| dusty-routes (Zig) | 1,230/s | 25-35/s, 3.0-3.1 K/s | 0.65-3.20 ms | 15 / 216 / 241 / 31 / 781 MB |
| ntex (Rust) | 1,198/s | 100-102/s, 4.6-4.7 K/s | 1.83-4.83 ms | 42 / 206 / 328 / 86 / 268 MB |
| actix-web (Rust) | 1,201/s | 94-95/s, 4.7-4.8 K/s | 16.7-19.6 ms | 19 / 332 / 384 / 57 / 196 MB |
| Axum (Rust) | 1,168/s | 35-36/s, 5.1-5.2 K/s | 8.52-10.5 ms | 26 / 482 / 584 / 162 / 261 MB |
| goose-rest, io_uring | 1,124/s | 150-156/s, 6.7-6.9 K/s | 6.33-8.67 ms | 13 / 71 / 58 / 71 / 123 MB |
| goose-rest, epoll | 1,141/s | 108-116/s, 7.2-7.3 K/s | 0.40-1.28 ms | 8 / 69 / 58 / 70 / 149 MB |
| goose-http alone\*, io_uring | 1,146/s | 170-175/s, 7.7-7.8 K/s | 4.66-8.20 ms | 13 / 71 / 58 / 71 / 125 MB |
| goose-http alone\*, epoll | 1,162/s | 123-125/s, 7.7-8.0 K/s | 0.34-1.34 ms | 8 / 69 / 58 / 69 / 132 MB |

"Reads p99" is the range over tier C's six routes and the three runs. Alone, the Goose
servers' reads have a p99 of 0.15-0.90 ms, and on 2026-10-18 the frameworks' 0.16-1.84
ms. Every server measured reached every fixed rate. Of Aegon's peak RSS, 256 MB is its 16,384 buffers of 4 KB in each of
the 4 workers, 1 MB each in `aegon-small`; what else it holds on tier C, about 300 MB
more than on A in both builds, isn't measured.

## Against goose-http alone

goose-http's REST server serves the same routes from the same records without a
framework, so the difference is what goose-rest costs.

### Rates

Tiers A to C at saturation, req/s, on the same loop:

| Tier | JSON | io_uring: goose-http | goose-rest | epoll: goose-http | goose-rest |
|---|---|---:|---:|---:|---:|
| A | serialize | 588 K | 583 K (-0.8%) | 438 K | 427 K (-2.4%) |
| A | template | 601 K | 593 K (-1.4%) | 455 K | 442 K (-2.8%) |
| B | serialize | 315 K | 317 K (+0.3%) | 245 K | 243 K (-0.6%) |
| B | template | 391 K | 391 K (-0.2%) | 297 K | 292 K (-1.4%) |
| C | serialize | 63.3 K | 63.2 K (-0.2%) | 61.7 K | 61.3 K (-0.6%) |
| C | template | 156 K | 155 K (-0.6%) | 148 K | 144 K (-2.6%) |

Tiers F, R, and M, req/s and, for M, CPU per request:

| Tier | Request | io_uring | epoll |
|---|---|---:|---:|
| F | `GET /`: goose-http's router, then goose-rest | 509 K, 511 K (+0.4%) | 407 K, 402 K (-1.4%) |
| F | `GET /id/{id}?name=` | 500 K, 498 K (-0.5%) | 395 K, 394 K (-0.3%) |
| F | `POST /json` | 435 K, 430 K (-1.2%) | 339 K, 337 K (-0.7%) |
| R | 203 routes: if chain, generated router | 331 K, 471 K (+42%) | 264 K, 375 K (+42%) |
| M | tier A, then with the stack | 577 K, 509 K (-11.9%), 6.9 → 7.8 µs | 421 K, 370 K (-12.0%), 9.5 → 10.8 µs |

- goose-rest is within 2.8% of goose-http's rate on every tier from A to C.
- The generated router serves tier R 42% faster than the if chain, which pays about
  179 instructions per route it passes, 35,898 more at route 201.

### Uploads and memory

| Workload, io_uring | goose-http | goose-rest |
|---|---:|---:|
| Uploads alone | 1,146/s | 1,124/s |
| Reads p99 beside uploads | 4.66-8.20 ms | 6.33-8.67 ms |
| Peak RSS, tier A | 13 MB | 13 MB |
| Peak RSS, tier B | 30 MB | 31 MB |
| Peak RSS, tier C | 71 MB | 71 MB |
| Peak RSS, tier C templated | 58 MB | 58 MB |
| Peak RSS, uploads alone | 71 MB | 71 MB |

On epoll, uploads alone ran at 1,162 a second on goose-http and 1,141 on goose-rest, and
the reads beside them had a p99 of 0.34-1.34 ms against 0.40-1.28 ms.

### Instructions per request

User instructions per request:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 4,155 | 4,222 |
| Tier A `GET /api/me` without a user, 401 | 3,637 | 4,026 |
| Tier A `GET /nothing`, 404 | 2,621 | 3,160 |
| Tier M `GET /api/items/1` without a token, 401 | | 4,968 |
| Tier F `GET /` | 2,408 (bare) | 2,305 |
| Tier F `GET /id/1?name=bun` | 2,983 (bare) | 3,213 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 3,159, 2,733 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 39,057, 3,224 |

- A tier A item costs 67 instructions more on goose-rest.
- goose-rest's 401 and 404 cost 389 and 539 more, and answer with a JSON body where
  goose-http's server sends none.
- Tier F's `/id` costs 230 more than goose-http's router and query; goose-rest's `/`
  costs 104 fewer.
- Tier M's stack costs 942 instructions on a 401, against tier A's 401.

## Where goose-rest loses

From the runs in this file:

- **Tier C templated**, to goose-http alone: 0.6% behind on io_uring and 2.6% on
  epoll. The largest gap on A to C is A templated on epoll, 2.8%.
- **To Aegon**: tier R, 471 K against 497 K, and F `/id`, 498 K against 512 K, on
  io_uring; on epoll, A, B, F, R, and M.
- **Uploads alone**: 1,124 a second on io_uring and 1,141 on epoll, 1.9% and 1.8%
  behind goose-http alone, and behind every framework that serves them: dusty-routes's
  1,230, actix-web's 1,201, ntex's 1,198, and Axum's 1,168.
- **Uploads beside forms**: 150-156 a second on io_uring against goose-http's 170-175,
  with forms at 6.7-6.9 K/s against 7.7-7.8 K/s.
- **Reads beside uploads on io_uring**: p99 6.33-8.67 ms, as on goose-http's io_uring
  loop, against dusty-routes's 0.65-3.20 ms, ntex's 1.83-4.83 ms, and goose-rest's own
  0.40-1.28 ms on epoll.
- **Memory on uploads**: 69-71 MB, more than dusty-routes's 31 MB and actix-web's 57,
  less than ntex's 86 and Axum's 162. On tiers A, C, and C templated, and on uploads
  beside forms, it holds the least of the frameworks.
- **Tier M's stack**: 11.9-12.0% of tier A's rate, against dusty-routes's 6.0%, ntex's
  14.9%, and Aegon's 16.1%.
- **On the epoll loop**, to dusty-routes on F `/id`, 394 K against 395 K, and on B
  templated, 292 K against 311 K.
