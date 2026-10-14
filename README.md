# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http): Actix's model, changed where Goose
differs, at no cost over a hand-written router wherever the language allows. Routes are
code, middleware is an inlined block, extractors are chosen by type, and errors return
straight to the route. An optional generator writes types, JSON readers and writers,
and a router from an OpenAPI document.

Experimental: a proof of concept with a first runtime core and no stable API, and the
name is provisional. Nothing here is stable enough to build on.

Start with the [tutorial](docs/tutorial.md); the [docs](#docs) table lists the rest.

## Status

🟢 works · 🟡 partial or next · 🔴 not yet

| | Part | Notes |
|---|---|---|
| 🟢 | Package | `rest.goose` imports goose-http at its pin; `scripts/test.sh` runs everything |
| 🟢 | Runtime core | `Cx<S, A, R>`, `serve`, `routes`, `on`, `route`, `fail`, `json`, `text`, `empty`, `otherwise`, one error shape a program can replace ([reference](docs/reference.md#errors)); `serve_one` to test without sockets ([reference](docs/reference.md#testing)) |
| 🟢 | Extractors | Path, query, header, and cookie parameters; `take<T>` for a JSON body or a program's own type; `once` ([reference](docs/reference.md#extractors)) |
| 🟢 | Middleware, scopes, examples | CORS, a bearer check, Server-Timing and the access log, prefix scopes ([reference](docs/reference.md#middleware)); a JSON API with and without a schema |
| 🟢 | Generator | Types, readers, writers, and extractors from OpenAPI's schemas, no `pattern` yet ([reference](docs/generator.md)) |
| 🟢 | TypeScript helper | `ts/api.mts`: write the OpenAPI document in TypeScript, and `tsc` rejects what the generator doesn't support as you type it; cycles, names, and number values stay the generator's checks ([reference](docs/generator.md#write-it-in-typescript)) |
| 🟢 | Generated router | `dispatch` from the paths, with typed path, query, header, and cookie parameters, at one route's cost where the if chain pays 6,000 instructions deep in 60 routes ([reference](docs/generator.md#paths)) |
| 🟢 | Waiting on another thread | `rest::ask`, resuming through the program's `Waiting` enum, replies of any size in pieces (`waiting.goose`, `examples/waiting/`) |
| 🟡 | Benchmark | Against goose-http alone on the Linux desktop: within 0.7-3.2% of its rate where routing and middleware are the work, 8-15% behind on serialized JSON, with 2-7 times its memory ([below](#benchmarks)). Axum, actix-web, and dusty pass their checks and wait for their run (task 010) |

## Layout

```text
rest.goose        the package's entry, namespace rest
runtime.goose     Cx, serve, route, fail, json, text, otherwise, and the error shape
extract.goose     the extractors: parameters, headers, cookies, take, once
middleware.goose  CORS, bearer, timed, and scope
waiting.goose     ask another thread, and resume with its reply
examples/         JSON APIs with and without a schema, waiting on a thread, and a device
check.goose       what generated code calls: code points, string formats, numbers
gen/              goose-rest gen, the generator (gen/main.goose)
ts/               the TypeScript helper: types for the generator's subset, api.mts
test/             unit tests, test_*.goose, each a root file; test/gen/ golden files
scripts/          test.sh runs every test; test-unit.sh the unit tests alone
bench/            measurements: routes.sh counts the routers' instructions per request (task 007),
                  stack.sh a JSON body's and the middleware's (task 015);
                  rest.sh runs the REST benchmark against goose-http and three frameworks (task 010)
spikes/           language checks the design relies on, one folder each with a README
docs/             the tutorial and its programs (docs/tutorial/), references, architecture,
                  development setup, Goose findings
tasks/            task tracking (tasks/README.md)
```

## Quick start

A program declares both packages in its root file, goose-http at the release tag below
and goose-rest at a pushed commit by its full hash:

```goose
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "github.com/kaitk/goose-rest@<40-hex commit>";
```

Build it with `goose build`: a server reaches `thread_spawn`, which `goose run` (TinyCC)
can't run. `scripts/test.sh` builds each example and requests each of its routes:

| Example | What it shows |
|---|---|
| [`examples/plain/`](examples/plain/main.goose) | Without a schema: `rest::on` routes in `rest::routes`, prefix scopes, extractors, a hand-written body reader, middleware, and a 4 MB upload route beside the 1 MB default |
| [`examples/schema/`](examples/schema/) | From `api.json`: the generated types and router in `api_gen.goose`, and the handlers in `app.goose`; `createProject` takes 2 MB by `x-body-limit` |
| [`examples/waiting/`](examples/waiting/main.goose) | Routes that ask a database thread and resume when it replies, with replies larger than a mailbox message, and a database that skips the work of a client that has gone |
| [`examples/device/`](examples/device/) | A board's API from `api.json`: temperature and uptime from sysfs and `/proc`, bounded settings that set an LED through sysfs, a 256 KB firmware upload, a bearer token on writes, CORS, and a page; one worker and small limits |

```sh
goose build -o build/examples/plain examples/plain/main.goose
build/examples/plain 8080
curl -s -H 'Authorization: Bearer secret' -H 'Content-Type: application/json' \
     -d '{"name": "goose"}' localhost:8080/v1/projects
```

[goose-rest, by example](docs/tutorial.md) builds a projects API step by step, from one
route to a schema, middleware, large bodies, state, tests, and a board.

`rest::serve(cfg, app)` puts the worker's state in `cx.app`; an optional `fresh`
argument starts each request's `cx.state`. Hand-written routes use
`rest::routes(cx) { cx => ... };`, `rest::on(cx, method, path)`, and
`rest::scope(cx, prefix)`. Parameters and fallback answers take the context:
`rest::param(cx, name)` and `rest::otherwise(cx)`. A schema's router is
`api::dispatch(cx)`, and its handlers and security checks take `cx` without a state
argument. The [reference](docs/reference.md#context-and-routes) covers
`Cx<S, A, R>`, `rest::NoRouter`, `rest::empty`, and fixed-width Server-Timing.

## Benchmarks

Ryzen 7 5800X3D, WSL2 kernel 6.18.54.1, 4 workers on CPUs 0-3, wrk 4.1.0 with 8 threads
and 256 connections on CPUs 4-15, 3 runs of 15 s after 5 s of warm-up, medians;
goose-rest `b1226e4` and `e44f653` (the same server code), goose-http `v0.3.1`, Goose
`bc3c1f1`, on 2026-10-14 and 2026-10-15. The frameworks haven't run yet, so the
comparison is with goose-http's own REST server, which serves the same routes without a
framework. Every table, the counts, and every loss:
[task 010](tasks/010-benchmark.md#goose-servers-on-linux-2026-10-14-and-2026-10-15);
goose-http's tables against Rust and Zig servers:
[benchmarks.md](https://github.com/kaitk/goose-http/blob/main/docs/benchmarks.md); the
raw runs: [A to D](https://github.com/kaitk/goose-http/tree/main/bench/results/2026-10-14T2039-rest-Tiamat)
and [F, R, M](https://github.com/kaitk/goose-http/tree/main/bench/results/2026-10-14T2039-rest-Tiamat-frm).

| Workload, io_uring loop | goose-rest | goose-http alone | Where goose-rest stands |
|---|---:|---:|---|
| Tier A, items of 0.2 KB | 585 K/s | 598 K/s | 2.2% behind |
| Tier B, a time tracker, serialized | 279 K/s | 315 K/s | 11% behind |
| Tier C, a clinic, serialized | 53.4 K/s | 62.4 K/s | 14% behind |
| Tier C, templates | 142 K/s | 147 K/s | 3.1% behind |
| Tier F, `GET /id/{id}?name=` | 504 K/s | 509 K/s | 1.1% behind |
| Tier R, 203 GitHub routes | 458 K/s generated, 325 K/s if chain | | The generated router 41% faster than the if chain |
| Tier M, tier A with CORS, a bearer check, and Server-Timing | 489 K/s | | 15% below tier A |
| Uploads, alone | 993/s | 1,120/s | 11% behind |
| Reads p99 beside uploads, tier C at 1,700/s | 20-28 ms | 4.8-7.5 ms | 4 times slower |
| Peak RSS, tiers A / C / C templates | 33 / 140 / 387 MB | 12 / 71 / 58 MB | 2-7 times more |

The serialized tiers' loss is in writing JSON: goose-rest's tier server calls
`json::format_string` on every string, where goose-http's skips strings without escapes
after a 16-byte `find_any` scan. The memory and the reads beside uploads aren't
explained yet.

## Docs

| Doc | What it holds |
|---|---|
| [`docs/tutorial.md`](docs/tutorial.md) | goose-rest, by example: the framework in 14 steps, each a program `scripts/test.sh` runs |
| [`docs/reference.md`](docs/reference.md) | Every middleware, extractor, and error code |
| [`docs/generator.md`](docs/generator.md) | What `goose-rest gen` reads, writes, and refuses, and how its router matches |
| [`docs/architecture/README.md`](docs/architecture/README.md) | The design, its decisions, and why: Actix and Elysia, changed where Goose differs |
| [`docs/development.md`](docs/development.md) | The toolchain, the tests, the arm64 checks, the benchmarks, and moving the pins |
| [`docs/goose-findings.md`](docs/goose-findings.md) | Goose compiler and stdlib gaps found here, and their workarounds |

## Pins

| What | Pin | Why |
|---|---|---|
| Goose compiler | `aardappel/goose` `bc3c1f1` (`master`, 2026-10-14) | The language and stdlib change often; this move adds only a logo |
| goose-http | `kaitk/goose-http` `v0.3.1`, commit `faead67` (2026-10-14) | Includes live mailbox keys and the fix that keeps them live through WAKE |

Move each pin in its own commit, with the spikes and tests rerun
([development.md](docs/development.md#move-the-pin)).

## Credits

The runtime takes its model from [actix-web](https://github.com/actix/actix-web): an
`App` of scopes and routes, extractors chosen by type, and middleware around a group of
routes. Where Goose differs, the architecture doc says how and why.

The generator takes its model from Elysia 2, the `kiana` branch of
[Elysia](https://github.com/elysiajs/elysia), read at `c91f61f` (2026-10-11): one
composed handler per route with only the hooks it has and the request parts it reads,
validators inline, and a response writer that copies only declared fields. Goose's
compiler does at build time what Elysia generates at run time or in its AOT build
([architecture](docs/architecture/README.md#the-generator)).
