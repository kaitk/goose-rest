# 006: Middleware, scopes, and examples

Status: done (2026-10-13)

The middleware every API needs, as blocks, and prefix scopes over `http::router`.

## Acceptance criteria

- [x] CORS, answering a preflight itself; a bearer token check; request timing with
      `Server-Timing` and the access log
- [x] Prefix scopes, with 404, 405 with `Allow`, and `OPTIONS` from `http::otherwise`
      across them
- [x] `examples/` with a JSON API without a schema and one with a schema, which
      `scripts/test.sh` builds and requests once per route
- [x] The README's quick start and API section match the examples

## What was built

`middleware.goose`, listed in the README's "Middleware":

- `cors` puts its fields in `cx.out.common`, which `http::start` writes into every
  answer, for as long as its block runs. So the route's errors and a handler's own
  `http::respond` get them, and nothing is done after the block. It answers a preflight
  with 204 and an origin it doesn't list with 403 itself.
- `bearer` and `bearer_token` fail 401 with `WWW-Authenticate`, which `Failure` now
  carries (`fail_auth`); `invalid_token` refuses a token.
- `timed` inserts `Server-Timing` after the status line of the answer its block wrote,
  and writes an access log line.
- `scope` narrows the router's path to what follows a prefix, at a segment boundary.

`test/test_middleware.goose` checks each answer byte for byte.
`test/inline_route.goose` puts `timed`, `cors`, a scope, `route`, and `bearer` around a
handler with failures two calls down. `scripts/test.sh` checks that its `-O2` C keeps
none of them, nor the functions that fail: all are inlined into the handler.

`examples/plain/` and `examples/schema/` serve the same projects API, without and with
`api.json`. `scripts/test-examples.sh` builds each, serves it, and checks 18 and 16
requests' status and body against `expected.txt`.

## Found on the way

- A request has one `rest::route`, which middleware doesn't open. Nested routes, a
  failing function left out of line, and a block-taking function past the inliner's
  size each kept the handler in pieces. The architecture doc's "Inlining" has the three
  rules this sets, and the last one is a compiler gap
  ([findings](../docs/goose-findings.md#a-function-called-once-isnt-inlined-past-a-size),
  aardappel/goose#33). The block-taking functions are `inline fn` until it's fixed.
- `resize` on the write buffer is refused while a slice of the request is live, as it
  may shrink; `insert_field` grows the buffer by appending.
- A middleware given `cx` as an untyped parameter changes a copy; `cors` takes
  `Cx<S>&` so that its block sees `cx.out.common`.
