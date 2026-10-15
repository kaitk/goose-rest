# 039: An upgraded connection's bytes while its route waits on a service

Status: todo (found moving the goose-http pin to v0.3.3, 2026-10-15)

From goose-http v0.3.3, an upgraded connection's bytes keep coming as `BODY` while its
exchange waits with `http::later`, and the handler can answer them with `http::send`;
`WAKE` or `TIMEOUT` comes when the reply or the limit does. goose-rest passes those
`BODY` events on, but what a route gets for them is undefined.

A route that called `rest::upgrade` and then `rest::ask` (at the request, or at a `BODY`)
has the ask's variant in `cx.state.waiting`: `rest::ask` overwrites the upgrade's. A
`BODY` during the wait goes through `on_event`, which calls nothing for it, then
`on_later`'s `arrived`, which passes a `BODY` on for any exchange with `UPGRADED` in its
mode. The handler then calls `resume(cx.state.waiting, cx)`, so the ask's case function
gets `cx.kind == http::BODY`, while the reference's Later calls table says it gets
`WAKE` alone. A case function written for that table ignores the bytes, and they are
lost. Further:

- After the `WAKE`, nothing restores the upgrade's variant: the route must set
  `cx.state.waiting` back itself, and no doc says so.
- A `TIMEOUT` on an upgraded connection writes nothing, since its response is open
  (`on_event` answers 504 only for one not begun), and calls no case function, so the
  route never learns that its wait ended.
- A `rest::ask` at a `BODY` during a wait sends a second job, with two replies to one
  exchange; goose-http's `later` at `BODY` only starts the limit again.

Found on goose-http `v0.3.3` (`95f4f2f`), Goose `v2026.1` (`ac759c3`), by reading
`runtime.goose`, not yet by a test.

## Acceptance criteria

- [ ] Decide which case function gets a `BODY` that comes while an upgraded route waits,
      and what the route gets at a `TIMEOUT` there
- [ ] The upgrade's variant, or its equivalent, still gets the client's bytes once the
      reply has come, without the route restoring it by hand, or the reference says it must
- [ ] A test sends bytes to an upgraded connection while its route waits on `rest::ask`,
      and checks where they go, at the reply and at the timeout
- [ ] `docs/reference.md`, "Later calls", says what an upgraded route gets while it waits
