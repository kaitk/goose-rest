# 009: Waiting on another thread

Status: done (2026-10-13)

A handler that asks another thread and a case function that answers when the reply
arrives, on spike 06's result.

## Acceptance criteria

- [x] `rest::ask`, and resuming through the application's `Waiting` enum
- [x] An example with a database thread, tested over HTTP
- [x] Replies larger than a mailbox slot, by whatever spike 06 settles
- [x] A route that never waits keeps nothing on the connection

## What was built

`waiting.goose`. `rest::ask(cx, to, tag, job, w)` keeps `w` in `cx.state.waiting`,
calls `http::later`, and sends a `rest::Ask<J>`: the job, the reply's address, and the
size of a reply message, `Config.mail_size`. A full or closed box fails 503
`unavailable`. `rest::serve` calls the handler again at the reply, where
`rest::woken(cx)` is true, and the program dispatches `resume(cx.state.waiting, cx)` to
a case function per variant. A reply that doesn't come in time is 504 `timeout`.

The other thread takes the job with `rest::asked<J>` and replies with `rest::answer`
or `rest::answer_value`, in pieces of at most a message, flagged in the tag's top bits.
`rest::relay(cx, status, content_type)` answers whole when the reply came in one
message, or begins a chunked response whose later pieces `rest::serve` sends on itself.
`rest::reply_value<T>` reads a flat value that fit one message.

goose-http's task 028 isn't built, so this works around it as spike 06 does: the job
carries the slot size, and `answer` retries a `FULL` piece after a millisecond.

`examples/waiting/` has a database thread with a report, one flat value, and an export
of `[[org, row, row²], ...]` through 64-byte messages, which `scripts/test-examples.sh`
requests. An export of 5,000 rows, 84,265 bytes, and eight of 300 rows at once came
back byte for byte (macOS, 2026-10-13).

## Found on the way

- goose-http's `serve` gave a block handler a copy of the per-request state, so what
  `ask` kept there was gone at the reply. Fixed in goose-http (`e27ab21`, passing
  `&x.state`), and the pin moved to it.
