# goose-rest

A REST framework for [Goose](https://github.com/aardappel/goose), built on
[goose-http](https://github.com/kaitk/goose-http). It follows Actix's model, adapted to
Goose, with no overhead over a hand-written router wherever the language allows.
An optional generator writes types, JSON readers and writers, and a router from an
OpenAPI document.

The API is still taking shape. The tutorial and examples use the intended API, but
names and details may change between tags. Work is also underway to reduce the
remaining overhead over goose-http.

[Tutorial](docs/tutorial/README.md) · [Best practices](docs/best-practices/README.md) ·
[Reference](docs/reference.md) ·
[Generator](docs/generator.md) · [Benchmarks](docs/benchmarks.md) ·
[Architecture](docs/architecture.md) · [Development](docs/development.md) ·
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
| ⚪ | OpenAPI out | Generate a document from the routes. Planned. |
| 🟢 | Bodies in pieces | `rest::body_in_pieces` reads a body of any size as it arrives, up to a route's limit, or `rest::body` gathers it whole ([reference](docs/reference.md#later-calls)). |
| 🟡 | Static files, streaming | `rest::file` serves a file with ranges and conditional requests, and `rest::begin` sends a response in pieces as the client takes them ([reference](docs/reference.md#later-calls)). Events sent over time, such as Server-Sent Events, are not supported yet. |
| 🔴 | WebSocket | Currently out of scope, as in goose-http; `rest::upgrade` hands an upgraded connection's bytes to the route ([reference](docs/reference.md#later-calls)). |

### Middleware

| | Middleware | Notes |
|---|---|---|
| 🟢 | CORS | Preflight requests, allowed origins, and credentials. |
| 🟢 | Bearer tokens | 401 with `WWW-Authenticate`; passes the token to your verifier. |
| 🟢 | Server-Timing and access log | Combined middleware, or timing alone. |
| 🟢 | Your own | Any `inline fn` that takes a block ([reference](docs/reference.md#middleware)). |
| ⚪ | JWT | No built-in verifier; use your own with the bearer middleware. |
| ⚪ | Sessions | No session store yet; read cookies with `rest::cookie`. |
| 🟢 | Compression | gzip, deflate, and zstd according to `Accept-Encoding`, in an optional module, for answers written whole and responses sent in pieces; files go as they are ([reference](docs/reference.md#compression)). |
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
import http from "github.com/kaitk/goose-http@v0.3.4";
import rest from "github.com/kaitk/goose-rest@v0.1.1";

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
basics first, then bodies and responses of any size, work that waits, and limits. The examples are complete
programs to start from, each built and tested with HTTP requests:

| Example | What it shows |
|---|---|
| [`plain/`](examples/plain/main.goose) | Without a schema: routes, scopes, extractors, a JSON or form body, middleware, and a 4 MB upload alongside the 1 MB default |
| [`schema/`](examples/schema/) | From `api.json`: generated types and router, hand-written handlers, and a 2 MB route limit set with `x-body-limit` |
| [`compress/`](examples/compress/main.goose) | Answers compressed according to `Accept-Encoding`, with the optional `rest.compression` module: goose-http's defaults, an export compressed as it's sent in pieces, and a scope with its own compression levels and no zstd |
| [`upgrade/`](examples/upgrade/main.goose) | An upgraded connection with `rest::upgrade`: a 101, then the client's bytes echoed back until the server closes the connection, or the client closes it first |
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
- **Workers share nothing and never block**, as in
  [goose-http](https://github.com/kaitk/goose-http#concepts). I/O-bound work, such as a
  query to a database server, runs on a service thread: the route sends it a
  [message](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#mail-between-threads)
  and resumes when the reply arrives, the half-sync/half-async pattern
  ([tutorial](docs/tutorial/13-waiting.md), [why](docs/architecture.md#waiting-on-a-service)).

For differences from Actix and the reasons behind them, see the
[architecture](docs/architecture.md#actix-and-where-goose-rest-differs).

## Benchmarks

goose-rest `v0.1.0` and Goose `v2026.1` on a Ryzen 7 5800X3D (WSL2), 4 workers per
server. [All results, the method, and the losses](docs/benchmarks.md).

Every framework serves the same REST APIs through its own router, extractors, and
middleware.

- **A**, **B**, and **C** are HttpArena's items, a time tracker, and a clinic's records,
  with larger, more deeply nested JSON from A to C.
- **Templates** builds each record's JSON once at startup.
- **F**, **R**, and **M** measure the framework itself: one route, 203 routes, and A
  behind CORS, a bearer token, and `Server-Timing`.

| Workload | goose-rest | dusty (Zig) | actix-web | Axum |
|---|:---|---:|---:|---:|
| [A](docs/benchmarks.md#the-tiers): items, 0.2 KB | **584k req/s** (97%) | 339k | 260k | 244k |
| [B](docs/benchmarks.md#the-tiers): time entries, 0.3-13 KB | **312k req/s** (98%) | 160k | 142k | 135k |
| [C](docs/benchmarks.md#the-tiers): records, up to 728 KB | **61.3k req/s** (99%) | 24.0k | 31.3k | 34.3k |
| C, templates | **139k req/s** (96%) | 130k | 91.6k | 87.3k |
| [F](docs/benchmarks.md#the-tiers): one route | **508k req/s** (99%) | 361k | 269k | 250k |
| [R](docs/benchmarks.md#the-tiers): 203 routes | **447k req/s** | 355k | 143k | 245k |
| [M](docs/benchmarks.md#the-tiers): A with middleware | **494k req/s** | 321k | 218k | 180k |
| [Uploads](docs/benchmarks.md#uploads-and-memory): up to 8 MB | 1,090 req/s (99%) | **1,191** | 1,117 | 1,119 |
| [Peak RSS](docs/benchmarks.md#against-other-frameworks), the worst tier for each | **133 MB**, uploads beside forms | 781 MB, uploads beside forms | 388 MB, C templates | 587 MB, C templates |

*Note: percentages, such as (97%), are goose-rest's share of goose-http's rate with no
framework.*

Goose uses io_uring. Results for every server, both Goose event loops, and memory:
[docs/benchmarks.md](docs/benchmarks.md#against-other-frameworks).

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
([architecture](docs/architecture.md#the-generator)).
