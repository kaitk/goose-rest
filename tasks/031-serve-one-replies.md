# 031: Test a route past `rest::ask` without sockets

Status: done (2026-10-15; proposed in task 024)

`rest::serve_one` runs no loop, so it can't drive a route past `rest::ask`: the job
reaches the service, but nothing calls the handler again with the reply. Case functions
are tested over HTTP only, with a real service thread and timing margins (tutorial page
16). A `serve_one` that, after a route asks, called the handler again with a reply the
test gives, as a `WAKE` event, would let a test check each case function's answer
without sockets, threads, or margins.

## Acceptance criteria

- [x] A test can give `serve_one` a reply for a route that asked, and get the route's
      answer to it, with the reply's tag and pieces as `rest::reply` sends them
- [x] A test can give it a `TIMEOUT` instead, and get the 504
- [x] Unit tests cover a reply in one piece and in several
- [x] Tutorial page 16 tests a case function this way, beside its HTTP test

`rest::serve_one(text, app, fresh, wakes, cfg)` takes a `rest::Wake` per wait, in
order: a reply's bytes and tag, split at `cfg.mail_size`, or `timeout: true`.
`rest::value_bytes(v)` gives a flat value's bytes. `test/test_serve_one.goose` covers
one piece, several, a value in pieces, the timeout, two waits in turn, and a wait with
no wake left; `docs/tutorial/13-waiting/test.goose` the assign route's case function.
