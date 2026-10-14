# 004: The runtime core

Status: done (2026-10-13)

`rest::Cx`, `rest::serve`, `rest::route` and `rest::fail`, one JSON error shape, and
`rest::json` and `rest::text`. Started before goose-http's task 027 settled (asked for
2026-10-13), on goose-http `cfb9c02`, where `main` holds 027's p2, p4, p5, and p6 and
`Event` is a struct again. A later breaking change there is absorbed in `rest::serve` and
the helpers that wrap goose-http's types; handlers see only `rest::Cx`.

## Acceptance criteria

- [x] `Cx` over goose-http's `Request`, `Reply`, and per-request state
- [x] `fail` from any depth below `route`, with an owned `u8[]` code
- [x] Every error answered in one JSON shape, which the README documents
- [x] Unit tests of each response's exact bytes
- [x] Generated C of a handler with two middleware blocks and `route` is one function,
      as in spike 04

## What was built

`runtime.goose`:

- `Cx<S>` holds the request, its whole body, the `Reply`, and the per-request state
  `S` by reference. `rest::serve(cfg, fresh)` serves with `http::serve` and calls its
  block at each request once the body is whole; `rest::serve(cfg)` keeps no state.
- `route` and `fail` follow the stdlib's `exception` module: `route` runs its block
  inside `attempt`, which returns `Failure[]`, and `fail` returns one `Failure` from
  `attempt`, its code built with `str()`. `fail_body` fails with a JSON reader's error.
- `json`, `text`, and `otherwise`, which answers as `http::otherwise` does with each
  error in the JSON shape.

`test/test_runtime.goose` checks each answer byte for byte, through the generated
`api::read_project` for a refused body. `test/inline_route.goose` puts two middleware
blocks around `route` with a failure two calls below, and `scripts/test.sh` checks its
`-O2` C: the handler, both blocks, `route`, `attempt`, `fail`, and the failing functions
are inlined into `main_g`. Only library leaves stay calls: goose-http's parsers,
`json::format_string`, `rest::text`, and the error writer. A server built from
`rest::serve` answered `curl` with each of the README's errors and a generated
writer's 201 (macOS, 2026-10-13).

## Found on the way

- `route` can't take back a response begun before a failure. Shrinking the write buffer
  is refused while any slice of the request is live, since a parameter's `u8` slices may
  point into any `u8` array (spec §5.1). So the first answer wins, which the README
  states.
- A thread can't call `json::format_number`, and the generated writers did
  (aardappel/goose#31, fixed in `861b7a9`). They now call `rest::format_number`.
