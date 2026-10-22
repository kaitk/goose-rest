# rest-actix-web

actix-web serving goose-http's REST tiers A to D and Plod's tiers F, R, and M
(`bench/rest/tiers`), for Plod's REST benchmark ([docs/benchmarks.md](../../../docs/benchmarks.md),
[bench/README.md](../../README.md)). Each route is registered on actix-web's
`App`, scopes, and resources, reads its input with actix-web's extractors, and answers
its errors through actix-web's hooks. The records, the serde types, both JSON ways, and
tier D's readers come from `bench/rest/rust-app`, a port of goose-http's
`bench/rest/rust` without its routing.

```sh
RUSTFLAGS="-C target-cpu=native" cargo build --release --locked \
    --target-dir ~/.cache/goose-rest-bench/target-actix-web
REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> \
    [ROUTES=bench/rest/tiers/github.txt] rest-actix-web <port>
```

Keep the target directory outside the repository; only the sources and `Cargo.lock` are
committed.

## Configuration

The configuration follows TechEmpower's actix entry at FrameworkBenchmarks
`57d92fbec6f8fd7431bc77326dd0484e60c96e20` (master on 2026-03-23; the entry's last change
is `1e047d8`), read on 2026-10-13: `frameworks/Rust/actix/Cargo.toml`,
`actix.dockerfile`, and `src/main_web.rs`, the `tfb-web` binary of its default test
("Actix Web"). Taken from it:

- `#[actix_web::main]`, and `actix_server::Server::build()` with a backlog of 1,024,
  binding one `HttpService` factory. actix-server runs one worker thread per worker, each
  a single-threaded runtime. The entry leaves the worker count at actix-server's default,
  one per available CPU; this server sets `.workers(WORKERS)`.
- `HttpService::build().keep_alive(KeepAlive::Os).client_request_timeout(Duration::ZERO)`,
  HTTP/1 only (`.h1(map_config(app, |_| AppConfig::default())).tcp()`).
- A `Server: A` field, which the entry sets in each handler; here `extract::reply` sets
  it on every answer the routes build.
- Allocator: snmalloc (`snmalloc-rs`) as the global allocator.
- actix-web with its default features; edition 2024.
- Release profile: `lto = true` (fat), `opt-level = 3`, `codegen-units = 1`. This
  server adds `panic = "abort"`, which the entry doesn't set, to share one profile with
  the other Rust servers ([bench/README.md](../../README.md#servers)).
- `RUSTFLAGS="-C target-cpu=native"`, from its Dockerfile.

HttpArena's actix entry (MDA2AV/HttpArena `36582d1`, read on 2026-10-17; the entry's last
change is `a232b94`) runs `HttpServer` in its default configuration, with thin LTO,
rustls, and the compression middleware, and without a global allocator, so it isn't the
faster configuration to follow. Its `panic = "abort"` is the one setting it has that
TechEmpower's entry lacks.

Versions are current where the entry's are older: actix-web 4.16.0 (entry 4.9.0),
actix-http 3.18.13 (3.9.0), actix-server 2.10.0 (2.2.0), actix-rt 2.15.0 (2.10.0), and
snmalloc-rs 0.7.6 (0.3.8). tokio is pinned at 1.53.2, goose-http's `bench/rest/hyper` pin.
The routes add actix-multipart 0.8.5, actix-cors 0.7.2, futures-util, and serde_json's
`preserve_order`.

## Routes

Each tier has a module with a `routes()` function taking a `ServiceConfig`. `main.rs`
configures the `App` by `TIER`, with a `default_service` answering 404 for paths no
route takes.

- Tier A (`arena.rs`): `web::Path<usize>`, whose `PathConfig` error handler answers 404,
  and `web::Json<Write>` as a `Result`, so a body that isn't a `Write` is a 422 after the
  id is looked up. `X-User-Id` comes from `HttpRequest::headers`. Each resource's
  `default_service` answers a missing method with 404.
- Tier B (`snow.rs`): the scope `/api/v1`, whose `default_service` and resources'
  `default_service` answer snowtime's 404. `SameOrigin` (Origin) and `Signed` (the
  session cookie, through `HttpRequest::cookie`) are `FromRequest` extractors,
  `Option<Signed>` through actix-web's `Option<T>`. Membership, `web::Query` as a
  `Result`, and the body (`web::Bytes`) follow in the handler, in snowtime's order.
- Tier C (`heavy.rs`): the scope `/api/v2`, with the bearer check as
  `middleware::from_fn` on each route (`Route::wrap`), so an unknown path or method is a
  404 before it. The scope's `PathConfig` and `QueryConfig` error handlers answer 404 and
  400; `/clients/{id}/encounters` takes its query as a `Result`, to look the client up
  first.
- Tier D (`writes.rs`): the scope `/api/v3`, with the same middleware. A
  `ContentType<M>` extractor answers 415 before the body is read.
- Tier F (`framework.rs`): `GET /` returns `"Hi"`, `GET /id/{id}` takes `web::Path` and
  `web::Query` and adds `x-powered-by` with `Responder::customize`, and `POST /json`
  echoes `web::Json<serde_json::Value>`.
- Tier R (`framework.rs`): each line of `ROUTES` as a route on a resource
  (`web::method`), the handler a closure holding the line number and reading
  `req.match_info()` in order. actix-web takes the first resource whose pattern matches,
  so a path's lines share one resource, in the file's order of first appearance.
- Tier M (`framework.rs`): tier A's routes and its 404 in a scope over every path
  (`web::scope("")`), wrapped, outermost first, by Server-Timing (`middleware::from_fn`),
  actix-cors's `Cors`, and the bearer check (`middleware::from_fn`). A scope keeps the
  `App`'s type the same for every tier, where `App::wrap` would change it.

How tier D reads each body:

| Route | Reads | Limit |
|---|---|---|
| `POST /api/v3/imports` | streamed: `web::Payload`, each chunk into the CSV reader | 16 MB, by hand |
| `POST /api/v3/attachments` | streamed: `web::Payload` through actix-multipart's `Multipart`, each field's chunks as they come | 16 MB, by hand |
| `POST /api/v3/bookings/batch` | buffered: `web::Bytes` | 1 MB, the resource's `PayloadConfig` |
| `POST /api/v3/forms` | buffered: `web::Bytes` | 64 KB, the resource's `PayloadConfig` |

`PayloadConfig` limits only the buffering extractors, and actix-multipart's
`MultipartConfig` only its in-memory buffer. The streamed routes refuse a declared
`Content-Length` over the limit before reading, and count what they read; the attachment
route counts the payload on its way into `Multipart`.

An answer given before a body's end leaves the rest to actix-http, which drains a
chunked body whose reader is dropped and closes the connection after a sized one,
sending `Connection: close`. The routes don't drain bodies themselves.

## Differences from goose-http's Rust routes

- **Tier M's preflight is 200, where `bench/rest/tiers/check.py` wants 204.** actix-cors
  answers a preflight with `HttpResponse::Ok()` and has no setting for its status.
  `check.py m` fails on that line alone; with 200 accepted, the rest of tier M passes.
  Changing the status would take a middleware that rewrites `Cors`'s answer, which isn't
  done. The preflight also lacks `Server: A`, which the routes add.
- `web::Query` refuses a repeated key with a 400 (serde_urlencoded's duplicate field),
  where goose-http's routes take the first value. It decodes `+` as a space and keeps a
  malformed percent-escape as it is; goose-http's tier C decodes only `staff`, without
  `+`, and refuses a malformed escape. `check.py` sends none of these.
- Tier A's `web::Json` requires `Content-Type: application/json`, accepts whitespace
  before the object, and has `JsonConfig`'s default limit; goose-http's tier A takes any
  type, refuses the whitespace, and has no limit. `check.py` and `tier-a.lua` send the
  type and no whitespace.
- Tier B's bodies are within `PayloadConfig`'s default 256 KB limit; goose-http's tier B
  has none.
- The session cookie's value comes from `HttpRequest::cookie` (the `cookie` crate
  0.16), which keeps surrounding double quotes; goose-http's tier B strips them.
  `check.py` sends none.
- GET routes take HEAD through a guard (`extract::get`), as goose-http's routes do;
  `web::get()` alone doesn't match HEAD.
- Tier C checks the token's shape only (three base64url segments), as goose-http's
  `bench/rest/rust` and `bench/rest/hyper` do, not against the dataset's tokens.
- Tier R answers a method a registered path lacks with 405, actix-web's default, and an
  unknown path with 404.

## Verified (2026-10-13)

On macOS (Darwin 25.3.0, rustc 1.99.0), `WORKERS=2`, port 29481, against
goose-http `e27ab21`'s datasets in `build/rest`, tiers A to D three times each:

| `check.py` | serialize | template |
|---|---|---|
| goose-http tier a | pass | pass |
| goose-http tier b | pass | pass |
| goose-http tier c | pass | pass |
| goose-http tier d | pass | pass |
| goose-http tier c against `TIER=d` | pass | not run |
| goose-rest tier f | pass | |
| goose-rest tier r | pass | |
| goose-rest tier m | fails at the preflight status only | |

A 3 s wrk run of each tier's script (tiers A to C at `-t2 -c16`; tier D's roles at
`-t1 -c2` and `-t2 -c14` at once; tier F's three routes, R, and M at `-t2 -c16`)
counted no socket error and no status but 200, 201, 204, and tier D's 422s. These were
smoke tests on a machine that isn't a benchmark platform, not measurements.
