# 015: Win back the plan's API where Goose and goose-http now allow it

Status: todo (asked for 2026-10-14)

The plan (`docs/plan.md` in `923c4fb`) wrote handlers and the generated router in calls
that read as the route means. The built API drifted from them, call by call, as each
part met Goose or goose-http's API at the time:

| The plan | Built |
|---|---|
| `fn get_project(cx: rest::Cx&, app: App&, ...)` | `fn get_project(cx, state, ...)`: `Cx<S>` is generic in the per-request state |
| `cx.path`, `cx.is("GET")` | `http::path_of(cx.req.target)`, `cx.req.method == "GET"` |
| `return rest::route(cx) { app::health(cx, app) };` | `rest::route(cx) { app::health(cx, state); };` then `return;` |
| `rest::not_allowed(cx, "GET, HEAD")`, `rest::not_found(cx)` | `rest::no_method(cx, "GET, HEAD", allow)`, `rest::not_found(cx, m, path, allow)` |
| `rest::under(path, "/projects/")`, `rest::segment_int(cx, 10)` | `rest::segment(path, at)`, `rest::segment_is(seg, lit, plain)`, `rest::path_int(cx, seg, "id")` |
| A route in `handle` as a `rest::route` block | `var r = http::router(cx.req)`, `if http::on(r, ...)`, and `r` passed on for `rest::param(cx, r, "name")` |

The generated router's calls matter less than a program's: nobody writes them, and the
architecture doc shows them as they are. A handler's signature, the context's fields,
and hand-written routes are what a program reads and writes.

goose-http has worked on its own API since `e27ab21` (its task 027): `Request` helpers
by reference, an `Event` enum, a `Router` built once rather than per request, and a list
of rough edges found against goose-rest, among them a package helper for gathering a
long body, constants for `finish`'s fields, and a supported way to add a field to every
response. Some drifts may be undone by moving the goose-http pin; others by a change
there, which goes through goose-http's task 027.

For each row, record why it drifted (a Goose limit, goose-http's API, or a choice made
here), whether that still holds at the current pins, and what undoing it costs. A
change lands only if `bench/routes.sh` and task 010's tiers show no slowdown, as in
task 014, and the generated router stays at one route's cost.

## Baseline

`bench/routes.sh` measured only the generated router (`gen60`), so a change to
hand-written routes or `rest::serve` had no cell. `hand60` serves the same 60 routes
written by hand: `rest::serve_epoll`, `rest::scope` for each prefix, the routes in
`rest::route`, and each path parameter read with `rest::param_int` or `rest::param`. It
gives the same answers as `gen60`, but it checks no session and doesn't check a
parameter's bounds. The `query` case reads `GET /v1/projects`'s three query parameters.
`SERVERS="gen60 hand60"` runs only those cells, about 20 s at `N=200000` and `RUNS=1`
for a quick check before a full run.

Measured with `bench/routes.sh` at goose-rest `ecf42e4` plus `hand60`: MacBook Pro,
Apple M1 Pro, macOS 26.3.1 (Darwin 25.3.0), load average 5.6-7.0 from other work.
Goose `46356c2`, goose-http `e27ab21`, built with `goose build --standalone`, serving
with `http::serve_epoll` over kqueue, one worker. h2load 1.70.0 `--h1 -n 2000000 -c 256
-m 16 -t 8` with `count.sh`'s headers, on the same machine, nothing pinned; the server's
instructions retired from `/usr/bin/time -l`, kernel included, divided by the requests.
3 rounds, interleaving the servers. Instructions per request, ranges over the rounds:

| Case | `routes60` | `gen60` | `hand60` | One route |
|---|---:|---:|---:|---:|
| First route | 18,294.9-18,298.5 | 18,208.5-18,224.3 | 18,404.9-18,420.9 | 18,239.1-18,254.4 |
| Last route | 25,855.8-25,859.3 | 19,871.7-19,886.6 | 24,047.6-24,053.0 | 19,851.2-19,862.3 |
| 404 in a scope | 25,437.0-25,438.7 | 19,665.9-19,692.0 | 23,791.0-23,793.2 | 19,452.8-19,471.2 |
| 404 outside | 18,288.8-18,292.7 | 18,536.5-18,557.5 | 18,735.9-18,753.6 | 18,143.0-18,168.0 |
| 405 | 25,787.8-25,788.9 | 20,010.0-20,029.6 | 24,193.4-24,196.8 | 19,765.4-19,774.1 |
| Query | 18,973.4-18,978.7 | 20,062.8-20,083.1 | 20,919.0-20,976.0 | |

A hand-written route deep in the chain costs about 4,200 instructions more than a
generated one, since `http::on` tries each route before it. That's less than `routes60`
pays, because after `rest::scope` each `http::on` matches only the rest of the path.

## Acceptance criteria

- [ ] Each row above, and any drift found beside them, has its reason and whether it
      still holds at the current Goose and goose-http pins, checked by a spike where the
      answer isn't in the docs
- [ ] goose-http's task 027 changes and its rough-edges list are read for what they make
      possible here, and each that would help is named in this file
- [ ] A recommendation per drift: undo it, undo it after a goose-http change (proposed
      to its task 027, after asking first), or keep it, with the reason
- [ ] The drifts undone are built, with the tutorial, reference, examples, and
      generated code updated, and `bench/routes.sh` measured before and after, recorded
      here with how it was measured
- [ ] A Goose limit that keeps a drift is in `docs/goose-findings.md` with a minimal
      program
