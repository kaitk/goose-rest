# rest-axum

axum serving goose-http's REST tiers A to D and Plod's tiers F, R, and M
(`bench/rest/tiers`), for Plod's REST benchmark ([docs/benchmarks.md](../../../docs/benchmarks.md),
[bench/README.md](../../README.md)). Each route is registered on axum's `Router`,
reads its input with axum's extractors, and answers its errors through axum's hooks. The
records, the serde types, both JSON ways, and tier D's readers come from
`bench/rest/rust-app`, a port of goose-http's `bench/rest/rust` without its routing.

```sh
RUSTFLAGS="-C target-cpu=native" cargo build --release --locked \
    --target-dir ~/.cache/plod-bench/target-axum
REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> \
    [ROUTES=bench/rest/tiers/github.txt] rest-axum <port>
```

Keep the target directory outside the repository; only the sources and `Cargo.lock` are
committed.

## Configuration

The configuration follows TechEmpower's axum entry at FrameworkBenchmarks
`57d92fbec6f8fd7431bc77326dd0484e60c96e20` (master on 2026-03-23; the entry's last change
is `fc12542`), read on 2026-10-13: `frameworks/Rust/axum/Cargo.toml`, `axum.dockerfile`,
`src/main.rs`, and `src/server.rs`. Its default test (`/app/axum`) runs `serve_hyper`
under `start_tokio`. Taken from it:

- Runtime: one current-thread Tokio runtime per thread, each with its own listener. The
  entry starts `num_cpus::get()` threads; this server starts `WORKERS`.
- Listener: `socket2` with `SO_REUSEPORT`, `SO_REUSEADDR`, non-blocking, `TCP_NODELAY`,
  and a backlog of 4,096; `TCP_NODELAY` again on each accepted socket.
- Connections: `hyper_util::server::conn::auto::Builder` with `http1().pipeline_flush(true)`,
  the router called through `hyper::service::service_fn`.
- A `Server: Axum` field, from tower-http's `SetResponseHeaderLayer::overriding`.
- Allocator: mimalloc as the global allocator.
- axum with `default-features = false` and the features `json`, `query`, `http1`, and
  `tokio`; hyper with `server` and `http1`; hyper-util with `tokio`, `server-auto`, and
  `http1`; edition 2024.
- Release profile: `lto = "fat"`, `codegen-units = 1`, and `opt-level = 3`. This
  server adds `panic = "abort"`, which the entry doesn't set, to share one profile with
  the other Rust servers ([bench/README.md](../../README.md#servers)).
- `RUSTFLAGS="-C target-cpu=native"`, from its Dockerfile.

HttpArena's axum entry (MDA2AV/HttpArena `36582d1`, read on 2026-10-17; the entry's last
change is `1165835`) runs axum on the multi-threaded Tokio runtime in its default
configuration, with thin LTO and without `target-cpu=native` or a global allocator, so
it isn't the faster configuration to follow.

Versions are current where the entry's are older: axum 0.8.9 (entry 0.8.7), tower-http
0.7.1 (0.6.7), mimalloc 0.1.52 (0.1.48). tokio 1.53.2, hyper 1.12.0, and hyper-util
0.1.21 are goose-http's `bench/rest/hyper` pins. The routes add axum-extra 0.12.6
(`cookie`), tower-http's `limit` and `cors`, http-body-util, multer 3.1.0, and
serde_json's `preserve_order`.

## Routes

Each tier has a module with a `routes()` function. `main.rs` picks the routers by `TIER`
and adds the 404 for paths no router takes.

- Tier A (`arena.rs`): `Path<usize>` and `Json<Write>`, each as a `Result`, so an id
  that isn't a number is a 404 and a body that isn't a `Write` a 422 after the id is
  looked up. `X-User-Id` comes from a `FromRequestParts` extractor.
  `method_not_allowed_fallback` answers a missing method with 404.
- Tier B (`snow.rs`): a router nested at `/api/v1`, whose `fallback` and
  `method_not_allowed_fallback` answer snowtime's 404. `SameOrigin` (Origin) and
  `Signed` (the session cookie, through axum-extra's `CookieJar`) are
  `FromRequestParts` extractors, `Option<Signed>` through `OptionalFromRequestParts`.
  Membership, `Query`, and the body (`Bytes`) follow in the handler, in snowtime's order.
- Tier C (`heavy.rs`): nested at `/api/v2`, with the bearer check as
  `middleware::from_fn` on `route_layer`, so an unknown path or method is a 404 before
  it. `Path` and `Query` rejections answer 404 and 400 from the handler's `Result`.
- Tier D (`writes.rs`): nested at `/api/v3`, behind the same middleware. A
  `ContentType<M>` extractor answers 415 before the body is read. Each route has
  `DefaultBodyLimit::disable()` and tower-http's `RequestBodyLimitLayer`, the pair axum's
  `DefaultBodyLimit` documentation gives for a limit that also refuses a declared
  `Content-Length` before reading; `Limited` alone waits for the bytes.
- Tier F (`framework.rs`): `GET /` returns `"Hi"`, `GET /id/{id}` takes `Path<String>`
  and `Query`, and `POST /json` echoes `Json<serde_json::Value>`.
- Tier R (`framework.rs`): each line of `ROUTES` registered with `on(MethodFilter, ..)`,
  the handler a closure holding the line number and taking `Path<Vec<String>>`.
- Tier M (`framework.rs`): tier A's router and its 404 under `Router::layer`, outermost
  first: Server-Timing (`middleware::from_fn`), tower-http's `CorsLayer`, and the bearer
  check (`middleware::from_fn`).

How tier D reads each body:

| Route | Reads | Limit |
|---|---|---|
| `POST /api/v3/imports` | streamed: `Body::into_data_stream`, each frame into the CSV reader | 16 MB |
| `POST /api/v3/attachments` | streamed: `Body::into_data_stream` through multer, each part's chunks as they come | 16 MB |
| `POST /api/v3/bookings/batch` | buffered: `Bytes` | 1 MB |
| `POST /api/v3/forms` | buffered: `Bytes` | 64 KB |

## Differences from goose-http's Rust routes

- **Tier M's preflight is 200, where `bench/rest/tiers/check.py` wants 204.**
  tower-http's `CorsLayer` builds the preflight response with `Response::new`, and has no
  setting for its status. `check.py m` fails on that line alone; with 200 accepted, the
  rest of tier M passes. Changing the status would take a middleware that rewrites
  `CorsLayer`'s answer, which isn't done.
- The routes that take a body (tier A's POST, tier B's writes, and tier D) run under
  `extract::drain`, a `middleware::from_fn` that hands the handler the body's stream
  and, after the answer, reads what the handler left, unless the answer is a 413 or
  closes the connection. goose-http's Rust routes read the rest of a body the same way.
  Without it, hyper closes a kept-alive connection whose body wasn't read to its end
  when the answer went out, unless the rest had already arrived, and doesn't send
  `Connection: close`; the client's next request on it fails. `check.py b` and `d` failed
  this way on some runs: after tier B's 403s for a missing Origin, tier D's 401s and
  415s, and an attachment whose last chunk multer, stopping at the close delimiter,
  never read. The drain costs a shared stream and a lock per body frame on those routes.
  `route_layer` doesn't wrap the fallbacks, so tier D's 404s read the body themselves:
  without that, `check.py d` failed every run on Linux after `POST /api/v3/nothing`
  (2026-10-15).
- The attachment route feeds multer, the parser axum's `Multipart` extractor wraps, from
  `Body::into_data_stream`, rather than use `Multipart`; the answers are the same.
- `Query` refuses a repeated key with a 400 (serde_urlencoded's duplicate field), where
  goose-http's routes take the first value. `Query` decodes `+` as a space and keeps a
  malformed percent-escape as it is; goose-http's tier C decodes only `staff`, without
  `+`, and refuses a malformed escape. `Path` percent-decodes segments. `check.py` sends
  none of these.
- A declared `Content-Length` over a tier D route's limit is a 413 before the media
  type is checked (`RequestBodyLimitLayer` runs before the extractors), where goose-http's
  routes answer 415 first.
- Tier A's `Json` extractor requires `Content-Type: application/json` and accepts
  whitespace before the object; goose-http's tier A takes any type and refuses the
  whitespace. `check.py` and `tier-a.lua` send the type and no whitespace.
- Tier B's bodies are within axum's default 2 MB body limit; goose-http's tier B has none.
- `CookieJar` keeps the last of a repeated cookie name; goose-http's tier B takes the
  first.
- Tier C checks the token's shape only (three base64url segments), as goose-http's
  `bench/rest/rust` and `bench/rest/hyper` do, not against the dataset's tokens.
- Tier R answers a method a registered path lacks with 405, axum's default, and an
  unknown path with 404.
- Tier M's `Router::layer` wraps each route, so a preflight to a known path reaches
  `CorsLayer` through the route's method-not-allowed path, and its 200 carries
  `Allow: GET,HEAD,POST`.

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
smoke tests, not measurements: macOS doesn't spread connections across `SO_REUSEPORT`
listeners, so one runtime takes them all.

`SO_REUSEPORT` also lets a server that is still running share the port with the next
one, so a stale `rest-axum` answers part of the next run's requests. Make sure the
previous server has exited before starting another; a successful `bind` doesn't prove
it.
