# 12: Shorter routes

Checks task 056.01's shorter routes (`tasks/056-aegon-ideas/01-compact-routes.md`)
against today's form, without changing the package. Today a program writes
`if rest::on(cx, "GET", "/p") { rest::route(cx) { ... }; } else { rest::otherwise(cx); }`.
The shorter form is `rest::get(cx, "/p") { ... };`, and `rest::routes` answers 404, 405,
501, and OPTIONS itself.

The bar for adopting it: one form that works everywhere, scopes behind middleware
included, that answers as today's form does and costs no instructions beyond the
spread of the runs (2026-10-20).

- `compact.goose` is design A. `routes` opens the request's one route around its block.
  `get` and its kin only match, run their block, and leave `routes`. `route` inside
  `routes` joins that route rather than opening a second.
- `marked.goose` is design B. `routes` opens no route. `route` hands its block a context
  whose router type is marked, `Routed`, and `get` and its kin are overloaded on the
  context. Given `routes`' context, they match, open a route of their own, and leave
  `routes`. Given a route's, they only match, run their block, and leave the route.
  Every call that reads the router has an overload for `Routed`.
- In both, `routes` answers after its block only when the response is still empty,
  nothing waits (`stream.waiting`), and the exchange expects no later call
  (`ex.mode & rest::LATER`), the same test that serve's `settle_kept` makes. So code
  that answers and returns normally doesn't get a second answer: today's
  `if rest::on(...)` routes, a scope's own `rest::otherwise`, and middleware that
  answers early.

`main.goose` answers each request with today's form, A, and B, and compares the whole
answers. `chain.goose` holds four routes and a scope behind `rest::bearer` in the three
forms, for their C. The 60-route servers are `bench/routes/hand60.goose` (today's form),
`short60.goose` (A), and `short60b.goose` (B), each with `/v1/reports` behind a
middleware that can fail. `bench/routes.sh` at commit `0fda9a2` builds and runs them.
Later commits leave them out, so that a full run doesn't measure a form not adopted.

Goose: commit `f114b5a`, the pin. goose-http: `b5f82a2`, with the same output as at `v0.4.3`. goose-rest: `6ea1377`.

`genroutes.sh` writes a larger program in today's form or A, of 1,111 routes by default
and 5,001 with nested middleware, and `benchroutes.sh` builds both forms and counts them
([Larger programs](#larger-programs)).

```sh
GOOSE=$(../../scripts/goose.sh)
$GOOSE main.goose
$GOOSE -O2 -o chain.c chain.goose
./benchroutes.sh   # macOS
```

## Verdict

Under the first bar, neither design is adopted. Both designs give one form that works everywhere and answers as today's form does. Both
cost instructions beyond the runs' spread on the 60-route chain. A costs +42 to +164
per request (+0.2 to +0.9%). B costs +26 to +83 in a scope behind its route (+0.1 to
+0.4%), and B changes the signatures of every call that reads the router. The first
version of this spike kept today's `rest::route` per route and had no added cost, but
in a scope behind middleware it needed today's form. That made two forms, and the wrong
one there goes out of line without a word.

The bar changed on 2026-10-20: a reasonable cost is acceptable for the shorter form. A's
cost is a fixed 57 to 165 instructions per request, whatever the number of routes: +0.2
to +0.7% at 1,111 routes and +0.2 to +0.6% at 5,001 with nested middleware. Adopting A
waits on agreeing that cost.

### Answers

All 30 requests get the same bytes from the three forms: routes that match, a failure
three calls down, 404, 405 with `Allow`, OPTIONS, 501, 400 for a dot-segment, a guard, a
body of 100,000 bytes gathered over two calls, and an answer a lane gives at a later
WAKE (`/slow`, and `/old/slow` in today's form inside the shorter one). The short form
inside scopes includes `/reports`, behind `rest::bearer`, and `/team`, behind a stack of
the program's own: 200, bearer's 401, 404, and 405. Those come from both A and B.

```text
POST /projects/7 HTTP/1.1 -> HTTP/1.1 405 Method Not Allowed
  Allow: GET, HEAD, DELETE
GET /reports/daily HTTP/1.1 -> HTTP/1.1 401 Unauthorized
POST /reports/daily HTTP/1.1 -> HTTP/1.1 405 Method Not Allowed
  Allow: GET, HEAD
```

A guard is an `if` around the routes it guards, `if admin(cx) { get(cx, "/admin") { ... }; }`,
in both designs. It's checked before the path, so a failed guard hides the route from
the 405's `Allow`. Today's form answers that way too when the guard comes first,
`admin(cx) && rest::on(...)`, as `main.goose` writes it. With
`rest::on(...) && admin(cx)`, a `POST /admin` from a non-admin gets 405, not 404.

### Instruction counts

`bench/routes.sh` at `0fda9a2`, full runs with `SERVERS="hand60 short60 short60b"`.
Each round is 2,000,000 requests per case, and the rounds interleave the servers. One
worker, `h2load --h1 -c 256 -m 16 -t 8`, Apple M1 Pro, macOS 26.3.1, Darwin 25.3.0,
h2load nghttp2/1.70.0, 2026-10-20, load average 4.2 at the start and 5.0 at the end.
On macOS, instructions retired include the kernel's
([bench/README.md](../../bench/README.md#instruction-counts-on-macos)).

| Case | Today (hand60) | A (short60) | B (short60b) |
|---|---|---|---|
| first, `/health` | 18,060 / 18,138 / 18,130 | 18,305 / 18,261 / 18,253: +164 | 18,084 / 18,152 / 18,158: +22 |
| last route | 24,448 / 24,449 / 24,442 | 24,506 / 24,502 / 24,498: +56 | 24,536 / 24,525 / 24,523: +82 |
| 404 in the last scope | 24,203 / 24,200 / 24,200 | 24,251 / 24,247 / 24,244: +46 | 24,231 / 24,225 / 24,226: +26 |
| 404 outside every scope | 18,466 / 18,458 / 18,458 | 18,550 / 18,558 / 18,569: +98 | 18,450 / 18,459 / 18,445: −9 |
| 405 in the last scope | 24,544 / 24,541 / 24,544 | 24,604 / 24,603 / 24,604: +61 | 24,579 / 24,572 / 24,571: +31 |
| query, `GET /v1/projects?...` | 20,642 / 20,644 / 20,671 | 20,691 / 20,698 / 20,694: +42 | 20,742 / 20,735 / 20,729: +83 |

Instructions per request in each round, and the difference of the means from today's.
Within a server, the rounds differ by at most 30, except in the first case: 78 for
today's form, 52 for A, and 74 for B. Every difference of A's is above that. B's
differences are within it outside `/v1`, on `/health` and the 404 outside every scope,
and above it in `/v1`, the scope behind its route. An earlier run of today's form
against A alone, at load average 10, gave +45 to +170. The +170 came with one low
round of today's form.

### Larger programs

A's cost doesn't grow with the program. `genroutes.sh` writes `/health` and areas of
scopes of 10 routes each, each scope a function of its own, as a program keeps a
module's routes. Four routes in ten are GETs, and seven take a path parameter. The first
area, `/public`, has no middleware. Every other area is behind a check that can fail.

- **1,111 routes**: 3 areas of 37 scopes, about a mid-sized REST API's 370 routes three
  times over.
- **5,001 routes**: 10 areas of 50 scopes, with middleware nested as an application's
  roles nest it (`ROLES=1`). Two scopes in three outside `/public` are behind a role,
  and their PUT and DELETE routes are behind a permission besides. Each is an `inline fn`
  that reads a header and can fail.

Both forms give the same bytes for every request checked: 15 at 1,111 routes, and 22 at
5,001 with the role's and the permission's 403s.

| Case | 1,111: today | 1,111: A | 5,001: today | 5,001: A |
|---|---|---|---|---|
| first, `/health` | 18,141 | 18,247: +106 | 18,131 | 18,247: +116 |
| a route in the middle area | 23,645 | 23,705: +60 | 28,912 | 28,969: +57 |
| last route | 28,616 | 28,682: +66 | 37,358 | 37,516: +158 |
| 404 in the last scope | 28,498 | 28,569: +71 | 37,243 | 37,409: +165 |
| 404 outside every scope | 18,774 | 18,909: +135 | 19,999 | 20,083: +84 |
| 405 in the last scope | 28,870 | 28,942: +73 | 37,609 | 37,772: +163 |

The means of three rounds of `benchroutes.sh` at goose-rest `2a37ee0`, with the pin.
Each round is 2,000,000 requests per case, and the rounds interleave the forms. One
worker, `h2load --h1 -c 256 -m 16 -t 8`, Apple M1 Pro, macOS 26.3.1, Darwin 25.3.0,
h2load nghttp2/1.70.0, 2026-10-20. Load average was 5.5 to 5.1 for 1,111 routes, and 3.6
to 4.0 for 5,001. Within a server, the rounds differ by at most 16 at 1,111 routes, and
by at most 18 at 5,001. The 5,001-route run is
`AREAS=10 MODULES=50 ROLES=1 MIDDLE=/specialist/work-hour LAST=/admin/practitioner-2 ./benchroutes.sh`.

The same runs' requests per second agree with the instruction counts within 1% at
1,111 routes. At 5,001 routes, A takes 6 to 7% more cycles per request than today's form
in `/admin`, the last area, and answers 6% fewer requests per second there, for 0.4%
more instructions. That binary's layout is the likely cause rather than the design.
Quick runs (2 rounds of 1,000,000 requests) repeat the loss with the same build, but
show none at 4,901 routes with roles, or at 5,001 without them: within 1% in every
case. Each binary's layout differs, and the build can land either form on a slow one.

| | 1,111: today | 1,111: A | 5,001: today | 5,001: A |
|---|---|---|---|---|
| build | 4.5 s | 4.8 s | 14 s | 17 s |
| binary | 368 KB | 371 KB | 1,339 KB | 501 KB |

In A, every scope's function stays a call: a `get` adds a match, its block, and a
`return from routes`, which takes a 10-route scope past the size limit for a function
called once. In today's form, Goose inlines every scope at 1,111 routes, and at 5,001
keeps 306 of the 500 as calls, the scopes behind a role. Why A's binary at 5,001 routes
is less than half the size of today's, with C of 13.3 MB against 14.6 MB, isn't
measured.

### The REST benchmark

On branch `routes1100`, the REST benchmark's goose-rest server serves tiers A, F, M, and
R in design A with `FORM=short`, chosen once per worker. `bench/rest.sh` names it
`goose-uring-rest-short` and `goose-epoll-rest-short`, and `count` counts it beside
today's form. Tier R's chain in A, `app::chain_short`, is 203 `compact::get` and kin
that `github_goose.py` writes. Both forms pass the tiers' checkers on macOS.

A quick count on macOS, with the server built there without its `mallopt` call: two
rounds of 500,000 requests per case, one worker on epoll, `h2load --h1 -c 256 -m 16 -t 8`,
Apple M1 Pro, 2026-10-20.

| Case | Today | A |
|---|---|---|
| tier A, `GET /api/items/1` | 19,522 / 19,531 | 19,509 / 19,518 |
| tier M, `GET /api/items/1` | 22,907 / 22,905 | 22,904 / 22,905 |
| tier R, route 201 of 203, `GET /user/keys/:id` | 61,583 / 61,585 | 57,263 / 57,265 |

Tier R's A runs 4,320 fewer instructions per request (7%). Both match through `http::on`.
Today's chain is 203 nested `else if` blocks, and A's is 203 statements in a row. Why
that costs today's form more isn't measured.

On Linux with io_uring, A serves tiers R and M as fast as today's form: every
difference in requests per second is within the rounds' spread. The instruction counts
there don't repeat macOS's. On tier R, A saves 74 instructions per request, not 4,320.
On tier M, A costs 431 more (+8.6%), where macOS showed no difference. Neither
difference is explained yet.

Tier R, every GitHub route, requests per second:

| Server | Round 1 | Round 2 | Round 3 | Mean | A against today's |
|---|---:|---:|---:|---:|---:|
| goose-uring-rest (today's) | 316,522 | 315,209 | 321,309 | 317,680 | |
| goose-uring-rest-short (A) | 318,653 | 316,273 | 331,265 | 322,063 | +1.4%, within the spread |
| goose-uring-rest-gen | 433,578 | 437,606 | 449,747 | 440,310 | |

Tier M, beside tier A, requests per second:

| Server | Case | Round 1 | Round 2 | Round 3 | Mean | A against today's |
|---|---|---:|---:|---:|---:|---:|
| today's | a | 404,328 | 527,226 | 549,832 | 493,795 | |
| A | a | 523,622 | 532,774 | 541,224 | 532,540 | +7.8%, within the spread |
| today's | m | 415,833 | 430,967 | 477,261 | 441,354 | |
| A | m | 459,276 | 463,309 | 469,482 | 464,022 | +5.1%, within the spread |

The rounds of today's form vary most. Its round 1 on case `a` is 404K against 527K and 550K.
Without that round, A is 1.1% below today's form on case `a`.

User instructions per request, from `bench/rest.sh count`, one run each. A run repeats
to within 0.1 instructions ([goose-http's `bench/count.sh`](https://github.com/kaitk/goose-http/blob/v0.4.3/bench/count.sh)):

| Case | Today's | A | A against today's | Generated router |
|---|---:|---:|---:|---:|
| tier R, route 201 of 203, `GET /user/keys/id201` | 39,065.4 | 38,990.9 | −74.5 (−0.2%) | 3,232.4 |
| tier M, `GET /api/items/1` | 5,030.4 | 5,461.4 | +431.0 (+8.6%) | |
| tier A, `GET /api/items/1` | 4,271.4 | 4,242.4 | −29.0 (−0.7%) | |

How it was measured, on 2026-10-20: Tiamat, an AMD Ryzen 7 5800X3D with 16 logical
CPUs, WSL2 kernel 6.18.54.1-microsoft-standard-WSL2, wrk 4.1.0 with
`wrk-monotonic.so`. The command was
`TIERS="r m" STEPS=none RUNS=3 EXTRA="goose-uring-rest goose-uring-rest-short" bench/rest.sh run`,
at goose-rest `9beacff`, with goose-http `v0.4.3` and Goose `f114b5a`. Each server ran
4 workers on CPUs 0 to 3. wrk ran on CPUs 4 to 15 with 8 threads and 256 connections,
for a 5 s warm-up and then 15 s per cell. The 3 rounds interleaved the servers. The
counts came from `bench/rest.sh count`, run as root. The machine wasn't idle: other
sessions were working in WSL. The 1-minute load average was 0.24 before the run, with
Windows CPU at 23%, and 10.11 after it, with Windows CPU at 5%. It was 1.78 after the
counts. The result directory is `bench/results/2026-10-20T2001-rest-Tiamat`. Its
`env.txt` shows goose-rest as blank and modified. That's wrong: the run used a
worktree that Windows Git created, and WSL's Git can't read it.

- **A.** The request's one route wraps all of `routes`' block, so every request pays
  for calling `route` and `attempt`. Today's form answers `/health` and the 404 outside
  every scope with no route at all. A route that matched also leaves through
  `return from routes`, past `attempt`, `route`, and `routes`, and each of them checks a
  discriminant.
- **B.** Each route builds a second context with the marked router type, about 15
  fields. Every match inside it then reads the router through one more reference. The
  last route is 59 matches in, and the query case reads its parameters through the
  marked context too.

### Which routes stay out of line

In the 60-route C, no route of any form stays out of line. Each form keeps the same
chain of calls: `routes`, `route`, `attempt`, and the scope function `v1`, with the
extractors as leaves (`param_int` and `param`). The spike's `routes` in A and its
`route` in B hold `rest::routes`'s and `rest::route`'s bodies rather than calling them,
so each chain is as deep as it would be adopted. The first version of this spike kept
`GET /projects` and one `DELETE` out of line, each with a discriminant check after the
call.

The inliner's size limit for a function called once isn't what keeps the chain. A Goose
build of `1e31b6d` with no such limit inlines `v1` into `attempt`, but `routes`, `route`,
and `attempt` stay calls in both forms. `attempt` stays a function because extractors
left as calls return from it: `rest::param_int` (33 calls) and `rest::param` (7) are
too large to inline at that many call sites, and Goose inlines no function with two
results, such as `rest::query_int`. `route` and `routes` then stay calls, because each
hands the next a block that reads its locals. With the limit removed, the extractors
`inline fn`, and the query readers unable to fail, both forms compile to one `handle`
function. That costs more than the chain in `/v1`: +126 to +172 instructions per
request for today's form, and +104 to +157 for A, on the run below. Outside `/v1`, today's
form costs 26 to 35 more, and A gains 21 to 55.

| Case | Today | Today, one function | A | A, one function |
|---|---|---|---|---|
| first, `/health` | 18,125 | 18,160 | 18,238 | 18,183 |
| last route | 24,435 | 24,561 | 24,484 | 24,588 |
| 404 in the last scope | 24,194 | 24,335 | 24,234 | 24,386 |
| 404 outside every scope | 18,455 | 18,481 | 18,555 | 18,534 |
| 405 in the last scope | 24,536 | 24,708 | 24,590 | 24,747 |

The means of three rounds of `bench/routes.sh` at `0fda9a2`, interleaved, set up as in
[Instruction counts](#instruction-counts), at load average 3.3 to 3.8. Today's form and
A are built with the pin, and the one-function columns with the `1e31b6d` build. Within
a server, the rounds differ by at most 30. The query case is left out: the probe's
query readers did less work.

In `chain.goose`'s C, each form is one function: `long_g` (908 lines), `short_g` (A, 725
lines, with one route's error handling where today's has five), and `short_b_g` (B,
1,097 lines). They make the same calls in the same order: the matches, `header` for the
guard, `narrowed` for the scope, and `otherwise`.

Design A needs one workaround. Its `get` ran the block and returned in one arm, and
Goose inlines a function called in such an arm only below half the usual size
([findings](../../docs/goose-findings.md#a-block-that-ends-in-a-return-keeps-its-calls-out-of-line)).
`rest::param_int` in the block then stayed a call. A function that fails and stays a
call keeps its route and everything around the route out of line, so all of `chain.goose`'s
short form stayed out of line. `on` now runs the block and returns in separate arms.

### What B costs in signatures

- `rest::route`'s block takes the context, `rest::route(cx) { cx => ... }`, in every
  program. So does a stack's: a program's own middleware that opens the route passes it
  on, `F(cx)`.
- `rest::on`, `rest::scope`, `rest::param`, `rest::param_int`, the other path
  extractors, and `rest::otherwise` each gain an overload for the marked type.
  Generated dispatch reaches them through those overloads.
- A helper typed through an alias needs a second alias for a route's context,
  `rest::Cx<St, App, rest::Routed>`.
- Code inside a route's block that names the outer `cx` still compiles, and a `get`
  there opens a second route, out of line. That's the hazard B was meant to remove.

## Skip-based routing (2026-10-21)

Adopted with block scopes only, on 2026-10-21
([decisions](../../docs/decisions.md#the-api)): the package has no `bool`
`rest::scope` now. The spike's programs that still use one, in today's form and in
`if` chains, call `compact::scope`, the same function kept in `compact.goose`.
`chain.goose` builds only against the package at `0fda9a2`, where its counts come
from.

Design A's `rest::get` leaves through `return from routes`, which skips the work of
any middleware between it and `rest::routes`, and a failure inside a scope's
middleware is answered outside it (task 056.01's snags 1 and 2; `after_block.goose`
shows both on design A). Skip-based routing keeps A's syntax and drops the
long-distance return:

- A matched `rest::get` and its kin mark the request taken and return as any block
  does. The mark is goose-http's `Router.bad`, which `http::on` and `rest::scope`
  check first, so the routes and scopes after it don't match. No field or type is
  added. `rest::routes` doesn't give its default answer when a route that matched
  chose to answer nothing.
- `rest::scoped(cx) { ... };`, inside `rest::routes`, runs its block as a route of its
  own, gives `rest::routes`' default answer when the block left the request
  unanswered, and takes the request. Outside `rest::routes` it only runs the block.
  `rest::cors`, `rest::timed`, `rest::security_headers`, and `rest::compressed` run
  their block in it, so each keeps one name and works in both places, and a
  program's middleware can build on it.
- `rest::scope(cx, "/p") { ... };`, a block form beside today's `bool` one, owns its
  prefix: it gives the default answer when its block answered nothing, and takes the
  request (snag 3).
- The generated `dispatch` answers nothing when a route before it took the request.

`skip.goose` answers 30 requests, and `after_block.goose`'s four cases now answer as
today's form does. Checked:

- Each of goose-rest's four middleware in a scope: 200, a failure, 404, and 405, with
  the middleware's fields, and `compressed`'s 405 with the scope's `Allow`.
- `test/middleware/later_routes.goose`: `later.goose`'s cases with the middleware
  inside `rest::routes`. The fields are kept for an answer at WAKE and at TIMEOUT,
  and for a body gathered first.
- `test/router/beside_dispatch_short.goose`: `rest::put` and `rest::post` before
  `api::dispatch`, with the same answers as `beside_dispatch.goose`.
- A program's untyped middleware that works after its block runs that work. Without
  `rest::scoped`, it sees status 0 for a 404 in its scope, which `rest::routes`
  answers after it, and a failure unwinds past it. Its fields miss a failure's answer
  too, as in today's form when the middleware holds no `rest::route`.
- The routes after a scope don't match once a route in it, or its middleware, took
  the request. After a `bool` scope that matched nothing, they still match the
  narrowed path (snag 3). A block scope gives 404 there.
- A statement after a matched route runs (snag 4 reversed).
- A matched route that writes nothing gets serve's 500, not a 400.

In `inline_skip.goose`'s -O2 C, `test/inline_route.goose`'s handler in this form with
block scopes, every middleware, route, scope, and function that fails is inlined into
`handle`, `cors`'s route inside the request's included. The answers are
`inline_route.goose`'s, Server-Timing's milliseconds aside. `test/inline_route.goose`
is now that handler, and `scripts/test.sh` checks its C.

### The 60 routes

`benchskip.sh` builds `skip60/`'s servers, each against its own package: today's form
(`hand60*`) against `f7ca662`, where `short-routes` branched; A (`short60*` on
`short-routes`, `fc4d51d`, in the script at `99d424a`); and skip-based routing
(`short60*` with scopes in `if` chains, `block60*` with block scopes). It checks that
every form answers every case with the same bytes, then counts. Three stacks:

- **plain**: the spike's `hand60` and `short60`, `/v1/reports` behind a check that
  can fail.
- **m**: tier M's stack. `rest::timed` and `rest::cors` are outside `rest::routes`,
  and `rest::bearer` is around `/v1`. Requests have an `Origin` and a token.
- **c**: `/v1/reports` behind `rest::cors` rather than the check. In today's form,
  cors goes outside a `rest::route` of the scope's own. In skip-based routing it's
  inside `rest::routes`, in `rest::scoped`. `/v1/reports` comes first in `/v1` in
  every form, as today's form must have it. Requests have an `Origin`. The failure
  is `GET /v1/reports/time/abc`, a 400.

| Case | Today | A | Skip, `if` |
|---|---|---|---|
| plain, first, `/health` | 18,116 | 18,251: +135 | 18,253: +137 |
| plain, last route | 24,424 | 24,491: +67 | 24,534: +110 |
| plain, 404 in the last scope | 24,184 | 24,237: +53 | 24,287: +103 |
| plain, 404 outside every scope | 18,440 | 18,558: +118 | 18,566: +126 |
| plain, 405 in the last scope | 24,527 | 24,594: +67 | 24,632: +105 |
| plain, query | 20,655 | 20,700: +45 | 20,734: +79 |
| m, first, `/health` | 20,870 | 20,988: +118 | 21,043: +173 |
| m, last route | 29,317 | 29,297: −20 | 29,380: +63 |
| m, 404 in the last scope | 29,138 | 29,108: −30 | 29,194: +56 |
| m, 405 in the last scope | 29,610 | 29,590: −20 | 29,668: +58 |
| c, last route | 23,938 | | 24,128: +190 |
| c, failure | 21,582 | | 21,729: +147 |
| c, 404 in the scope | 23,710 | | 23,908: +198 |
| c, 405 in the scope | 24,094 | | 24,292: +198 |

The means of three rounds of `benchskip.sh` at `6e6ebc1`, instructions per request.
Each round is 2,000,000 requests per case, and the rounds interleave the servers. One
worker, `h2load --h1 -c 256 -m 16 -t 8`, Apple M1 Pro, macOS 26.3.1, Darwin 25.3.0,
h2load nghttp2/1.70.0, Goose `f114b5a`, 2026-10-20 (UTC), load average 2.7 at the start
and 4.8 at the end. Within a server, the rounds differ by at most 11. A isn't measured
on stack c: there it answers a failure, a 404, and a 405 without cors's fields. The
block form's numbers from this run are replaced below: they predate the mark's check
inline in the block scope.

- **Middleware outside `rest::routes` costs nothing.** On stack m, A costs 20 to 30
  fewer instructions than today's form on every case but the first, and skip-based
  routing in `if` chains costs 56 to 63 more. The first case's +118 to +173 is the
  request's one route, which today's form doesn't open for `/health`.
- **Skip-based routing in `if` chains costs 30 to 80 more than A** on stack plain,
  except on `/health` and the 404 outside every scope.
- **A scope behind cors costs +147 to +198 with `if` chains** against today's
  `cors { route { ... } }`.

The block form, adopted, after the mark's check moved inline into the block scope and
`rest::get` (`acae7d3`), against today's form and `if` chains in the same run:

| Case | Today | Skip, `if` | Block scopes |
|---|---|---|---|
| plain, first, `/health` | 18,054 | 18,172: +118 | 18,158: +105 |
| plain, last route | 24,363 | 24,408: +46 | 24,360: −3 |
| plain, 404 in the last scope | 24,123 | 24,158: +35 | 24,127: +5 |
| plain, 404 outside every scope | 18,377 | 18,489: +113 | 18,509: +133 |
| plain, 405 in the last scope | 24,469 | 24,506: +37 | 24,469: 0 |
| plain, query | 20,583 | 20,664: +82 | 20,732: +149 |
| m, first, `/health` | 20,811 | 20,940: +129 | 20,934: +124 |
| m, last route | 29,242 | 29,160: −82 | 29,168: −74 |
| m, 404 in the last scope | 29,058 | 28,979: −79 | 28,998: −61 |
| m, 405 in the last scope | 29,534 | 29,457: −76 | 29,470: −64 |
| c, last route | 23,857 | 24,050: +193 | 24,111: +253 |
| c, failure | 21,503 | 21,653: +149 | 21,733: +229 |
| c, 404 in the scope | 23,636 | 23,819: +183 | 23,880: +244 |
| c, 405 in the scope | 24,006 | 24,202: +196 | 24,263: +257 |

A quick run of `benchskip.sh`: one round of 1,000,000 requests per case
(`RUNS=1 N=1000000`), set up as above, at goose-rest `acae7d3`, 2026-10-21 (UTC), load
average 2.9 at the start and 4.3 at the end. One round shows no spread: the `if`
chains' differences here are up to 64 off the full run's above. Requests per second
are within 3.2% of today's form in every case, above and below.

- **Block scopes cost nothing in a scope without middleware**, −3 to +5 on stack plain
  in `/v1`, and less than today's form behind tier M's stack, −61 to −74. `/health`
  and the 404 outside every scope pay the request's one route, +105 to +133, and the
  query case +149.
- **A scope behind cors costs +229 to +257**, against today's
  `cors { route { ... } }`, likely the route `rest::scoped` opens inside the
  request's, and `v1`'s other scopes, each checking the mark after `/v1/reports` took
  the request; not measured apart.

### 1,111 routes

`benchroutes.sh` with `CORS=1 FORMS="hand skip block" TODAY=<a worktree of f7ca662>`:
`genroutes.sh`'s 1,111 routes with the second area, `/patient`, behind `rest::cors`,
outside its `rest::route` in today's form and inside `rest::routes` in the others.
Every request has an `Origin`. The middle case is in `/patient`. The three forms give
the same bytes for each case, and for each with a tenant the check refuses.

| Case | Today | Skip, `if` |
|---|---|---|
| first, `/health` | 18,441 | 18,602: +161 |
| a route in `/patient`, behind cors | 25,452 | 25,584: +132 |
| last route | 29,097 | 29,202: +105 |
| 404 in the last scope | 28,979 | 29,095: +116 |
| 404 outside every scope | 19,091 | 19,207: +116 |
| 405 in the last scope | 29,394 | 29,510: +116 |

The means of three rounds, set up as the 60 routes' are, at goose-rest `6e6ebc1`,
2026-10-20 (UTC), load average 4.6 at the start and 4.5 at the end. Within a server,
the rounds differ by at most 14. Requests per second are within 1% of today's form in
every case for `if` chains. The block form's numbers from this run, +108 to +278, are
replaced below.

With `if` chains, skip-based routing costs +105 to +161, near A's +60 to +135 at
1,111 routes without cors, and the scope behind cors costs no more than the others.
Every scope's function stays a call, as in A, where today's form inlines them all.

The block form, adopted, at `acae7d3`, in a quick run with the same command and
`RUNS=1 N=1000000`, 2026-10-21 (UTC), load average 4.0 at the start and 4.9 at the end:

| Case | Today | Skip, `if` | Block scopes |
|---|---|---|---|
| first, `/health` | 18,372 | 18,484: +112 | 18,490: +118 |
| a route in `/patient`, behind cors | 25,363 | 25,485: +122 | 25,588: +225 |
| last route | 29,002 | 29,070: +68 | 29,109: +107 |
| 404 in the last scope | 28,884 | 28,960: +76 | 29,002: +118 |
| 404 outside every scope | 18,999 | 19,134: +135 | 19,134: +135 |
| 405 in the last scope | 29,295 | 29,377: +81 | 29,421: +126 |

Block scopes cost +107 to +135 outside cors and +225 behind it, under 1% in every case:
about 40 more than the `if` chains in the areas, and 100 more behind cors. Requests per
second are within 1.1% of today's form but on `/health` and the 404 outside every
scope, 2.3% and 2.4% lower, one round each. The binaries: today's form 385 KB, `if`
chains 388 KB, block scopes 421 KB.
