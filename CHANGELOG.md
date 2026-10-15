# Changelog

What each tag adds. Each release names the Goose compiler it was built and tested with.

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
