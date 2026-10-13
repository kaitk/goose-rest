# 004: The runtime core

Status: todo

`rest::Cx`, `rest::serve`, `rest::route` and `rest::fail`, one JSON error shape, and
`rest::json` and `rest::text`. Waits on goose-http's task 027 breaking changes, then
moves the goose-http pin to the commit after them.

## Acceptance criteria

- [ ] `Cx` over goose-http's `Request`, `Reply`, and per-request state
- [ ] `fail` from any depth below `route`, with an owned `u8[]` code
- [ ] Every error answered in one JSON shape, which the README documents
- [ ] Unit tests of each response's exact bytes
- [ ] Generated C of a handler with two middleware blocks and `route` is one function,
      as in spike 04
