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

Goose: commit `f114b5a`, the pin. goose-http: `v0.4.3`. goose-rest: `6ea1377`.

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

### Where the cost comes from

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
