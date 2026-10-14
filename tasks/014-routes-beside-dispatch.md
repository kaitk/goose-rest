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
- [ ] A test reproduces the 404 for another method of a hand-written route's path
- [ ] A path matched by hand-written or generated routes answers 405, and OPTIONS 204,
      with an `Allow` listing both
- [ ] `bench/routes.sh` shows no slowdown of the generated router, recorded here with how
      it was measured
- [ ] Tutorial section 7 and `docs/generator.md` describe the fix
- [ ] A helper answers a request's bytes through a block, gathering a long body as
      `rest::serve` does
- [ ] `test/test_router.goose` and `docs/tutorial/06-schema/test.goose` use it, and
      tutorial section 12 is written around it
- [ ] A test request without `Host` works, or fails with an error that says why
- [ ] The missing-handler error is shorter, or its noise is recorded in
      `docs/goose-findings.md` with a minimal program
