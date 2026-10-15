# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), built on
[goose-http](https://github.com/kaitk/goose-http). It follows Actix's model, adapted to
Goose, with no overhead over a hand-written router wherever the language allows.
An optional generator writes types, JSON readers and writers, and a router from an
OpenAPI document.

The API is still taking shape. The tutorial and examples use the intended API, but
names and details may change between tags. Work is also underway to reduce the
remaining overhead over goose-http.

[Tutorial](docs/tutorial/README.md) · [Reference](docs/reference.md) ·
[Generator](docs/generator.md) · [Benchmarks](docs/benchmarks.md) ·
[Architecture](docs/architecture/README.md) · [Development](docs/development.md) ·
[Changelog](CHANGELOG.md)

*Note: goose-rest is a working name, and the repository may be renamed before a stable
release.*

## Status

goose-rest builds wherever goose-http does: Linux, macOS, and Windows. Its examples also
pass their tests on arm64 Linux.

🟢 works · 🟡 partial · ⚪ not yet · 🔴 out of scope

| | Feature | Notes |
|---|---|---|
| 🟢 | Routes | Path parameters, 404, 405 with `Allow`, and `OPTIONS`; guards are `if` conditions ([reference](docs/reference.md#context-and-routes)). |
| 🟢 | Scopes | Prefixes, each with its own middleware. |
| 🟢 | Extractors | Path, query, header, and cookie parameters, a JSON body, and custom types ([reference](docs/reference.md#extractors)). |
| 🟡 | Forms | URL-encoded form fields through `rest::form`, `rest::form_int`, and `rest::form_bool` ([reference](docs/reference.md#extractors)). Multipart forms have no extractor yet: read them with goose-http's `http::each_part`. |
| 🟢 | State | Worker state in `cx.app` and request state in `cx.state`. |
| 🟢 | Middleware | Blocks inlined into the handler; available middleware is listed [below](#middleware). |
| 🟢 | Errors | JSON with an error code and a customizable format ([reference](docs/reference.md#errors)). |
| 🟢 | Async work | Send work to another thread, resume with its reply, and skip work if the client disconnects ([tutorial](docs/tutorial/13-waiting.md)). |
| 🟢 | Testing | `rest::serve_one` handles raw request bytes without a socket ([reference](docs/reference.md#testing)). |
| 🟢 | OpenAPI in | Types, validating readers, writers, and a router from OpenAPI 3.1 in JSON or TypeScript ([generator](docs/generator.md)). |
| ⚪ | OpenAPI out | Generate a document from the routes, as Elysia's plugin does. Planned. |
| ⚪ | Bodies in pieces | A body is gathered whole, up to its limit; goose-http reads one [as it arrives](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies). |
| ⚪ | Static files, streaming | Not in goose-rest yet; goose-http [serves files and streams](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#long-responses). |
| 🔴 | WebSocket | Out of scope, as in goose-http. |

### Middleware

| | Middleware | Notes |
|---|---|---|
| 🟢 | CORS | Preflight requests, allowed origins, and credentials. |
| 🟢 | Bearer tokens | 401 with `WWW-Authenticate`; passes the token to your verifier. |
| 🟢 | Server-Timing and access log | Combined middleware, or timing alone. |
| 🟢 | Your own | Any `inline fn` that takes a block ([reference](docs/reference.md#middleware)). |
| ⚪ | JWT | No built-in verifier; use your own with the bearer middleware. |
| ⚪ | Sessions | No session store yet; read cookies with `rest::cookie`. |
| ⚪ | Compression | No middleware yet; goose-http compresses responses. |
| ⚪ | Rate limiting | No limiter yet; goose-http's per-connection limits and timeouts apply. |
| ⚪ | Default headers | No middleware yet; add headers to every response through `cx.out.common` ([goose-http](https://github.com/kaitk/goose-http/blob/main/docs/api.md#handler)). |

## Quick start

Install Goose [`v2026.1`](https://github.com/aardappel/goose/releases/tag/v2026.1): unpack
the archive for your platform and put its directory on `PATH`
([Goose's install notes](https://github.com/aardappel/goose#install-a-release)). Building
a program also needs a C compiler and, on Linux, liburing:

- **Linux:** gcc or clang, with `libc6-dev` and `liburing-dev` (Debian, Ubuntu).
- **macOS:** the Xcode command line tools (`xcode-select --install`).
- **Windows:** the Visual Studio 2022 or later Build Tools, with the C++ workload.

Save this as `hello.goose`:

```rust
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "github.com/kaitk/goose-rest@v0.0.1";

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/hello/:name") {
            rest::route(cx) { rest::text(cx, 200, str("Hello, ", rest::param(cx, "name"))); };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
    http::report(e);
}

fn main() {
    let cfg = http::Config { port: 8080, .. };
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
```

Build and run it, then open <http://localhost:8080/hello/goose>:

```sh
goose build hello.goose
./hello
```

*Note: a server with workers needs `goose build`: `goose hello.goose` runs through
TinyCC, which can't start threads.*

**With a schema**, describe the API in OpenAPI 3.1 using JSON or
[TypeScript](docs/generator.md#write-it-in-typescript), then
[generate its types and router](docs/generator.md#run-it). `api::dispatch(cx)` replaces
the routes and calls your handler for each operation with typed, validated parameters
and a validated body: [tutorial, page 5](docs/tutorial/05-schema.md).

The [tutorial](docs/tutorial/README.md) builds a projects API a page at a time: the
basics first, then large bodies, work that waits, and limits. The examples are complete
programs to start from, each built and tested with HTTP requests:

| Example | What it shows |
|---|---|
| [`plain/`](examples/plain/main.goose) | Without a schema: routes, scopes, extractors, a JSON or form body, middleware, and a 4 MB upload alongside the 1 MB default |
| [`schema/`](examples/schema/) | From `api.json`: generated types and router, hand-written handlers, and a 2 MB route limit set with `x-body-limit` |
| [`device/`](examples/device/) | A board's API: sysfs readings, bounded settings, a firmware upload, a bearer token, and CORS, on one worker |

## Concepts

```mermaid
flowchart LR
    R(["request"]) --> S["routes"] --> M["middleware"] --> H["handler"]
    H --> A(["answer"])
    H -. "fails" .-> E["error as JSON"] -.-> A
```

- **Routes are code.** Goose has no function values to store in a table, so a route is an
  `if` that matches a method and a path, and a generated router uses a `match`.
  Unmatched requests receive 404, 405, or an `OPTIONS` response
  ([routes](docs/reference.md#context-and-routes)).
- **One context.** Every call takes `cx`: the request, the response being written,
  worker state, and request state.
- **Middleware is a block** around the routes it applies to. It compiles into the
  handler, so a layer adds no function call ([middleware](docs/reference.md#middleware)).
- **Errors return to the route.** A failure anywhere within a route ends it with a JSON
  error in a customizable format ([errors](docs/reference.md#errors)).
- **Workers share nothing**, as in
  [goose-http](https://github.com/kaitk/goose-http#concepts). A route that needs another
  thread sends it a
  [message](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#mail-between-threads)
  and resumes when the reply arrives ([tutorial](docs/tutorial/13-waiting.md),
  [why](docs/architecture/README.md#waiting-on-another-thread)).

For differences from Actix and the reasons behind them, see the
[architecture](docs/architecture/README.md#actix-and-where-goose-rest-differs).

## Benchmarks

goose-rest `v0.0.1`, goose-http `v0.3.1`, and Goose `v2026.1` on a Ryzen 7 5800X3D
(WSL2), 4 workers per server, on the io_uring loop.
[Full results, methodology, and losses](docs/benchmarks.md).

Compared with goose-http's REST server, which serves the same routes without a framework:

| Workload | goose-rest | goose-http alone | |
|---|---:|---:|---|
| [A](docs/benchmarks.md#the-tiers): HttpArena's items, 0.2 KB | 585k req/s | 598k | 2.2% behind |
| [C](docs/benchmarks.md#the-tiers): records up to 728 KB | 53.4k req/s | 62.4k | 14% behind |
| C, templates | 142k req/s | 147k | 3.1% behind |
| [F](docs/benchmarks.md#tier-f): `GET /id/{id}?name=` | 504k req/s | 509k | 1.1% behind |
| [M](docs/benchmarks.md#tier-m): A + CORS, bearer, Server-Timing | 489k req/s | | 15% below A |
| [R](docs/benchmarks.md#tier-r): 203 routes, generated | 458k req/s | | 41% over an if chain |

Comparisons with Rust and Zig frameworks are not yet available. For the underlying
HTTP layer, see goose-http's
[REST API benchmarks](https://github.com/kaitk/goose-http#rest-apis)
against xitca-web, dusty, hyper, and tokio.

## Credits

The runtime draws three ideas from [actix-web](https://github.com/actix/actix-web):

- An `App` of scopes and routes.
- Extractors chosen by type.
- Middleware around a group of routes.

The generator draws three ideas from Elysia 2, the `kiana` branch of
[Elysia](https://github.com/elysiajs/elysia), reviewed at `c91f61f` (2026-10-11):

- One composed handler per route, with only the hooks it needs and the request parts it
  reads.
- Inline validators.
- A response writer that copies only declared fields.

Goose's compiler does at build time what Elysia generates at run time or in its AOT build
([architecture](docs/architecture/README.md#the-generator)).
