# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http): Actix's model, changed where Goose
differs, at no cost over a hand-written router wherever the language allows. Routes are
code, middleware is an inlined block, extractors are chosen by type, and errors return
straight to the route. An optional generator writes types, JSON readers and writers,
and a router from an OpenAPI document.

Experimental: a proof of concept with no framework API yet, and the name is provisional.
Nothing here is stable enough to build on.

The design is in [`docs/architecture/README.md`](docs/architecture/README.md), and the
Goose gaps found here are in [`docs/goose-findings.md`](docs/goose-findings.md).

## Status

🟢 works · 🟡 partial or next · 🔴 not yet

| | Part | Notes |
|---|---|---|
| 🟢 | Package | `rest.goose` imports goose-http at its pin; `scripts/test.sh` runs everything (task 001) |
| 🟢 | Language checks | Spikes 01–05 pass on `a6249a4`, three with workarounds the design takes |
| 🟢 | Spikes 06–07 | Resuming a waiting route, and the `format` hook from `rest`, pass on `a6249a4` (task 002) |
| 🟢 | Generator | Types, readers, and writers from OpenAPI's schemas, no `pattern` yet ([reference](docs/generator.md), task 003) |
| 🔴 | Runtime | Context, routes, errors, extractors, middleware (tasks 004–006) |
| 🟡 | Generated router | Measured: the if chain costs about 6,000 instructions a request deep in 60 routes; task 008 proposed (task 007) |
| 🔴 | Waiting on another thread | Task 009 |
| 🔴 | Benchmark | Against goose-http alone, Axum, actix-web, and dusty (task 010) |

## Layout

```text
rest.goose     the package's entry, namespace rest
check.goose    the checks generated readers call: code points, string formats
gen/           goose-rest gen, the generator (gen/main.goose)
test/          unit tests, test_*.goose, each a root file; test/gen/ golden files
scripts/       test.sh runs every test; test-unit.sh the unit tests alone
bench/         measurements: routes.sh counts the if chain's instructions (task 007)
spikes/        language checks the design relies on, one folder each with a README
docs/          architecture, generator reference, development setup, Goose findings
tasks/         task tracking (tasks/README.md)
```

## Use

A program declares both packages in its root file, goose-http at the pin below and
goose-rest at a pushed commit, each by its full hash:

```goose
import http from "github.com/kaitk/goose-http@cfb9c02bd8cd1d841eaf9d140ff0dbd96bb3bcf8";
import rest from "github.com/kaitk/goose-rest@<40-hex commit>";
```

Build it with `goose build`: a server reaches `thread_spawn`, which `goose run` (TinyCC)
can't run.

## Pins

| What | Pin | Why |
|---|---|---|
| Goose compiler | `aardappel/goose` `a6249a4` (`master`, 2026-10-13) | The language and stdlib change often |
| goose-http | `kaitk/goose-http` `cfb9c02` (`main`, 2026-10-13) | Its API is still changing (its task 027) |

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
