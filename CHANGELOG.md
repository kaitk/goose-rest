# Changelog

What each tag adds. Each release names the Goose compiler it was built and tested with.

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
