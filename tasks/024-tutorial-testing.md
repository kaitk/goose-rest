# 024: Test the tutorial's application, without sockets and over HTTP

Status: todo (asked for 2026-10-15)

The tutorial's page 9 tests part one's schema program with `rest::serve_one` and
`requests.sh`, and page 13 calls a service's use case as a plain function. Part two's
application, with its services and limits, has no page on how to test it as a whole. A
developer coming from Axum or Express needs both on the same application: socketless
tests of routes and use cases, and integration tests against the running server,
including a service's answers, a 503, a 504, and a client that has gone.

## Acceptance criteria

- [ ] The tutorial shows tests of part two's application without sockets: routes through
      `rest::serve_one`, and use cases as plain calls, with where each fits
- [ ] It shows integration tests against the running server, as `requests.sh` and
      `scripts/test-examples.sh` run them, and what timing-dependent cases need
- [ ] Each test is code `scripts/test.sh` runs
