# 025: Middleware fields on answers written after the request

Status: done (2026-10-15)

`rest::cors` and `rest::timed` add their fields to the answers written while the handler
runs for the request. An answer written later, when a route resumes at a service's
reply, at the end of a body read in pieces, or in a response begun later, got neither:
the middleware's blocks ran at `REQUEST`, and the request's head is gone by then. A
browser then refused a cross-origin answer that a waiting route or an upload writes
(task 023's page 11 showed one). Found in task 023's proposal, which left it here.

## Acceptance criteria

- [x] What each middleware decided at `REQUEST` (CORS's allowed origin, the timing's
      start) is kept with the exchange, and an answer written later gets the same fields
- [x] A program that uses neither middleware pays nothing for it
- [x] Tests cover a route that resumes at `WAKE` and one that answers at a body's `END`
- [x] The reference says which answers get which fields

## How it works

- After its block, `cors` or `timed` checks whether the route left the request
  unanswered for a later call: waiting on `rest::ask`, or reading with
  `rest::body_in_pieces`, and not gathering for `rest::body`, which runs the route again.
  If so, the innermost middleware records where its `cx.out.common` sits in `cx.scratch`
  in a `Kept` local of `on_event` (or of `on_later`'s call for a gathered body), reached
  through the new `cx.kept`. `timed` adds its start and log setting. `Kept` holds
  offsets, not a slice: the checker refused a slice of the scratch stored through
  `cx.kept` from a handler that isn't inlined.
- After the handler returns, `on_event` copies that into a run of the worker's spill: 8
  bytes of start, a flag byte, the middleware's fields without goose-http's
  `Server`/`Date`, and for the log the method and target. The exchange's `at`, `cap`, and
  `head`, which only a gathered body uses and never at the same time, locate it, and a
  new `Exchange.mode` bit, `KEPT`, marks it.
- At `WAKE`, `TIMEOUT`, and each `on_later` call, the reply's `common` is goose-http's
  current fields followed by the kept ones. Once a call writes the answer's head, serve
  fills in `Server-Timing` from the kept start, writes the log line, and frees the run.
  `CLOSED`, `TIMEOUT`, or an exchange that ends without an answer also frees it.
- At a later call `timed` runs its block as it is, so wrapping the resume in it doesn't
  add a second field.

## Cost

- Per connection slot: no bytes. `Exchange` stays 42 bytes (Goose packs structs); the
  kept data reuses the gathered body's fields and a spare `mode` bit.
- Per waiting exchange behind the middleware: a run of 9 bytes plus the fields (about
  100 bytes for CORS with an `expose` list, 37 for `Server-Timing`) plus the request line
  when `timed` logs, in the worker's spill until the answer.
- Per request, for every program: `on_event` initializes a `Kept`, an empty buffer, and
  a copy of the reply, and checks `kept.taken` after the handler; `cors` and `timed` compare
  the buffer's length once after their block. Not measured; tier M's instruction count
  on Linux would show it.

## Alternatives not taken

- A field in `Slot` or `Exchange` for the kept run: simpler, but 8 to 16 bytes per
  connection slot for every program.
- A per-worker dictionary keyed by the connection's fd: no slot bytes either, but a hash
  lookup per later event and stale entries to manage when an fd is reused.
- A `rest::keep_middleware(cx)` call the route makes before waiting: an API a user must
  remember, where serve can tell by itself.
