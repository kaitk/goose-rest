# 014: Hand-written routes beside dispatch, and testing without sockets

Status: in-progress

Requested 2026-10-14. Three changes from writing the tutorial, each its own commit.

**Allow across hand-written and generated routes (bug).** With a hand-written
`PUT /uploads/:name` before `api::dispatch`, a `GET /uploads/x` gets 404, not 405 with
`Allow: PUT`, and OPTIONS gets 404, not 204: `dispatch` never sees the `http::Router`
that collected the hand-written route's `Allow`. Tutorial section 7 works around it with
a `rest::scope` that ends in its own `rest::otherwise`. A path that either the
hand-written routes or the generated ones match should answer 405, or OPTIONS' 204,
with an `Allow` that lists both, at no cost to the generated router.

**A test helper.** A test builds `rest::Cx` by hand, from goose-http's `http::Reply`
and `http::Stream`. A helper that takes a request's bytes, runs a block in a
`rest::route`, and returns the response's bytes keeps tests off goose-http's internals.
It runs the gathering path for a body past the read buffer, so that a test can cover the
rule that code before a route's first `rest::body` runs twice.

**Small fixes.** `http::parse` refuses an HTTP/1.1 request without `Host`, which a test
request easily lacks. The compile error for a missing handler shows about 18 lines of
goose-http's call chain.

## Acceptance criteria

- [x] `docs/architecture/README.md` records whether generated files are committed
- [x] A test reproduces the 404 for another method of a hand-written route's path
- [x] A path matched by hand-written or generated routes answers 405, and OPTIONS 204,
      with an `Allow` listing both
- [x] `bench/routes.sh` shows no slowdown of the generated router, recorded here with how
      it was measured
- [x] Tutorial section 7 and `docs/generator.md` describe the fix
- [x] A helper answers a request's bytes through a block, gathering a long body as
      `rest::serve` does: `rest::serve_one`, as `rest::answer` already replies to a
      waiting route
- [x] `test/test_router.goose` and `docs/tutorial/06-schema/test.goose` use it, and
      tutorial section 12 is written around it
- [x] A test request without `Host` works: `rest::serve_one` adds `Host: localhost`
- [ ] The missing-handler error is shorter, or its noise is recorded in
      `docs/goose-findings.md` with a minimal program

## Allow across both routers

`dispatch` takes an optional `allow`, the program's `http::Router`'s `r.allow`, and
passes it to `rest::no_method` and `rest::not_found`, which answer 405 or OPTIONS' 204
with it ahead of the generated path's methods it lacks. Passing the `Allow` rather than
the router keeps `dispatch` free of `http::Router`: a program without hand-written
routes calls it as before, and the generated routes pay one argument, read only on
their 405, 404, and OPTIONS answers.

Measured as in task 008, `bench/routes.sh`, the fix's `gen60` against the same servers
with it stashed (goose-rest `35cc5e3`), one after the other: MacBook Pro, Apple M1 Pro,
macOS 26.3.1 (Darwin 25.3.0), load average 5.8-8.9 from other work. Goose `46356c2`,
goose-http `e27ab21`, built with `goose build --standalone` (Apple clang 21, `-O2`),
serving with `http::serve_epoll` over kqueue, one worker. h2load 1.70.0 `--h1 -n 2000000
-c 256 -m 16 -t 8` with `count.sh`'s headers, on the same machine, nothing pinned; the
server's instructions retired from `/usr/bin/time -l`, kernel included, divided by the
requests. 3 rounds each, interleaving the servers. `gen60`'s instructions per request,
ranges over the rounds:

| Case | Before | After |
|---|---:|---:|
| First route | 18,208.6-18,219.5 | 18,182.1-18,220.8 |
| Last route | 19,847.7-19,887.1 | 19,871.6-19,884.5 |
| 404 in a scope | 19,673.3-19,685.6 | 19,663.1-19,684.1 |
| 404 outside | 18,534.6-18,543.6 | 18,531.9-18,541.7 |
| 405 | 19,988.9-20,012.3 | 20,013.5-20,027.0 |

The ranges overlap except the 405's, which costs 1 to 38 instructions more, 0.2% at
most: its check of the empty `allow`. `routes1_post`, which serves the same 405 without
the change, moved by at most 11 between the two runs.
