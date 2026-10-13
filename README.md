# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http): Actix's model, changed where Goose
differs, at no cost over a hand-written router wherever the language allows. Routes are
code, middleware is an inlined block, extractors are chosen by type, and errors return
straight to the route. An optional generator writes types, JSON readers and writers,
and a router from an OpenAPI document. Proof of concept; the name is provisional.

The design is in [`docs/architecture/README.md`](docs/architecture/README.md), and the
Goose gaps found here are in [`docs/goose-findings.md`](docs/goose-findings.md).

## Status

🟢 works · 🟡 partial or next · 🔴 not yet

| | Part | Notes |
|---|---|---|
| 🟢 | Language checks | Spikes 01–05 pass on `a6249a4`, three with workarounds the design takes |
| 🟡 | Spikes 06–07 | Resuming a waiting route, and the `format` hook from `rest` (task 002) |
| 🔴 | Generator | Types, readers, and writers from OpenAPI (task 003) |
| 🔴 | Runtime | Context, routes, errors, extractors, middleware (tasks 004–006) |
| 🔴 | Generated router | If measurement justifies it (tasks 007, 008) |
| 🔴 | Waiting on another thread | Task 009 |
| 🔴 | Benchmark | Against goose-http alone, Axum, actix-web, and dusty (task 010) |

## Layout

```text
spikes/        language checks the design relies on, one folder each with a README
docs/          architecture, development setup, Goose findings
tasks/         task tracking (tasks/README.md)
```

## Pins

| What | Pin | Why |
|---|---|---|
| Goose compiler | `aardappel/goose` `a6249a4` (`master`, 2026-10-13) | The language and stdlib change often |
| goose-http | `kaitk/goose-http` `04791ac` (`main`, 2026-10-13) | Its API is still changing (its task 027) |

Move each pin in its own commit, with the spikes and tests rerun
([development.md](docs/development.md#move-the-pin)).
