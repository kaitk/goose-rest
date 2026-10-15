# 031: Test a route past `rest::ask` without sockets

Status: todo (proposed in task 024, 2026-10-15)

`rest::serve_one` runs no loop, so it can't drive a route past `rest::ask`: the job
reaches the service, but nothing calls the handler again with the reply. Case functions
are tested over HTTP only, with a real service thread and timing margins (tutorial page
16). A `serve_one` that, after a route asks, called the handler again with a reply the
test gives, as a `WAKE` event, would let a test check each case function's answer
without sockets, threads, or margins.

## Acceptance criteria

- [ ] A test can give `serve_one` a reply for a route that asked, and get the route's
      answer to it, with the reply's tag and pieces as `rest::reply` sends them
- [ ] A test can give it a `TIMEOUT` instead, and get the 504
- [ ] Unit tests cover a reply in one piece and in several
- [ ] Tutorial page 16 tests a case function this way, beside its HTTP test
