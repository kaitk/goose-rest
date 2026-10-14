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
| 🟢 | Runtime core | `Cx`, `serve`, `route`, `fail`, `json`, `text`, `otherwise`, one error shape a program can replace ([reference](docs/reference.md#errors)); `serve_one` to test without sockets ([reference](docs/reference.md#testing)) |
| 🟢 | Extractors | Path, query, header, and cookie parameters; `take<T>` for a JSON body or a program's own type; `once` ([reference](docs/reference.md#extractors)) |
| 🟢 | Middleware, scopes, examples | CORS, a bearer check, Server-Timing and the access log, prefix scopes ([reference](docs/reference.md#middleware)); a JSON API with and without a schema |
| 🟢 | Generator | Types, readers, writers, and extractors from OpenAPI's schemas, no `pattern` yet ([reference](docs/generator.md)) |
| 🟢 | TypeScript helper | `ts/api.mts`: write the OpenAPI document in TypeScript, and `tsc` rejects what the generator doesn't support as you type it; cycles, names, and number values stay the generator's checks ([reference](docs/generator.md#write-it-in-typescript)) |
| 🟢 | Generated router | `dispatch` from the paths, with typed path, query, header, and cookie parameters, at one route's cost where the if chain pays 6,000 instructions deep in 60 routes ([reference](docs/generator.md#paths)) |
| 🟢 | Waiting on another thread | `rest::ask`, resuming through the program's `Waiting` enum, replies of any size in pieces (`waiting.goose`, `examples/waiting/`) |
| 🟡 | Benchmark | Against goose-http alone, Axum, actix-web, and dusty on goose-http's REST tiers and three of its own, F, R, and M (`bench/rest.sh`); the servers pass their checks, and the runs wait on the Linux desktop (task 010) |

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

A program declares both packages in its root file, goose-http at the pin below and
goose-rest at a pushed commit, each by its full hash:

```goose
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "github.com/kaitk/goose-rest@<40-hex commit>";
```

Build it with `goose build`: a server reaches `thread_spawn`, which `goose run` (TinyCC)
can't run. `scripts/test.sh` builds each example and requests each of its routes:

| Example | What it shows |
|---|---|
| [`examples/plain/`](examples/plain/main.goose) | Without a schema: routes in an `http::router` chain under a scope, extractors, a hand-written body reader, the middleware, and a 4 MB upload route beside the 1 MB default |
| [`examples/schema/`](examples/schema/) | From `api.json`: the generated types and router in `api_gen.goose`, and the handlers in `app.goose`; `createProject` takes 2 MB by `x-body-limit` |
| [`examples/waiting/`](examples/waiting/main.goose) | Routes that ask a database thread and resume when it replies, with replies larger than a mailbox message |
| [`examples/device/`](examples/device/) | A board's API from `api.json`: temperature and uptime from sysfs and `/proc`, bounded settings that set an LED through sysfs, a 256 KB firmware upload, a bearer token on writes, CORS, and a page; one worker and small limits |

```sh
goose build -o build/examples/plain examples/plain/main.goose
build/examples/plain 8080
curl -s -H 'Authorization: Bearer secret' -H 'Content-Type: application/json' \
     -d '{"name": "goose"}' localhost:8080/v1/projects
```

[goose-rest, by example](docs/tutorial.md) builds a projects API step by step, from one
route to a schema, middleware, large bodies, state, tests, and a board.

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
| Goose compiler | `aardappel/goose` `46356c2` (`master`, 2026-10-14) | The language and stdlib change often |
| goose-http | `kaitk/goose-http` `bc75f2a` (`main`, 2026-10-14) | Its API is still changing (its task 027) |

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
