# Changelog

What each tag adds. Each release names the Goose compiler it was built and tested with.

## Unreleased

Shorter routes: a program's routes are statements in a row, and scopes are blocks
([reference](docs/reference.md#1-context-and-routes),
[decision](docs/decisions.md#the-api)).

- `rest::get`, `post`, `put`, `patch`, and `delete` match a method and a pattern, take
  the request, and run their block. The routes and scopes after a route that took the
  request don't match, and the code after it runs.
- `rest::routes` opens the request's one route, and answers 404, 405, OPTIONS, and 501
  itself when its block answered nothing. Inside it, `rest::route` joins that route.
- Breaking: `rest::scope(cx, "/p") { ... };` is a block, which owns the paths under
  its prefix and answers a 404 or 405 for them itself. The `bool` `rest::scope` is
  gone.
- `rest::scoped(cx) { ... }` runs a middleware's block, inside `rest::routes`, as a
  route of its own that gives the default answer. `rest::cors`, `rest::timed`,
  `rest::security_headers`, and `rest::compressed` run their block in it, so each works
  inside a scope, its errors, 404s, and 405s getting its fields.
- `rest::on` and `rest::otherwise` stay; `rest::otherwise` answers nothing after a
  route that took the request. The generated `dispatch` begins with
  `rest::untaken(cx)`, and answers nothing after a hand-written route that took it.

goose-http's parts in place of goose-rest's own copies, on goose-http `5701a0d`, ahead
of its `v0.5.0` ([decisions](docs/decisions.md#waiting-on-another-thread)).

- goose-http's `TIMEOUT` at once, for want of a timer, is told by its tag
  `http::NO_ROOM`, not by the clock, so a busy loop no longer passes it for a pause's
  own. Breaking: `rest::ask` answers it 503 `unavailable` with `Retry-After: 1`, where
  it answered 504 `timeout`.
- Breaking: `rest::body` and `rest::body_in_pieces` fail with 500 `body_too_late` at a
  later call than the request's, where `rest::body` returned an empty body and
  `rest::body_in_pieces` ended a body after its first piece. Whether a body came whole
  is goose-http's `Event.whole`, read where it's given, with no bit kept per
  connection.
- `rest::upgrade` on an HTTP/2 stream, which goose-http answers 501, no longer gives the
  route a `CLOSED`.
- `rest::routes`, `rest::otherwise`, and the generated router take a request no route
  took's status from `http::unrouted`, rather than deciding it again.
- Gathered bodies, collected replies, and the fields middleware keeps for a later answer
  are runs of goose-http's gather pool, under the budget a program sets with
  `http::gather_budget` in `main`, in place of goose-rest's own spill. Each is promised
  its most when it's admitted, and refused there with 503 `unavailable` and
  `Retry-After: 1`. Breaking: a chunked body is refused at its head when the budget
  can't promise its route's limit, not once it grows past the budget; `rest::ask` takes
  `most`, the reply's limit, `rest::REPLY_LIMIT`, 64 KB, by default, promised before
  the job is sent, and a `rest::reply_value` past it gets 502 `reply_too_large`, where
  the budget alone bounded it; `rest::GATHER_BUDGET`, `rest::Budget`, `rest::Run`,
  `Cx.budget`, and `rest::Config.gather_budget` are gone: a program calls
  `http::gather_budget(bytes)` in `main` before `http::run`, and `rest::serve` and
  `rest::serve_one` leave the budget as it is.

WebSocket and HTTPS, each in a module `rest` doesn't import, made of goose-http's parts
([decisions](docs/decisions.md#websocket-and-https)).

- `rest.websocket`: `rest::ws_upgrade(cx, ws, u, protocol)` answers a WebSocket's
  handshake with 101, its `http::WebSocket` promised its bytes from the gather pool, and
  refuses in the program's error shape: 426 `upgrade_required`, 400 `bad_handshake`, 501
  `not_implemented` on h2, and 503 `unavailable`. `rest::ws_read(cx, ws) { op, data =>
  ... }` gives a case function each whole message, and releases at `CLOSED`
  ([reference](docs/reference.md#43-websocket)).
- `rest.tls`: `rest::serve` and `rest::serve_epoll` take goose-http's
  `http::TlsServer`, and serve HTTPS on the listeners that ask for it
  ([reference](docs/reference.md#13-https)).

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
