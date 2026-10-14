# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), on
[goose-http](https://github.com/kaitk/goose-http): Actix's model, changed where Goose
differs, at no cost over a hand-written router wherever the language allows. Routes are
code, middleware is an inlined block, extractors are chosen by type, and errors return
straight to the route. An optional generator writes types, JSON readers and writers,
and a router from an OpenAPI document.

Experimental: a proof of concept with a first runtime core and no stable API, and the
name is provisional. Nothing here is stable enough to build on.

The design is in [`docs/architecture/README.md`](docs/architecture/README.md), the
middleware, extractors, and errors in [`docs/reference.md`](docs/reference.md), and the
Goose gaps found here in [`docs/goose-findings.md`](docs/goose-findings.md).

## Status

🟢 works · 🟡 partial or next · 🔴 not yet

| | Part | Notes |
|---|---|---|
| 🟢 | Package | `rest.goose` imports goose-http at its pin; `scripts/test.sh` runs everything |
| 🟢 | Runtime core | `Cx`, `serve`, `route`, `fail`, `json`, `text`, `otherwise`, one error shape a program can replace ([reference](docs/reference.md#errors)) |
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
bench/            measurements: routes.sh counts the if chain's instructions (task 007);
                  rest.sh runs the REST benchmark against goose-http and three frameworks (task 010)
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

## On a board

A program cross-builds for an embedded Linux board as goose-http's does, with
`goose build --cc` and the board's C cross compiler: goose-http's
[docs/embedded.md](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers distribution cross compilers, Yocto SDKs, what the board needs, and the checks
to run on it. `scripts/test-aarch64.sh` cross-builds every example for aarch64 and runs
their checks in an arm64 container, printing each one's peak RSS
([development.md](docs/development.md#run-the-examples-on-arm64)). There,
`examples/device` peaked at 4,728 kB on one worker (task 013). None has run on a board
yet.

## Pins

| What | Pin | Why |
|---|---|---|
| Goose compiler | `aardappel/goose` `46356c2` (`master`, 2026-10-14) | The language and stdlib change often |
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
