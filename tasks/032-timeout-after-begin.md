# 032: Timers for a route that began a response

Status: done (2026-10-16)

A route that begins a response with `rest::begin` is called again at `MORE`, when the
client has taken what was sent, and at `CLOSED`. It has no call at a time of its own
choosing, so it can't send events over time, such as Server-Sent Events or a
progress stream, without a service that replies on a schedule. goose-http's `TIMEOUT`
gives a waiting exchange such a call, which `rest::ask` uses for its wait: goose-rest
would let a route ask for one after it has begun a response. Whether goose-http can arm
a timer on an exchange whose response is open is the first thing to check; if it can't,
that's a goose-http task.

## Acceptance criteria

- [x] A route that began a response can ask for a call after a given time, and gets
      `http::TIMEOUT` then, in its case function, with the response still open
- [x] It can ask again from that call, and a client that goes cancels the timer and
      gives `CLOSED`
- [x] Tests cover events sent over time, and a client that goes between them
- [x] An example or a tutorial section sends Server-Sent Events this way

## Outcome (2026-10-16)

`rest::pause(cx, ms)` in `pieces.goose`; a `TIMEOUT` on a response begun with
`rest::begin` goes to the route in `arrived` (`runtime.goose`), which ends the
response when the clock says goose-http gave it at once. The decision and what it
rejected: `docs/decisions.md`, "Waiting on another thread" (2026-10-16). Tests:
`test/pieces/events.goose`; the tutorial's page 12, "Events over time", serves
`/v1/projects/:id/progress`, and was also run once with `max_waiting: 1` and two
streams, the second ending after its first event.

Found while reading goose-http v0.3.3, not run: without `Config.mail_slots` and
`max_waiting`, `start_wait` finds no timer and queues the exchange in `overdue`, which
both loops process only `if waiting`, so a `later` on an open response never gets
`TIMEOUT`, and the stream stalls until the connection's deadline. `rest::pause` says
it needs both, as `rest::ask` does. For goose-http to decide: `TIMEOUT` at once there
too, as its docs say for `max_waiting`.

## Findings (2026-10-16)

Answer: yes for goose-http, partly for goose-rest. goose-http v0.3.3, the pinned tag,
arms a timer on an exchange whose response is open. goose-rest doesn't pass the
resulting `http::TIMEOUT` to the route, so this needs a goose-rest change and no
goose-http task. Read from source at the tag, not run; a spike would confirm the
goose-rest half.

### Evidence in goose-http v0.3.3

- `http.goose`, `later(out, ms)`: sets `stream.waiting`, `rearm`, and `wait_ms`, and
  returns the exchange's address. Its comment says that "at MORE, or after begin, it
  pauses an open response, for Server-Sent Events and long polling". It checks nothing
  about `stream.open`.
- `docs/api.md` ("Answers that wait") says the same, and `docs/patterns.md` ("Long
  responses", "Events over time") names `http::later` for Server-Sent Events, shown in
  `examples/device/` (`/api/events`).
- `epoll.goose`, `call`: after the handler returns, `unwait()` cancels a wait only when
  the call wrote a whole response or ended one (`!x.stream.open`). An open response
  keeps its wait, and `start_wait` arms the timer.
- `epoll.goose`, `timed_out(key, waited)`: at the deadline clears the wait and calls the
  handler with `Event { kind: TIMEOUT }`; `delivered` does the same for `WAKE`. Neither
  requires a closed response. A client that goes while the exchange waits gets the
  handler `CLOSED` (`docs/api.md`), and the pending timer is cancelled.
- `later` at the `Config.max_waiting` limit, or without `Config.mail_slots` and
  `max_waiting`, gives `TIMEOUT` at once, so a route can't tell that case from a real
  deadline except by the clock (`examples/device/device.goose` checks `now_ms()` against
  its own due time).
- The same `later` call works again from the `TIMEOUT` call, as `device.goose` does
  (`reading` calls `http::later(out, st.ms)`).

### What goose-rest does today

- A route can already call `http::later(cx.out, ms)` at `MORE` after `rest::begin`;
  nothing in `pieces.goose` stops it. The `WAKE` it can get reaches the handler:
  `runtime.goose`, `on_event` calls `H` for `REQUEST` and `WAKE`.
- `TIMEOUT` never reaches the route. `on_event` handles `http::TIMEOUT` itself: it writes
  `504 timeout` only when `!out.stream.open`, and returns -1; `on_later` then calls
  `arrived`, which returns `NO_EVENT` for `TIMEOUT`. With a response open, nothing is
  written and the handler isn't called, so the exchange is left neither waiting nor
  sending, and goose-http closes the connection (the same outcome as a `MORE` that does
  nothing, `docs/api.md`). That makes acceptance criterion 1 fail, and an early
  `TIMEOUT` from `max_waiting` closes the stream.
- `rest::ask` and `relay_piece` (`waiting.goose`) use `later` for a reply, whose `TIMEOUT`
  answer 504 is the right one only while the response isn't open.

### What follows

Add to goose-rest; no goose-http task is needed.

1. `rest::wake_after(cx, ms)` in `pieces.goose`, beside `begin`: guards that the response
   is open (`cx.out.stream.open`, else `fail` 500), calls `http::later(cx.out, ms)`, and
   sets nothing else, since `cx.state.waiting` was set by `begin`. It returns after the
   caller's `send`, so a route sends a piece and asks for the next call in one `MORE`
   or `TIMEOUT` case.
2. `runtime.goose`: in `on_event`, when `ev.kind == http::TIMEOUT` and
   `out.stream.open` and the exchange is `SENDING` (`st.ex.mode`), don't take the 504
   path; return a mark so the handler is called with `kind == http::TIMEOUT`, as it is
   for `WAKE`. A response that isn't open keeps the 504. For the `max_waiting` case,
   record the arming time in `Exchange` (`rest::wake_after` stores `now + ms`), and
   give the route `TIMEOUT` only when the clock has reached it; otherwise end the
   response, as `device.goose` does, or the client sees a stream that never ends.
3. `pieces.goose` docs: say that a `begin` route gets `http::TIMEOUT` and `http::WAKE`
   in its case function once it called `wake_after`, and that `http::CLOSED` cancels the
   timer. `docs/reference.md` lists the function; a Server-Sent Events example goes
   under `examples/` or `docs/tutorial/`.
4. Check `testing.goose` (`serve_one`'s own `on_later` call, line 135) and the middleware
   that wraps a route (`rest::compressed` at a later call) pass `TIMEOUT` the same way.

Open: whether `Exchange` can keep the deadline without a per-exchange clock read, and
whether a route that forgets to ask again should end the response or get the 504-like
close it gets now. Both are goose-rest decisions to record in `docs/decisions.md` with
the implementation.
