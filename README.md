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
| 🟢 | Package | `rest.goose` imports goose-http at its pin; `scripts/test.sh` runs everything |
| 🟢 | Runtime core | `Cx`, `serve`, `route`, `fail`, `json`, `text`, `otherwise`, one error shape ([below](#errors)) |
| 🟢 | Extractors | Path, query, header, and cookie parameters; `take<T>` for a JSON body or a program's own type; `once` ([below](#extractors)) |
| 🟢 | Middleware, scopes, examples | CORS, a bearer check, Server-Timing and the access log, prefix scopes ([below](#middleware)); a JSON API with and without a schema |
| 🟢 | Generator | Types, readers, writers, and extractors from OpenAPI's schemas, no `pattern` yet ([reference](docs/generator.md)) |
| 🟢 | Generated router | `dispatch` from the paths, with typed path, query, header, and cookie parameters, at one route's cost where the if chain pays 6,000 instructions deep in 60 routes ([reference](docs/generator.md#paths)) |
| 🟢 | Waiting on another thread | `rest::ask`, resuming through the program's `Waiting` enum, replies of any size in pieces (`waiting.goose`, `examples/waiting/`) |
| 🔴 | Benchmark | Against goose-http alone, Axum, actix-web, and dusty (task 010) |

## Layout

```text
rest.goose        the package's entry, namespace rest
runtime.goose     Cx, serve, route, fail, json, text, otherwise, and the error shape
extract.goose     the extractors: parameters, headers, cookies, take, once
middleware.goose  CORS, bearer, timed, and scope
waiting.goose     ask another thread, and resume with its reply
examples/         a JSON API without a schema and one with a schema
check.goose       what generated code calls: code points, string formats, numbers
gen/              goose-rest gen, the generator (gen/main.goose)
test/             unit tests, test_*.goose, each a root file; test/gen/ golden files
scripts/          test.sh runs every test; test-unit.sh the unit tests alone
bench/            measurements: routes.sh counts the if chain's instructions (task 007)
spikes/           language checks the design relies on, one folder each with a README
docs/             architecture, generator reference, development setup, Goose findings
tasks/            task tracking (tasks/README.md)
```

## Quick start

A program declares both packages in its root file, goose-http at the pin below and
goose-rest at a pushed commit, each by its full hash:

```goose
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "github.com/kaitk/goose-rest@<40-hex commit>";
```

Build it with `goose build`: a server reaches `thread_spawn`, which `goose run` (TinyCC)
can't run. Two examples serve a small projects API, and `scripts/test.sh` builds and
requests each:

| Example | What it shows |
|---|---|
| [`examples/plain/`](examples/plain/main.goose) | Without a schema: routes in an `http::router` chain under a scope, extractors, a hand-written body reader, and the middleware |
| [`examples/schema/`](examples/schema/) | From `api.json`: the generated types and router in `api_gen.goose`, and the handlers in `app.goose` |
| [`examples/waiting/`](examples/waiting/main.goose) | Routes that ask a database thread and resume when it replies, with replies larger than a mailbox message |

```sh
goose build -o build/examples/plain examples/plain/main.goose
build/examples/plain 8080
curl -s -H 'Authorization: Bearer secret' -H 'Content-Type: application/json' \
     -d '{"name": "goose"}' localhost:8080/v1/projects
```

A worker serves with `rest::serve`, which calls its block with a `rest::Cx` for each
request whose body has come whole. A route runs inside `rest::route`, so that `rest::fail`
answers from any depth below it. From `examples/plain/`:

```goose
fn handle(cx, app: App&) {
    rest::timed(cx) {                                  // Server-Timing and the access log
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            var r = http::router(cx.req);
            if http::on(r, "GET", "/health") {
                rest::text(cx, 200, "ok");
            } else if rest::scope(r, "/v1") {          // the rest of the path, under /v1
                rest::route(cx) { projects(cx, app, r); };
            } else {
                rest::otherwise(cx, r);                // 404, or 405 with Allow
            }
        };
    };
}

fn projects(cx, app: App&, r: http::Router&) {
    if http::on(r, "GET", "/projects/:id") {
        rest::json(cx, 200, find_project(cx, app, rest::param_int(cx, r, "id")));
    } else if http::on(r, "POST", "/projects") {
        rest::bearer(cx) { token =>                    // 401 without a bearer token
            guard token == app.token else { rest::invalid_token(cx); }
            let body = rest::take<ProjectCreate>(cx);  // 415, or 400 with the reader's error
            rest::json(cx, 201, app.projects.push(Project { id: app.projects.len + 1, name: body.name }));
        };
    } else {
        rest::otherwise(cx, r);
    }
}

thread_fn worker(cfg: http::Config) {
    var projects: Project[>..] = [];
    var app = App { projects: projects, token: "secret" };
    let e = rest::serve(cfg) { cx => handle(cx, app) };
    if e.code != 0 { http::report(e); }
}
```

`rest::serve(cfg, fresh)` keeps per-request state as well: `cx.state` starts from `fresh`
for each request. `rest::json` writes a value through its type's `format` overload, which
the generator writes for each schema. Workers share nothing, so state that every worker
must see lives on a thread of its own ([architecture](docs/architecture/README.md)).

## Middleware

Middleware is a block around the routes it applies to, inlined into the handler: a scope
can have its own, and a public route none.

| Call | Does |
|---|---|
| `rest::timed(cx) { ... }` | Adds `Server-Timing: app;dur=<ms>` to the answer, and writes an access log line to standard error: method, target, status, bytes, milliseconds. `rest::timed(cx, false)` skips the log. |
| `rest::cors(cx, rest::Cors { origins: "...", .. }) { ... }` | Adds the CORS fields to every answer inside, errors included, for an origin in `origins` (separated by spaces, or `*`). Answers a preflight with 204 itself, and an origin not listed with 403 `origin_not_allowed`. `methods`, `headers`, `expose`, `max_age`, and `credentials` set the rest. |
| `rest::bearer(cx) { token => ... }` | Fails 401 `unauthenticated` with `WWW-Authenticate: Bearer` without a bearer token; `rest::invalid_token(cx)` refuses one. `rest::bearer_token(cx)` returns it, for a generated router's security check. |
| `rest::scope(r, "/v1")` | Whether the path starts with the prefix at a segment boundary; the routes inside match the rest. `rest::otherwise` answers 404, 405, and OPTIONS across scopes. |

`timed` and `cors` go outside `rest::route`, so that the errors it answers get their
fields; `bearer` and anything else that fails goes inside it. A request has one route:
routes nested in routes don't inline ([architecture](docs/architecture/README.md#inlining)).
An answer written later, when a waiting route resumes, gets neither middleware's fields.

## Extractors

Each extractor reads one part of the request, and fails the route with 400 when that
part is malformed ([Errors](#errors)), so it runs inside `rest::route`. A value that
has escapes to decode is decoded into `cx.scratch`, which lasts until the handler
returns. Otherwise the extractor returns the request's own bytes.

| Call | Gives | Fails with `detail` |
|---|---|---|
| `rest::param(cx, r, "name")` | the path parameter, decoded | |
| `rest::param_int(cx, r, "id")` | the path parameter as an `i64` | `id: integer` |
| `rest::query(cx, "q")` | the query parameter, decoded with `+` as a space, and whether it's there | |
| `rest::query_int(cx, "page")`, `rest::query_bool(cx, "all")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `page: integer`, `all: boolean` |
| `rest::header(cx, "X-Request-Id")`, `rest::cookie(cx, "sid")` | the value, and whether it's there | |
| `rest::int_of(cx, v, "name")`, `rest::bool_of(cx, v, "name")` | `v` as an `i64` or a `bool` | `name: integer`, `name: boolean` |
| `rest::require(cx, "q", found)` | | `q: required` |
| `rest::take<T>(cx)` | a `T`, by `T`'s `from_request` overload | its own |

`rest::take<T>` reads any type with an overload declared in the `rest` namespace, as
`fn rest::from_request(cx, v: const app::Session?) -> app::Session`. `v` is always null,
and its type picks the overload. The generator writes one for each schema object, which
reads the JSON body: 415 unless the request says `application/json`, and 400
`invalid_body` for a body the reader refuses.

```goose
rest::route(cx) {
    let body = rest::take<api::ProjectCreate>(cx);
    let page, has_page = rest::query_int(cx, "page");
    rest::json(cx, 201, create_project(cx, body, if has_page { page } else { 1 }));
};
```

`rest::once(cx.state.profile) { load_profile(...) }` computes a value on its first call
in a request and returns it from then on. The slot is a `rest::Once<T>` field of the
per-request state, so each request starts it anew.

## Errors

Every error goose-rest answers is JSON with one member, `error`, a code in snake_case:

```json
{"error":"project_not_found"}
```

| Status | Code | From |
|---|---|---|
| any | the code given | `rest::fail(cx, status, code)` |
| 400 | `invalid_body`, with `detail` and `at` | `rest::fail_body(cx, r)`, for a body a JSON reader refused |
| 400 | `invalid_parameter`, with `detail` | the [extractors](#extractors), `rest::fail_param`, and the generated router: a parameter missing, malformed, or outside its schema, as `id: integer`, `q: required`, or `page: minimum` |
| 400 | `bad_path` | `rest::otherwise`: a path with a dot-segment or an escaped control byte |
| 401 | `unauthenticated`, with `WWW-Authenticate: Bearer` | `rest::bearer`: no bearer token |
| 401 | `invalid_token`, with `WWW-Authenticate: Bearer error="invalid_token"` | `rest::invalid_token(cx)` |
| 403 | `origin_not_allowed` | `rest::cors`: an `Origin` it doesn't list |
| 404 | `not_found` | `rest::otherwise`: no route's path matched |
| 405 | `method_not_allowed`, with an `Allow` field | `rest::otherwise`: a route's path matched with another method |
| 415 | `unsupported_media_type` | `rest::take` of a schema type: a JSON body sent as another media type |
| 501 | `not_implemented` | `rest::otherwise`: a method HTTP doesn't define |

The generated router answers 404, 405, 501, and `bad_path` as `rest::otherwise` does,
through `rest::no_route`, `rest::no_method`, and `rest::not_found`.

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
| goose-http | `kaitk/goose-http` `e27ab21` (`main`, 2026-10-13) | Its API is still changing (its task 027) |

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
