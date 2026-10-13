# 010: Benchmark against goose-http, Axum, actix-web, and dusty

Status: in-progress

The framework's overhead is the number this design exists to keep small. Serve
goose-http's task 021 tiers on goose-rest, and on three frameworks used as their own
documentation shows: Axum and actix-web in Rust, and dusty in Zig (asked for
2026-10-13). goose-http's own REST server is the baseline without a framework.

Each framework uses its own router with a route per path, its own extractors or body
readers, and its own JSON, so that the run measures what a framework costs. goose-http's
`bench/rest/dusty` doesn't: one handler takes every path (`router.any("/*path")`) and
matches them itself. The framework entry starts from its records and handlers, and its
pins (dusty `ae164fa`, zio 0.19.1, Zig 0.16.0).

## Decided (2026-10-13)

- The servers: goose-http alone on both loops (`goose-epoll`, `goose-uring`), goose-rest
  on both (`goose-epoll-rest`, `goose-uring-rest`, the binary `rest-goose-rest`), Axum,
  actix-web, dusty with a route per path (`dusty-routes`), and goose-http's catch-all
  dusty and hyper as anchors to goose-http's 2026-10-13 tables. The pair of dusty entries
  prices dusty's router, its middleware, and its query and cookie readers, which the
  routed one uses and the catch-all doesn't (`bench/rest/dusty/NOTES.md`); the records,
  JSON, and body readers are the same.
- Axum and actix-web run in their TechEmpower entries' configuration: runtime layout,
  allocator, and release profile, each recorded with the commit it follows. goose-http's
  xitca-web entry follows its TechEmpower flags the same way.
- goose-rest answers errors in the shape a program chooses, so that tiers C and D, which
  want `{"error", "status"}`, pass as the frameworks' custom error types do. The default
  stays `{"error"}`.
- goose-rest gathers a body larger than goose-http's read buffer up to a limit the route
  sets, answers 413 from the head when `Content-Length` is over it, and then runs the
  route with the whole body. Until then such a body reached the route empty. Its tier D
  reads bodies whole, as tokio and odin-http do.
- Beyond tiers A to D, three tiers of goose-rest's own, run at saturation only, and
  `count.sh` on Goose builds. The tiers are below.

## Tier F: per-request framework cost

From the three tests of the bun-http-framework-benchmark, whose chart Elysia's README
shows. Small requests and answers, so routing, parameters, fields, and a JSON body
dominate. Each route is a cell of its own.

| Request | Response |
|---|---|
| `GET /` | 200 `text/plain`, `Hi` |
| `GET /id/{id}?name={name}` | 200 `text/plain`, `{id} {name}` with `name` decoded, and `x-powered-by: benchmark` |
| `POST /json`, a JSON object of about 200 bytes | 200 `application/json`, the body read into the language's JSON value and written back, members in order |

goose-http alone serves it too, as the baseline.

## Tier R: routing at scale

The GitHub API's 203 routes from julienschmidt's go-http-routing-benchmark, each answering
200 `text/plain` with the route's number and its parameters, separated by spaces. The
load requests every route in a fixed shuffled order. goose-rest serves it twice: through
an `http::router` if chain in the list's order, and through the router the generator
writes from an OpenAPI document of the same routes.

## Tier M: a middleware stack

Tier A with three middlewares around every route, each the framework's own: a
`Server-Timing: app;dur=<ms>` field without an access log, CORS for
`https://app.example`, and a bearer check that answers 401 without a token. The load is
tier A's with an `Origin` field. Compared with tier A, it prices the stack.

## Instruction counts

`count.sh`, on Linux, on goose-http and goose-rest serving the same request: a tier A
item (200), `/api/me` without a user (401), an unknown path (404), a malformed path
parameter (400), and tier M's item. Both share the HTTP layer, so the difference is the
framework's. It compares Goose builds only.

## Acceptance criteria

- [x] goose-rest answers errors in a shape the program chooses
- [x] goose-rest gathers bodies larger than the read buffer up to a route's limit
- [x] goose-rest serves tiers A to D, and passes goose-http's `bench/rest/check.py`
      (macOS, 2026-10-14, both loops and both JSON ways)
- [ ] Axum, actix-web, and dusty serve them through their routers, extractors, and
      middleware, built in release mode (`ReleaseFast` for dusty) in their fastest
      documented configuration, with the same worker count
- [ ] Where a framework answers an error before the handler (a 404, 405, or bad query)
      differently from the checker's expectation, the difference is recorded beside its
      rows, not worked around with a catch-all route
- [ ] Tiers F, R, and M served by every framework, each with a checker
- [ ] Measured against goose-http alone with goose-http's `bench/rest.sh`, wrapped by
      goose-rest's `bench/rest.sh`, which runs tiers F, R, and M itself
- [ ] Instruction counts from `count.sh`
- [ ] Results in `docs/results.md`, with how they were measured, losses as plainly as
      wins, and a summary in the README
