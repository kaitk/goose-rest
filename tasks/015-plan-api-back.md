# 015: Win back the plan's API where Goose and goose-http now allow it

Status: in-progress (asked for 2026-10-14). The inventory is done; the
recommendations wait on the maintainer before anything public changes.

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
change lands only if `bench/routes.sh`, `bench/stack.sh`, and task 010's tiers show no
slowdown, as in task 014, and the generated router stays at one route's cost.

The plan is a starting point, not the target (2026-10-14). Any change that makes the API
more concise is welcome, even where it departs from the plan, if it:

1. Doesn't make a real application harder to write: one whose routes do more than the
   simple cases. Shorthand for simple cases is welcome when it's general enough.
2. Doesn't slow the hot path. A small cost can be accepted for a large gain in
   readability, but only when the gain is shown and the cost is measured.

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

`bench/routes.sh` sends only GETs, since h2load's POSTs run at a tenth of its GETs'
rate. `bench/stack.sh` covers a JSON body and the middleware stack instead. It runs
task 010's server (`bench/rest/goose-rest/main.goose`) under wrk, which sends POSTs at
full rate, with each connection pipelined 16 deep. Unpipelined, the kernel's share is
about 250,000 instructions per request, ten times the server's. The `item` and `post`
cases send the same request to tier A and to tier M, which wraps tier A's routes in
`rest::timed` (without its log), `rest::cors`, and `rest::bearer`, so the difference
between the two is the stack's cost.

Measured with `bench/stack.sh` at goose-rest `028af19` on the same machine and pins as
above, load average 9.4-16.1 from other work: one worker, wrk 4.2.0 `-t 8 -c 256 -d 10`,
pipelined 16 deep, nothing pinned. The server's instructions retired
from `/usr/bin/time -l`, kernel included, less those of the same server started and
stopped without load, divided by wrk's request count. 3 rounds, interleaving the cells:

| Case | Tier | Instructions per request | req/s |
|---|---|---:|---:|
| `POST /json`, 159 bytes, `rest::take` | F | 26,151.6-26,153.7 | 503,889-506,574 |
| `GET /api/items/42` | A | 20,703.1-20,787.0 | 519,832-556,118 |
| The same, inside the stack | M | 32,792.6-33,139.0 | 407,675-415,738 |
| `POST /api/items/7`, 51 bytes | A | 21,449.8-21,457.6 | 549,827-556,656 |
| The same, inside the stack | M | 30,407.1-30,596.2 | 427,559-434,644 |

The stack costs about 12,100 instructions per request on the GET and 9,000 on the POST,
and a quarter of the GET's throughput. That's more than a 60-route chain costs, so
middleware is worth a look within this task.

### The goose-http pin moved to `cb57a0b`

goose-http's `main` at `cb57a0b` (2026-10-14) holds task 027's p2 to p6 and review items
1, 2, 4, and 6 to 11. Here, `http::stop_on_signals` and `http::mail_open` now return an
`http::Error`, so each `main` calls `http::exit_on_error`. A mailbox message longer than a
slot now returns `TOO_LONG` rather than `FULL`, so `rest::answer` gives up on one, where
it retried it forever.

Measured as the baseline above, at `faa6b69` with the pin moved against those tables, on
a machine far busier than then: load average 13-31. `bench/routes.sh`, the mean of 3
rounds' instructions per request:

| Case | goose-http alone | `gen60` | `hand60` |
|---|---:|---:|---:|
| First route | +32.9, +54.9 | +32.7 | +5.6 |
| Last route | +20.7, +60.1 | +23.7 | +3.1 |
| 404 in a scope | +48.8, +68.6 | +40.2 | +5.2 |
| 404 outside | +51.7, +45.2 | +31.3 | +8.5 |
| 405 | -42.0, +56.9 | +46.1 | +3.3 |
| Query | +57.9 | +38.1 | +11.5 |

goose-http alone is `routes60`, then the one-route server. Every cell but `routes60`'s
405, whose rounds spread over 270, sits above its old range: goose-http's request path
costs 45-70 instructions more on kqueue, 0.3%, and `gen60` pays most of that. `hand60`
moves by 3-12. `bench/stack.sh`'s cells stay within their old ranges, from -33 to +110
of 20,700-33,000.

## Inventory

Why each drift happened, and whether the reason still holds at Goose `46356c2` and
goose-http `cb57a0b` (read 2026-10-14). Spike 08 checked what the docs didn't settle.

### The table's rows

1. **Handler signature, `cx, state` for `cx: rest::Cx&, app: App&`.** A choice made
   here. `Cx<S>` is generic in the per-request state, since `cx.state` has the
   program's type and `rest::error_body` is overloaded by it (tasks 004 and 010). An
   untyped `cx` is how Goose writes a generic parameter. `state` is the name the
   generated router gives whatever the program passes to `dispatch`; a handler names
   and types its own parameter, as `state: App&`. Still holds, but a program can now
   name the context: `type Cx = rest::Cx<St>;` and `cx: Cx&` (spike 08).
2. **`http::path_of(cx.req.target)` and `cx.req.method == "GET"` for `cx.path` and
   `cx.is("GET")`.** A choice made here, in generated code only. The router computes
   the path once into a local and compares the method directly, at no cost. Still
   holds.
3. **`rest::route(cx) { ... };` then `return;` for `return rest::route(cx) { ... };`.**
   A Goose limit, in generated code only: "cannot return a valueless expression". Still
   holds ([findings](../docs/goose-findings.md#a-function-cant-return-a-valueless-call)).
4. **`rest::no_method(cx, "GET, HEAD", allow)` and `rest::not_found(cx, m, path, allow)`
   for `rest::not_allowed` and `rest::not_found(cx)`.** A choice made here, in
   generated code only. `allow` carries the `Allow` of hand-written routes before
   `dispatch` (task 014), and `m` and `path` are the locals the router already has.
   Still holds.
5. **`rest::segment`, `rest::segment_is`, and `rest::path_int` for `rest::under` and
   `rest::segment_int`.** A choice made here, in generated code only. Walking segments
   lets a literal match an escaped byte as `http::on` does, and a typed parameter fail
   with its name (task 008). Still holds.
6. **`var r = http::router(cx.req)`, `http::on(r, ...)`, and `r` passed on, for routes
   taking `cx` alone.** goose-http's API: a route's parameters and `Allow` live in the
   `http::Router` the program builds, and `Cx` doesn't hold one, since a program served
   by the generated router needs none. So each function of hand-written routes takes
   `cx`, the program's state, and `r`, and each extractor of a path parameter takes `r`
   too: `rest::param_int(cx, r, "id")`. The reason no longer holds: spike 08 puts an
   optional router in `Cx`, which `rest::routes(cx) { cx => ... }` sets, so a program
   that never calls `routes` builds none. One store needs a helper there
   ([findings](../docs/goose-findings.md#a-store-through-an-optional-field-is-charged-to-the-structs-other-references)).
   goose-http's "Router built once" (task 027) is blocked on Goose, and doesn't change
   this.

### Found beside them

7. **The worker's state, passed beside `cx` to every handler and helper.** The plan's
   own design, `fn get_project(cx: rest::Cx&, app: App&, ...)`, as Actix's `web::Data`
   is an argument. Every function a route calls takes it, `find_project(cx, app, id)`,
   and the generated router passes it on. Spike 08 shows `Cx` can hold a reference to it
   beside the per-request state, `cx.app`.
8. **`rest::route` written in hand-written routes.** The plan wrote it only in the
   generated router. A program without a schema opens one route per request itself,
   inside `timed` and `cors` and around the code that fails (task 006): a route nested in
   a route stays out of line (architecture doc, "Inlining"). Still holds. A `routes` block
   could be that route too.
9. **`rest::cors(cx, rest::Cors { origins: "...", .. })` for `rest::cors(cx,
   ALLOWED_ORIGINS)`.** A choice made here, for the methods, headers, credentials, and
   max age a real API sets (task 006). Still holds.
10. **No `cx.now`.** The plan's security check compared a session's expiry with
    `cx.now`. A choice made here: nothing built needed a clock per request. Still holds.
11. **An empty answer takes two goose-http calls**: `http::start(cx.out, 204);
    http::finish(cx.out, "", "");` in `examples/plain`. goose-http's API: `http::respond`
    always writes a `Content-Type`. goose-http's fix is on `findings-46356c2-hot` and
    `api-hot`, not on `main`; goose-rest can add its own answer without either.
12. **Middleware costs 12,000 instructions a GET** ("Baseline"). Measured alone on tier
    M's GET and POST: `timed` costs 5,200 and 2,000, `cors` 3,750 and 3,500, and
    `bearer` 1,700 and 2,000. `timed` moves the whole written response a byte at a time
    to insert `Server-Timing`, since Goose has no move within an array (goose-http's
    findings, "Moving bytes up within an array takes a byte loop"), so a larger
    response costs more. `cors` looks for `Access-Control-Request-Method` on every
    request with an `Origin`, a GET's too, and formats its fields per request. Choices
    made here, in the implementation; the API needn't change.
13. **goose-rest's own copies of what goose-http's `main` now has.** goose-http's API at
    `e27ab21` lacked them; `cb57a0b` has them: `http::gather` for `runtime.goose`'s body
    gathering (about 70 lines), `http::insert_field`, `http::bearer` for
    `rest::bearer_token`'s parsing, `http::JSON` and `http::TEXT` for the raw
    `"Content-Type: ...\r\nContent-Length: "` strings, and `http::mail_slot_size` for
    the slot size `rest::ask` sends in each job.
14. **UFCS.** Not a drift from the plan, which named the namespace too, but the one
    change that would shorten every call: `cx.text(200, "ok")` for `rest::text(cx, 200,
    "ok")`. A Goose limit: UFCS looks in the caller's namespace, not the type's (spike 08,
    [findings](../docs/goose-findings.md#ufcs-doesnt-reach-the-namespace-of-the-receivers-type)).
15. **`rest::take<T>(cx)` with `T` explicit.** The plan's own. A Goose limit:
    `let v: T = rest::take(cx)` can't infer `T` (spike 08). Still holds.

## Acceptance criteria

- [x] Each row above, and any drift found beside them, has its reason and whether it
      still holds at the current Goose and goose-http pins, checked by a spike where the
      answer isn't in the docs
- [x] goose-http's task 027 changes and its rough-edges list are read for what they make
      possible here, and each that would help is named in this file
- [ ] A recommendation per drift: undo it, undo it after a goose-http change (proposed
      to its task 027, after asking first), or keep it, with the reason
- [ ] The drifts undone are built, with the tutorial, reference, examples, and
      generated code updated, and `bench/routes.sh` measured before and after, recorded
      here with how it was measured
- [x] A Goose limit that keeps a drift is in `docs/goose-findings.md` with a minimal
      program
