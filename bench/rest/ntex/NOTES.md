# rest-ntex

ntex serving goose-http's REST tiers A to D and Plod's tiers F, R, and M
(`bench/rest/tiers`), for Plod's REST benchmark ([docs/benchmarks.md](../../../docs/benchmarks.md),
[bench/README.md](../../README.md)). Each route is registered on ntex's `App`, scopes,
and resources, reads its input with ntex's extractors, and answers its errors through
ntex's error domain. The records, the serde types, both JSON ways, and tier D's readers
come from `bench/rest/rust-app`, a port of goose-http's `bench/rest/rust` without its
routing.

```sh
RUSTFLAGS="-C target-cpu=native" cargo build --release --locked \
    --target-dir ~/.cache/goose-rest-bench/target-ntex
REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> \
    [ROUTES=bench/rest/tiers/github.txt] rest-ntex <port>
```

Keep the target directory outside the repository; only the sources and `Cargo.lock` are
committed.

## Runtime

ntex 4.3.0 on its native runtime, which has no Tokio underneath. Each worker is a
single-threaded runtime with its own reactor:

- On Linux, the `neon-uring` feature, set in `Cargo.toml` for `target_os = "linux"`
  only, holds the reactor to io_uring. Without it, ntex tries io_uring and falls back to
  polling without saying so; with it, a server that can't set up io_uring stops at
  startup instead of measuring epoll.
- On macOS and other platforms, the same build uses ntex's polling reactor (kqueue on
  macOS), which is enough to check the answers.

Tokio and compio are ntex's other runtime features, and neither is enabled.

## Configuration

The configuration follows TechEmpower's ntex entry at FrameworkBenchmarks
`57d92fbec6f8fd7431bc77326dd0484e60c96e20` (master on 2026-03-23; the entry's last change
is `4607de8`), read on 2026-10-16: `frameworks/Rust/ntex/Cargo.toml`,
`benchmark_config.json`, `ntex.dockerfile`, `ntex-neon-uring.dockerfile`, `src/main.rs`,
and `src/utils.rs`. The entry runs ntex 3.4 in four variants: `tokio` (the default test),
`neon` (polling), `neon-uring`, and `compio`. This server takes the `neon-uring`
variant's runtime, at ntex 4, where the native runtime is the default. Taken from the
entry:

- `#[ntex::main]`, and `ntex::server::build()` with a backlog of 1,024 and
  `enable_affinity()`, which pins each worker to one of the CPUs the process may run on.
  The entry leaves the worker count at ntex's default, one per CPU; this server sets
  `.workers(WORKERS)`. `AFFINITY=0` leaves the workers unpinned, as the other servers
  run.
- `HttpService::h1` over the `App`, with `HttpServiceConfig`'s keep-alive set to
  `KeepAlive::Os`, no client timeout, and no header or payload read rates.
- A `Server: N` field, which the entry sets in each handler; here `extract::reply` sets
  it on every answer the routes build.
- Allocator: mimalloc as the global allocator, without its default features.
- ntex-bytes with its `simd` feature.
- Release profile: `opt-level = 3`, `codegen-units = 1`, and `panic = "abort"`. The
  entry's `lto = "thin"` is fat LTO here, to share one profile with the other Rust
  servers ([bench/README.md](../../README.md#servers)); its `debug = false`,
  `incremental = false`, and `overflow-checks = false` are a release build's defaults.
- `RUSTFLAGS="-C target-cpu=native"`, from its Dockerfiles.

Not taken: the entry's `IoConfig` read and write buffer sizes. ntex 4 replaced those
settings with buffer page sizes, so the server keeps `IoConfig`'s defaults (reads in 4 to
64 KiB pages, 16 KiB write pages).

HttpArena's ntex entry (MDA2AV/HttpArena `8977be2`, read on 2026-10-16; the entry's last
change is `f6cacd2`) runs ntex 2 on Tokio through `web::HttpServer` with a request logger
and without `target-cpu=native` or LTO, so it isn't the faster configuration to follow.

Versions are current where the entry's are older: ntex 4.3.0 (entry 3.4.0), ntex-bytes
1.12.0 (1.5), mimalloc 0.1.52 (0.1.25), and edition 2024 (2018). The routes add ntex's
`cookie` feature, ntex-cors 4.1.1, ntex-multipart 4.1.0, futures-util, and serde_json's
`preserve_order`.

## Routes

Each tier has a module with a `routes()` function taking a `ServiceConfig`. `main.rs`
configures the `App` by `TIER`, with a `default_service` answering 404 for paths no
route takes. The `App`'s state, `Bench`, holds the tier, and its error domain, `Answers`,
renders each extractor's error as that tier answers it.

- Tier A (`arena.rs`): `Path<usize>`, whose error the domain answers 404, and
  `Json<Write>` as a `Result`, so a body that isn't a `Write` is a 422 after the id is
  looked up. `X-User-Id` comes from `HttpRequest::headers`. Each resource's
  `default_service` answers a missing method with 404.
- Tier B (`snow.rs`): the scope `/api/v1`, whose `default_service` and resources'
  `default_service` answer snowtime's 404. `SameOrigin` (Origin) and `Signed` (the
  session cookie, through `HttpRequest::cookie`) are `FromRequest` extractors,
  `Option<Signed>` through ntex's `Option<T>`. Membership, `Query` as a `Result`, and
  the body (`Bytes`) follow in the handler, in snowtime's order.
- Tier C (`heavy.rs`): the scope `/api/v2`. Each resource takes GET and HEAD by a
  resource guard and has the bearer check as resource middleware, so an unknown path or
  method falls to the scope's 404 before it. The domain answers `Path` and `Query`
  errors 404 and 400; `/clients/{id}/encounters` takes its query as a `Result`, to look
  the client up first.
- Tier D (`writes.rs`): the scope `/api/v3`, with POST guards and the same middleware. A
  `ContentType<M>` extractor answers 415 before the body is read.
- Tier F (`framework.rs`): `GET /` returns `"Hi"`, `GET /id/{id}` takes `Path` and
  `Query` and adds `x-powered-by` with `Responder::with_header`, and `POST /json` echoes
  `Json<serde_json::Value>`.
- Tier R (`framework.rs`): each line of `ROUTES` as a route on a resource
  (`web::method`), the handler a closure holding the line number and reading
  `req.match_info()` in order. ntex takes the first resource whose pattern matches, so a
  path's lines share one resource, in the file's order of first appearance.
- Tier M (`main.rs`, `framework.rs`): tier A's routes and the 404 behind the `App`'s
  middleware, outermost first: Server-Timing (`Timing`), ntex-cors's `Cors`, and the
  bearer check. `App::middleware` changes the `App`'s type, so `main.rs` serves tier M's
  `App` apart from the other tiers'. ntex has no scope over every path: `scope("")`
  matches only `/`.

Each middleware is a `Middleware` and `Service` pair, as ntex's documentation writes
them; ntex has no middleware built from a function.

How tier D reads each body:

| Route | Reads | Limit |
|---|---|---|
| `POST /api/v3/imports` | streamed: `web::types::Payload`, each chunk into the CSV reader | 16 MB, by hand |
| `POST /api/v3/attachments` | streamed: the payload through ntex-multipart's `Multipart`, each field's chunks as they come | 16 MB, by hand |
| `POST /api/v3/bookings/batch` | buffered: `Limited<1 MB>` | 1 MB |
| `POST /api/v3/forms` | buffered: `Limited<64 KB>` | 64 KB |

`Limited<N>` is a `FromRequest` extractor that refuses a declared `Content-Length` over
`N` before reading, and counts what it reads. ntex's `PayloadConfig` is one limit for the
whole application, read from `WebAppConfig`, and tier D's routes need two. The streamed
routes refuse a declared length over the limit before reading, and count what they read;
the attachment route counts the payload on its way into `Multipart`.

## Differences from goose-http's Rust routes

- **Tier D's scope reads what an answer leaves of a body** (`extract::Drain`, scope
  middleware), unless the answer is a 413 or closes the connection. ntex closes a
  connection whose payload wasn't read to its end, with `Connection: close`, but the
  bytes still arriving turn the close into a reset, which the client can see before it
  reads the answer. `check.py d` failed this way after an attachment whose chunked end
  the multipart parser never read. The drain costs a shared payload and a `RefCell`
  borrow per chunk on tier D's routes. Tiers A and B buffer their small bodies whole,
  and their early refusals pass `check.py`.
- **ntex-multipart 4.1.0 drops a close delimiter that arrives in small pieces.** Its
  field reader takes a buffer of exactly `\r\n--` for field data, so the boundary after
  it goes unseen; actix-multipart checks the same buffer for a boundary. `check.py d`
  failed now and then on attachments sent in chunks of 1 to 999 bytes. The attachment
  route feeds `Multipart` through `Delimited`, which holds a piece's tail back from its
  last `\r` until a whole delimiter can follow.
- ntex's HTTP layer refuses a request target with a malformed percent-escape (`%zz`)
  with a bare 400 before routing, where actix-web routes it and tier C answers its own
  400.
- ntex-cors refuses a request with an Origin it doesn't allow with a 400, where
  actix-cors and tower-http pass it through without CORS fields. It also takes every
  OPTIONS request for a preflight, so an OPTIONS without an Origin is a 400. Its
  preflight is 200, which `check.py m` accepts. `tier-m.lua` sends only the allowed
  Origin.
- The error domain answers tier F's refused query or body with an empty 400 (413 for
  JSON over its limit), where actix-web's default answers with the error's text.
- `Query` refuses a repeated key with a 400 (serde_urlencoded's duplicate field), where
  goose-http's routes take the first value. `Query` decodes `+` as a space; goose-http's
  tier C decodes only `staff`, without `+`. `check.py` sends none of these.
- Tier A's `Json` requires `Content-Type: application/json` and accepts whitespace before
  the object; goose-http's tier A takes any type and refuses the whitespace. `check.py`
  and `tier-a.lua` send the type and no whitespace.
- Tier B's bodies are within the `Bytes` extractor's default 256 KB limit; goose-http's
  tier B has none.
- GET routes take HEAD through a guard (`extract::get`), as goose-http's routes do.
- Tier C checks the token's shape only (three base64url segments), as goose-http's
  `bench/rest/rust` and `bench/rest/hyper` do, not against the dataset's tokens.
- Tier R answers a method a registered path lacks with 405, ntex's default, and an
  unknown path with 404.

## Verified (2026-10-16)

On macOS (Darwin 25.3.0, rustc 1.99.0), on the polling reactor, `WORKERS=2`, port 29481,
against the datasets in goose-http's `build/rest` (generated 2026-10-13), every tier
three times:

| Check | serialize | template |
|---|---|---|
| goose-http `check.py`, tiers a to c | pass | pass |
| goose-http `check.py`, tier d | pass | |
| goose-http tier c against `TIER=d`, once | pass | pass |
| goose-rest `tiers/check.py`, tiers f, r, and m | pass | |

The same requests at the edges (unknown paths and methods, bad ids, queries, and bodies,
missing tokens, media types, declared lengths over a limit, preflights) got the same
statuses and bodies from `rest-ntex` and `rest-actix-web`, apart from the differences
above.

In an arm64 `rust:1.99-trixie` container on Docker Desktop (kernel 7.0.14-linuxkit),
with `--security-opt seccomp=unconfined`, the `--locked` build with `neon-uring` passed
every tier of both checkers once. Docker's default seccomp profile blocks
`io_uring_setup`, which this build refuses to run without.

A 3 s wrk run of each tier's script (tiers A to C at `-t2 -c16`; tier D's roles at
`-t1 -c2` and `-t2 -c14` at once; tier F's three routes, R, and M at `-t2 -c16`)
counted no socket error and no status but 2xx and tier D's 422s. These were smoke tests
on a machine that isn't a benchmark platform, not measurements.
