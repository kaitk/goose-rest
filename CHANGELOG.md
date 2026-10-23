# Changelog

What each tag adds. Each release names the Goose compiler it was built and tested with.
Plod was named goose-rest up to `v0.3.4`; the entries before `v0.4.0` keep that name.

## Unreleased

Changed:

- `plod::cors` with `origins: "*"` answers `Access-Control-Allow-Origin: *` and never
  sends `Access-Control-Allow-Credentials`, even with `credentials: true`; it used to
  echo any origin with credentials, which let any website read a signed-in user's
  answers. A program that sends credentials lists its origins
  ([reference](docs/reference.md)).

Added:

- An upgraded route, a WebSocket's among them, gets goose-http's `http::DRAINED` after
  it calls `http::after_drain(cx.out)`, so a publisher sends its next batch once the
  last has reached the socket ([WebSocket](docs/reference.md#43-websocket)).
- `plod::files` serves a directory under a `*name` route: a directory's `index.html`,
  `.br`, `.zst`, and `.gz` copies by `Accept-Encoding`, and 404 for a name that would
  leave the directory ([Later calls](docs/reference.md#4-later-calls)).

## v0.4.0 (2026-10-23)

goose-rest is now Plod. The package, its namespace, and its generator take the new
name; error codes, JSON shapes, and HTTP behaviour are as in `v0.3.4`. The repository
is now `github.com/kaitk/plod`; GitHub redirects `kaitk/goose-rest`, so imports of
earlier tags keep working. Goose
`v2026.3`, goose-http `v0.5.4`, goose-compress `v0.1.1`; `plod.websocket` declares
goose-hash `v0.0.4`, and `plod.tls` goose-tls `v0.0.5`.

Breaking changes, and what a program changes:

- The package is `plod`, and its entry `plod.goose`: write
  `import plod from "github.com/kaitk/plod@v0.4.0";` where the root wrote
  `import rest from ...`, and `import plod;` in the files that wrote `import rest;`.
- Every call and type is in namespace `plod`: `rest::get` becomes `plod::get`,
  `rest::Cx` `plod::Cx`, and an overload a program declares, such as
  `fn rest::from_request` or `fn rest::error_body`, `fn plod::from_request` and
  `fn plod::error_body`.
- The optional modules are `plod.compression`, `plod.websocket`, and `plod.tls`.
- The generator is `plod gen`, and its files `import plod;` and call `plod::`:
  regenerate each `_gen.goose`. Its errors start with `plod:`.

## v0.3.4 (2026-10-22)

An HTTP client, from goose-http `v0.5.4`. Goose `v2026.3`, goose-http `v0.5.4`,
goose-compress `v0.1.1`; `rest.websocket` declares goose-hash `v0.0.4`, and `rest.tls`
goose-tls `v0.0.5`. No breaking changes in goose-rest's API.

Added:

- goose-http's `http.client`, its blocking HTTP/1.1 and HTTPS client on goose-tls,
  reaches a goose-rest program through goose-http: a lane imports it to make requests,
  with a JSON body from `rest::format_fields`.

## v0.3.3 (2026-10-22)

A TLS connection's context chosen per connection, from goose-http `v0.5.3`. Goose
`v2026.3`, goose-http `v0.5.3`, goose-compress `v0.1.1`; `rest.websocket` declares
goose-hash `v0.0.4`, and `rest.tls` goose-tls `v0.0.5`. No breaking changes in
goose-rest's API.

Added:

- `rest::serve` and `rest::serve_epoll` in `rest.tls` take goose-http's
  `http::TlsServerOf<C>`, a server with a chooser, as well as `http::TlsServer`. The
  chooser's `http::tls_hello` moves a connection to another context at its
  ClientHello, as ACME's TLS-ALPN-01 needs (`docs/reference.md`, "HTTPS").

## v0.3.2 (2026-10-22)

Faster TLS, from goose-tls `v0.0.5`. Goose `v2026.3`, goose-http `v0.5.2`,
goose-compress `v0.1.1`; `rest.websocket` declares goose-hash `v0.0.4`, and `rest.tls`
goose-tls `v0.0.5`. No breaking changes in goose-rest's API; a program that imports
`rest.tls` moves its goose-tls import to `v0.0.5`.

Changed:

- goose-tls `v0.0.5` cuts its TLS server's overhead: one HKDF and one HMAC context
  reused through a handshake, and records decrypted in place. In goose-tls's own
  measurements, 8.3% less CPU a json-like request, 2.7% a full handshake, and 11.8% a
  resumed one.

## v0.3.1 (2026-10-22)

h2 over TLS, and less memory per TLS connection, from goose-http `v0.5.1`. Goose
`v2026.3`, goose-http `v0.5.1`, goose-compress `v0.1.1`; `rest.websocket` declares
goose-hash `v0.0.4`, and `rest.tls` goose-tls `v0.0.4`. No breaking changes in
goose-rest's API; a program that imports `rest.tls` moves its goose-tls import to
`v0.0.4`.

Added:

- `rest.tls` serves h2 over TLS: a context made with `["h2", "http/1.1"]` as its ALPN
  protocols serves h2 to a client that chooses it and HTTP/1.1 to one that doesn't, on
  one port, through `rest::serve` and `rest::serve_epoll` alike. Handlers don't change
  ([reference](docs/reference.md#13-https)).

Changed:

- goose-tls `v0.0.4`'s TLS 1.3 server, written in Goose over libcrypto, holds 2.9 KB
  per idle connection where libssl's held 28.5 KB, and sends session tickets. The kTLS
  handoff is gone. A client whose ALPN offer shares no protocol with the context's now
  fails with `no_application_protocol`. The build still needs CMake
  and OpenSSL 3.

Fixed, in goose-http:

- On io_uring, a socket a handler waits on with `http::wait_socket` is released when
  the handler answers in the call that waited, or when its h2 stream is reset, rather
  than held open until the connection's next event or close.
- An h2 stream refused with 413, for a body past `Config.max_body`, calls its handler
  with `CLOSED` when it was owed a call, so a socket it holds is hung up.
- An idle h2 connection, h2c or over TLS, is sent GOAWAY before it closes.

## v0.3.0 (2026-10-22)

Shorter routes, goose-http's gather pool for gathered bodies and replies, WebSocket and
HTTPS modules, and helpers for security headers, cookies, Server-Sent Events, and
problem details. Goose `v2026.3`, goose-http `v0.5.0`, goose-compress `v0.1.1`;
`rest.websocket` declares goose-hash `v0.0.4`, and `rest.tls` goose-tls `v0.0.3`.

Breaking changes, and what a program changes:

- `rest::scope(cx, "/p") { ... };` is a block, which owns the paths under its prefix
  and answers a 404 or 405 for them itself. The `bool` `rest::scope` is gone: write the
  block where a program wrote `if rest::scope(cx, "/p") { ... }`.
- `rest::Config` is gone, and `rest::serve`, `rest::serve_epoll`, and `rest::serve_one`
  no longer take `limits`: drop the argument. A program sets its gather budget with
  `http::gather_budget(bytes)` in `main`, before `http::run`; `rest::serve` and
  `rest::serve_one` leave the budget as it is. `rest::GATHER_BUDGET`, `rest::Budget`,
  `rest::Run`, and `Cx.budget` are gone.
- `rest::ask` takes `most`, the reply's limit, `rest::REPLY_LIMIT`, 64 KB, by default,
  promised from the gather pool before the job is sent, and refused there with 503
  `unavailable`. A `rest::reply_value` past it gets 502 `reply_too_large`: pass a
  larger `most` to a lane that replies more.
- A chunked body is refused at its head, with 503 `unavailable` and `Retry-After: 1`,
  when the gather budget can't promise its route's limit, not once it grows past the
  budget.
- goose-http's `TIMEOUT` at once, for want of a timer, is told by its tag
  `http::NO_ROOM`, not by the clock, so a busy loop no longer passes it for a pause's
  own. `rest::ask` answers it 503 `unavailable` with `Retry-After: 1`, where it
  answered 504 `timeout`.
- `rest::body` and `rest::body_in_pieces` called at a later call than the request's
  fail with 500 `body_too_late`, where `rest::body` returned an empty body and
  `rest::body_in_pieces` ended a body after its first piece: read the body at the
  request.

Shorter routes: a program's routes are statements in a row, and scopes are blocks
([reference](docs/reference.md#1-context-and-routes),
[decision](docs/decisions.md#the-api)).

- `rest::get`, `post`, `put`, `patch`, and `delete` match a method and a pattern, take
  the request, and run their block. The routes and scopes after a route that took the
  request don't match, and the code after it runs.
- `rest::routes` opens the request's one route, and answers 404, 405, OPTIONS, and 501
  itself when its block answered nothing. Inside it, `rest::route` joins that route.
- `rest::scoped(cx) { ... }` runs a middleware's block, inside `rest::routes`, as a
  route of its own that gives the default answer. `rest::cors`, `rest::timed`,
  `rest::security_headers`, and `rest::compressed` run their block in it, so each works
  inside a scope, its errors, 404s, and 405s getting its fields.
- `rest::on` and `rest::otherwise` stay; `rest::otherwise` answers nothing after a
  route that took the request. The generated `dispatch` begins with
  `rest::untaken(cx)`, and answers nothing after a hand-written route that took it.
- `rest::routes`, `rest::otherwise`, and the generated router take a request no route
  took's status from `http::unrouted`, rather than deciding it again.
- The generated `dispatch` passes the context to each operation by reference, which
  saves a copy of `rest::Cx` per request. Regenerate a router to take it.

goose-http's parts in place of goose-rest's own copies
([decisions](docs/decisions.md#waiting-on-another-thread)).

- Gathered bodies, collected replies, and the fields middleware keeps for a later answer
  are runs of goose-http's gather pool, in place of goose-rest's own spill. Each is
  promised its most when it's admitted, and refused there with 503 `unavailable` and
  `Retry-After: 1`.
- Whether a body came whole is goose-http's `Event.whole`, read where it's given, with
  no bit kept per connection.
- `rest::upgrade` on an HTTP/2 stream, which goose-http answers 501, no longer gives the
  route a `CLOSED`.

WebSocket and HTTPS, each in a module `rest` doesn't import, made of goose-http's parts
([decisions](docs/decisions.md#websocket-and-https)).

- `rest.websocket`: `rest::ws_upgrade(cx, ws, u, protocol)` answers a WebSocket's
  handshake with 101, its `http::WebSocket` promised its bytes from the gather pool, and
  refuses in the program's error shape: 426 `upgrade_required`, 400 `bad_handshake`, 501
  `not_implemented` on h2, and 503 `unavailable`. `rest::ws_read(cx, ws) { op, data =>
  ... }` gives a case function each whole message, and releases at `CLOSED`
  ([reference](docs/reference.md#43-websocket)). `examples/websocket` is an echo server.
- `rest.tls`: `rest::serve` and `rest::serve_epoll` take goose-http's
  `http::TlsServer`, and serve HTTPS on the listeners that ask for it
  ([reference](docs/reference.md#13-https)).

Helpers:

- `rest::security_headers(cx, cfg) { ... }` adds a prepared security policy to every
  answer inside, errors included, from the `rest::security_html()` or
  `rest::security_api()` presets that `rest::prepare_security_headers` writes once per
  worker ([reference](docs/reference.md#22-security-headers)).
- `rest::set_cookie` and `rest::clear_cookie` write a `Set-Cookie` field through
  goose-http's `http::set_cookie` ([reference](docs/reference.md#12-cookies-out)).
- `rest::sse_begin`, `sse_event`, `sse_data`, `sse_json`, `sse_comment`, and
  `sse_retry` send Server-Sent Events ([reference](docs/reference.md#42-server-sent-events)).
- `rest::problem_body` writes an error as RFC 9457 problem details, chosen with a
  program's `rest::error_body` and `rest::error_type` overloads.
- `rest::pause(cx, ms, u)` pauses a route before a response has begun, with `u` in
  `cx.state.use`.

Benchmarks: `bench/rest.sh count` takes `LOOP=uring`, and tier A's server takes
`SECURITY=1` for the API security headers. Instructions per request, from `bd9967b` on
goose-http `v0.4.3` to `0dd585f` on goose-http `e128cb39`, the commit `v0.5.0` tags,
with goose-http's `count.sh` and 1 million requests a case, one run each, on a Ryzen 7 PRO 6850U (WSL2, kernel 6.18.54, gcc 15.2,
Goose `v2026.3` both sides): on epoll, every case costs the same or less, from 15 fewer
on tier F's `/` to 105 fewer on tier M's 401. On io_uring, most cost less, up to 90
fewer on tier M's 401, but tier A's `/api/me` 401 costs 14 more and tier R's
`/authorizations` 6 more.

## v0.2.1 (2026-10-20)

The tier C benchmark's JWT check scans 16 bytes at a time, and the goose-http pin
moves to `v0.4.3`: faster bearer and header scans, and h2 state kept off epoll's
HTTP/1.1 turns. Goose master `f114b5a`, goose-compress `v0.1.1`.
The tag names `62c340d`, the commit measured in the 2026-10-20 benchmark session.

## v0.2.0 (2026-10-19)

Lanes of several threads, each typed by an enum of its jobs, replies in pieces, and
workers started with `http::run`. Goose master `f114b5a`, since no release has
[aardappel/goose#37](https://github.com/aardappel/goose/pull/37) yet, which `http::run`
and `http::lane_open` need; goose-http `v0.4.0`, goose-compress `v0.1.1`.

- Lanes are goose-http's, and there is one way to use them
  ([reference](docs/reference.md#41-lanes)). Each lane takes a fixed-mode enum of its
  jobs, a variant per use case: `rest::lane_open<U>(cfg, mark, W)` opens a
  `rest::Lane<U, M>` of `http::LaneConfig`'s `threads`, spawning each `thread_fn W(box,
  jobs: rest::Jobs<U>)`, and a thread whose `jobs` names another enum doesn't compile.
  `rest::lane(box, jobs) { u, a => ... }` is a lane thread's loop, `rest::lane_job` one
  job of it, and `rest::lane_stop` stops the lane once the jobs queued are done.
- `rest::ask(cx, lane, job, ms)` sends a variant of the lane's enum to the least busy
  thread and keeps only the lane's mark in `cx.state.use`. The reply carries the job
  back: the mark's `resume` dispatches on `rest::job<U>(cx)`, and the job's `resume`
  reads `rest::answer<T>(cx)`. `rest::ask` fails with 500 `job_too_large` before it
  sends a job that can't fit a message with its length. Breaking: the ask to a box,
  `rest::ask_by`, the tagged `ask`, `rest::asked`, `rest::read_reply`, and
  `cx.state.waiting` are gone.
- `rest::fail` on a lane refuses the job, which fails the route with its status and
  code before the `resume` runs, so a domain's checks serve a route and a lane alike. A
  job that gets no reply answers 500 `no_reply`.
- `rest::reply_value` replies in pieces that the worker collects in its spill, counted
  against `gather_budget`, and the `resume` runs once with the whole reply; past the
  budget the route fails with 502 `reply_too_large`. `rest::reply`'s pieces still go on
  one at a time through `rest::relay`.
- `cx.state.use` keeps a route's variant after it answers, so the `CLOSED` that follows
  an early answer reaches the variant that holds what to release.
- Every program starts its workers with `http::run`, and tests play a lane's job with
  `rest::play`, with no thread.
- The REST benchmark adds ntex on io_uring and Aegon (C++) beside Axum, actix-web, and
  dusty, and the Rust servers share one release profile.

## v0.1.2 (2026-10-16)

A JSON writer from a struct's fields, multipart extractors, and pauses for events sent
over time. Goose `v2026.2` (`3ee3871`), goose-http `v0.3.6`, goose-compress `v0.1.1`.

- `rest::format_fields(out, v)` writes a struct as a JSON object, every field under its
  declared name, through Goose's new `const for`: a program's `format` overload can be
  one line. It doesn't rename a key, leave out a field, or read JSON
  ([reference](docs/reference.md#11-json-from-a-structs-fields)).
- `rest::part`, `part_int`, `part_bool`, and `file_part` read a part of a whole
  `multipart/form-data` body as slices of it, over goose-http's `http::find_part`.
- `rest::pause(cx, ms)` pauses a response begun with `rest::begin`, for events sent over
  time such as Server-Sent Events: the handler is called again with `http::TIMEOUT` and
  sends the next piece.
- An upgraded route that waits with `rest::ask` gets its client's bytes as `BODY`
  meanwhile, and `TIMEOUT` in place of a 504. A second `ask` while one waits fails with
  500 `already_waiting`.
- The REST benchmark server imports goose-http's shared application module, so it does
  the same work outside the framework as goose-http's server.
- The docs call the threads a program asks "lanes", and the Best practices have a
  Testing page.

## v0.1.1 (2026-10-16)

A faster generated router, and goose-http's fix for its emulated ring. Goose `v2026.1`
(`ac759c3`), goose-http `v0.3.4`.

- The generator writes each operation as a function of its own, which `dispatch` calls,
  where it wrote every operation inside `dispatch`. With them all inline, `dispatch`'s
  stack frame grew with the document's routes, and the C compiler's stack probes
  touched it page by page on every request: on 203 routes, more than half a request's
  cycles. Regenerate a router to take it.
- goose-http `v0.3.4`: the ring's emulation over epoll, and over kqueue on macOS, no
  longer leaves a connection waiting for seconds under load.
- The README and the architecture name the event-loop and offload patterns: I/O-bound
  work goes to services, CPU-bound work stays in routes. The best practices show the
  example app's domains and data model.

## v0.1.0 (2026-10-15)

Bodies and responses in pieces, files and upgraded connections, forms, compression, and
bounded memory for gathered bodies, with renamed service calls. Goose `v2026.1`
(`ac759c3`), goose-http `v0.3.3`.

- Bodies and responses in pieces: `rest::body_in_pieces` reads a body of any size as it
  arrives, up to a route's limit, and `rest::begin`, `send`, and `end` send a response
  as the client takes it. Each later call goes to the route's case function, with
  `cx.kind` saying which event it is.
- `rest::file` and `rest::send_file` serve a file in pieces, with ranges, `ETag`,
  `Last-Modified`, and 304; `rest::upgrade` answers 101 and hands the upgraded
  connection's bytes to the route, which `rest::send` writes back raw.
- URL-encoded form extractors: `rest::form`, `rest::form_int`, and `rest::form_bool`.
- An optional `rest.compression` module: `rest::compressed` compresses answers with
  gzip, deflate, or zstd according to `Accept-Encoding`, including responses sent in
  pieces with `rest::begin`. It declares goose-compress at `v0.1.0`.
- The CORS fields and `Server-Timing` that a route's middleware decided reach an answer
  written at a later call: a reply, a body's end, a 504, or a 413.
- `rest::serve_one` takes a waiting route's replies or its timeout (`rest::Wake`), so a
  test can drive a route that asks a service.
- A body with a `Content-Length` is gathered in one run of its exact size.
- A per-worker budget for bodies being gathered, `rest::Config`'s `gather_budget` (64 MB
  by default), passed to `rest::serve` or `serve_one`. A body past it gets 503
  `unavailable` with `Retry-After`.
- The generator's `format: ascii`, and strings of the ASCII formats sized in bytes, not
  four bytes a code point.
- Every JSON string goose-rest writes, in the generated writers and the error bodies,
  goes through goose-http's `http::json_string`, which looks for a byte to escape 16
  bytes at a time. The output is unchanged.
- Docs: tutorial pages on bodies in pieces, long responses, services, limits, testing
  with services, and middleware stacks of a program's own; a Best practices section on
  laying out an application; and the architecture split into how goose-rest works and
  the decisions behind it.
- The tests follow Goose's convention: small programs by area under `test/`, each
  checked against its expected output, run by `test/run_tests.py`.
- API changes: `rest::woken` is `rest::resumed`, and is true for every call after the
  request's first. The service calls are renamed: `rest::answer` is `rest::reply`,
  `rest::answer_value` is `rest::reply_value`, and `rest::wanted` is
  `rest::still_wanted`; the route reads a value reply with `rest::read_reply<T>`, which
  was `rest::reply_value<T>`. `rest::serve` and `serve_one` take an optional
  `rest::Config`.

## v0.0.1 (2026-10-15)

The first tag, of the API goose-rest means to keep: routes, middleware, extractors, and
errors, and a generator for OpenAPI. Goose `v2026.1` (`ac759c3`), goose-http `v0.3.1`.

- The runtime core: `rest::Cx`, `serve`, `routes`, `on`, `route`, `fail`, `json`,
  `text`, `empty`, and `otherwise`, with one error shape a program can replace.
- Extractors: path, query, header, and cookie parameters, `take<T>` for a JSON body or a
  program's own type, `once`, and bodies gathered past the read buffer up to a route's
  limit.
- Middleware: CORS, a bearer check, Server-Timing with the access log, and prefix
  scopes.
- `goose-rest gen`: types, readers, writers, extractors, and a router from an OpenAPI
  3.1 document, with `x-body-limit`; the router answers 405 and `OPTIONS` with
  hand-written routes beside it.
- The TypeScript helper, `ts/api.mts`, typed to the generator's subset.
- Waiting on another thread: `rest::ask`, replies of any size in pieces, and
  `rest::wanted` to skip the work for a client that has gone.
- `rest::serve_one`, to test a handler without sockets.
- Examples: a JSON API with and without a schema, waiting on a thread, and a board's
  API, cross-built and run on arm64 under Docker.
