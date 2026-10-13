# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http): Actix's model, changed where Goose
differs, at no cost over a hand-written router wherever the language allows. Routes are
code, middleware is an inlined block, extractors are chosen by type, and errors return
straight to the route. An optional generator writes types, JSON readers and writers,
and a router from an OpenAPI document.

Experimental: a proof of concept with a first runtime core and no stable API, and the
name is provisional. Nothing here is stable enough to build on.

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
| 🟢 | Runtime core | `Cx`, `serve`, `route`, `fail`, `json`, `text`, `otherwise`, one error shape ([below](#errors), task 004) |
| 🔴 | Extractors, middleware | Tasks 005–006 |
| 🟡 | Generated router | Next: the if chain costs about 6,000 instructions a request deep in 60 routes (tasks 007, 008) |
| 🔴 | Waiting on another thread | Task 009 |
| 🔴 | Benchmark | Against goose-http alone, Axum, actix-web, and dusty (task 010) |

## Layout

```text
rest.goose     the package's entry, namespace rest
runtime.goose  Cx, serve, route, fail, json, text, otherwise, and the error shape
check.goose    what generated code calls: code points, string formats, numbers
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

A worker serves with `rest::serve`, which calls its block with a `rest::Cx` for each
request whose body has come whole. A route runs inside `rest::route`, so that `rest::fail`
answers from any depth below it:

```goose
thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx =>
        var r = http::router(cx.req);
        if http::on(r, "GET", "/projects/:id") {
            rest::route(cx) {
                let id, ok = parse_int(http::param(r, "id"));
                guard ok else { rest::fail(cx, 400, "bad_id"); }
                rest::json(cx, 200, find_project(cx, id));   // fails 404 itself
            };
        } else {
            rest::otherwise(cx, r);           // 404, or 405 with Allow
        }
    };
    if e.code != 0 { http::report(e); }
}
```

`rest::serve(cfg, fresh)` keeps per-request state as well: `cx.state` starts from `fresh`
for each request. `rest::json` writes a value through its type's `format` overload, which
the generator writes for each schema.

## Errors

Every error goose-rest answers is JSON with one member, `error`, a code in snake_case:

```json
{"error":"project_not_found"}
```

| Status | Code | From |
|---|---|---|
| any | the code given | `rest::fail(cx, status, code)` |
| 400 | `invalid_body`, with `detail` and `at` | `rest::fail_body(cx, r)`, for a body a JSON reader refused |
| 400 | `bad_path` | `rest::otherwise`: a path with a dot-segment or an escaped control byte |
| 404 | `not_found` | `rest::otherwise`: no route's path matched |
| 405 | `method_not_allowed`, with an `Allow` field | `rest::otherwise`: a route's path matched with another method |
| 501 | `not_implemented` | `rest::otherwise`: a method HTTP doesn't define |

A body a generated reader refuses names the field and the check that failed, and where
in the body the reader stopped, counted in bytes:

```json
{"error":"invalid_body","detail":"name: maxLength","at":31}
```

`detail` is one of the reader's messages: `<field>: required`, `<field>: <keyword>` for a
schema keyword such as `minLength`, `maximum`, or `enum`, `<field>: not UTF-8`, `unknown
member`, or a syntax error from `json`, such as `expected a string`.

The first answer wins: a route that answers and then fails keeps its answer.

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
