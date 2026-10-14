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

## macOS preview (2026-10-14)

Not results: macOS has no `perf`, so these counts include the kernel's instructions and
spread by about 30 per request between runs (goose-http's development.md, "macOS"). They
show where to look on Linux. Apple M1 Pro, macOS 26.3.1 (Darwin 25.3.0), load average
5-6; goose-rest `fe6cbf2`, Goose `0bdbd18`, both servers built with `goose build --cc
gcc --standalone` (Apple clang 21); one worker, epoll loop. Each case: h2load 1.70.0
`--h1 -n 2000000 -c 256 -m 16 -t 8` with count.sh's headers, the server under
`/usr/bin/time -l`, instructions retired divided by the requests, the median of 3
interleaved runs:

| Case | goose-http alone | goose-rest |
|---|---:|---:|
| Tier A `GET /api/items/1`, 200 | 20,151 | 20,126 |
| Tier A `GET /api/me` without a user, 401 | 20,362 | 20,657 |
| Tier A `GET /nothing`, 404 | 18,704 | 19,045 |
| Tier M `GET /api/items/1` without a token, 401 | | 24,871 |
| Tier F `GET /` | 17,980 (bare) | 18,007 |
| Tier F `GET /id/1?name=bun` | 18,667 (bare) | 18,940 |
| Tier R, route 1, `GET /authorizations`: if chain, generated | | 19,038, 18,604 |
| Tier R, route 201, `GET /user/keys/id201`: if chain, generated | | 61,284, 19,291 |

- On a tier A item, goose-rest costs nothing measurable over goose-http alone.
- Its 401 and 404 cost about 300 more, but answer with a JSON body where goose-http's
  server sends none, so the two aren't the same answer.
- Tier F's `/id` costs about 270 more through `rest::param` and `rest::query` than
  through goose-http's router and query; look at it with perf.
- The if chain pays about 210 instructions per route it passes, 42,000 more at route 201
  of 203, where the generated router stays flat; it costs 430 less on the first route
  too.
- Tier M's stack adds about 4,200 to a 401. `sample` puts it in the inlined middleware
  (Server-Timing's insertion and formatting, CORS), in field lookups
  (`http::authorization`, `http::field_in`) for the bearer token and Origin, and in
  reading the clock twice (`mach_absolute_time`).

## Acceptance criteria

- [x] goose-rest answers errors in a shape the program chooses
- [x] goose-rest gathers bodies larger than the read buffer up to a route's limit
- [x] goose-rest serves tiers A to D, and passes goose-http's `bench/rest/check.py`
      (macOS, 2026-10-14, both loops and both JSON ways)
- [x] Axum, actix-web, and dusty serve them through their routers, extractors, and
      middleware, built in release mode (`ReleaseFast` for dusty) in their fastest
      documented configuration, with the same worker count (macOS checks, 2026-10-14;
      each entry's `NOTES.md` has its configuration and the TechEmpower commit it follows)
- [ ] Where a framework answers an error before the handler (a 404, 405, or bad query)
      differently from the checker's expectation, the difference is recorded beside its
      rows, not worked around with a catch-all route (recorded in each entry's
      `NOTES.md`; goes beside the rows once there are results)
- [x] Tiers F, R, and M served by every framework, each with a checker
- [ ] Measured against goose-http alone with goose-http's `bench/rest.sh`, wrapped by
      goose-rest's `bench/rest.sh`, which runs tiers F, R, and M itself, after task 012
      so both Goose servers share the application code
- [ ] Instruction counts from `count.sh`
- [ ] Results in `docs/results.md`, with how they were measured, losses as plainly as
      wins, and a summary in the README
