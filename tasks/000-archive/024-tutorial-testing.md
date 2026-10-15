# 024: Test the tutorial's application, without sockets and over HTTP

Status: done (2026-10-15; asked for 2026-10-15)

The tutorial's page 9 tests part one's schema program with `rest::serve_one` and
`requests.sh`, and page 13 calls a service's use case as a plain function. Part two's
application, with its services and limits, has no page on how to test it as a whole. A
developer coming from Axum or Express needs both on the same application: socketless
tests of routes and use cases, and integration tests against the running server,
including a service's answers, a 503, a 504, and a client that has gone.

The page is 16, "Testing the application", after Limits, since it tests what pages 13
to 15 build; Embedded Linux moved to 17 (2026-10-15). Page 13's routes moved to
`13-waiting/app.goose`, apart from `main`, so that `test.goose` imports them.

`serve_one` runs no loop, so it can't drive a route past `rest::ask`: the job reaches
the box and the answer is 500; the case functions, `rest::relay`, 504, and a client
that has gone are tested over HTTP only. A `serve_one` that, after a route asks, called
the handler again with a reply the test gives (a `WAKE` event) would make the case
functions testable without sockets; not added.

## Acceptance criteria

- [x] The tutorial shows tests of part two's application without sockets: routes through
      `rest::serve_one`, and use cases as plain calls, with where each fits
- [x] It shows integration tests against the running server, as `requests.sh` and
      `scripts/test-examples.sh` run them, and what timing-dependent cases need
- [x] Each test is code `scripts/test.sh` runs
