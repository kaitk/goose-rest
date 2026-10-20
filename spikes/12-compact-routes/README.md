# 12: Shorter routes

Checks task 056.01's two changes (`tasks/056-aegon-ideas/01-compact-routes.md`) beside
today's form, without changing the package. `compact.goose` holds them:

- `compact::routes` is `rest::routes`, then `rest::otherwise` when nothing in its block
  answered or waits for a later call. So a program writes no `else { rest::otherwise(cx); }`.
- `compact::get(cx, "/projects/:id") { ... }`, and `post`, `put`, `patch`, and
  `delete`, do `rest::on` and `rest::route` in one call. A route that matched leaves
  through `return from routes`, so the statements after it act as the `else` of an
  `if` chain.

`main.goose` serves each request with both forms through `rest::serve_one` and prints
one line when they answer alike, and both status lines when they don't. `chain.goose`
holds the same four routes in both forms, for their C. `bench/routes/short60.goose` is
`hand60.goose`'s 60 routes in the shorter form.

Goose: commit `f114b5a`, the pin. goose-http: `v0.4.3`. goose-rest: `bd6f0b1`.

```sh
GOOSE=$(../../scripts/goose.sh)
$GOOSE main.goose
$GOOSE -O2 -o chain.c chain.goose
SERVERS="hand60 short60" ../../bench/routes.sh   # macOS
```

## Verdict: adopt

Both forms answer every request alike, with one difference in a guard, below. They
compile to the same `if` chain and run the same number of instructions per request.

```text
GET /projects/7 HTTP/1.1 -> HTTP/1.1 200 OK
POST /projects/7 HTTP/1.1 -> HTTP/1.1 405 Method Not Allowed
  Allow: GET, HEAD, DELETE
BREW /health HTTP/1.1 -> HTTP/1.1 501 Not Implemented
POST /admin HTTP/1.1 -> today HTTP/1.1 405 Method Not Allowed, shorter HTTP/1.1 404 Not Found
```

(`expected.txt` has all 25 requests.)

- **The 405's `Allow`.** A route that doesn't match falls through to the next one, so
  every route before the answer adds its method to the router's `Allow`. `POST
  /projects/7` gets `Allow: GET, HEAD, DELETE` in both forms, and `OPTIONS` gets the
  same field.
- **A guard.** A guard is still an `if` condition, around the routes it guards:
  `if admin(cx) { compact::get(cx, "/admin") { ... }; }`. When the guard fails, the
  route doesn't match, and the request falls through to the next route or to 404, as
  with `if rest::on(...) && admin(cx)`. One answer differs. With today's
  `rest::on(...) && admin(cx)`, the path is matched before the guard, so a `POST
  /admin` from a non-admin gets 405 with `Allow: GET, HEAD`, while a `GET` from the
  same client gets 404. The shorter form checks the guard first, so both get 404. No
  route is shown to a client it doesn't apply to, which is the better answer.
- **Today's form inside the shorter one.** A scope behind middleware keeps one
  `rest::route` around its routes, which use `rest::on`. That's the middleware rule:
  one route for each request. Such a scope still works inside `compact::routes`, with or
  without its own `rest::otherwise`. In `main.goose`, `/reports`, without one, answers
  200, 401 from `rest::bearer`, 404, and 405 alike in both forms, and `/old`, with one,
  answers 200, 404, and 405 once. A route that gathers its body
  (`PUT /upload` with 100,000 bytes) gets one answer in both forms.

### Why `routes` checks for an answer

`compact::routes` can't call `rest::otherwise` after every block that falls through.
Some code inside the block answers and then returns normally:

- an `if rest::on(...)` route written in today's form;
- a scope's own `rest::otherwise`;
- middleware such as `rest::bearer` that answers 401 early;
- a route that waits for its body or a lane's reply.

So after the block, `routes` answers only when the response is still empty from where
the block began, nothing waits (`stream.waiting`), and the exchange expects no later
call (`ex.mode & rest::LATER`). That's the test serve's `settle_kept` already makes.
A matched short route leaves before that test, so it never pays for it. goose-http's
`http::Router` records no match, and adding a field for one would be a change in
another repository.

### The C

In `chain.goose`'s `-O2` C, Goose inlines all of each form into one function, `long_g`
and `short_g`, with nothing left out of line but the same leaves: `rest_on_g4`,
`rest_header_g4`, `rest_otherwise_g4`, the writers, and the integer parse. Both
functions make the calls in the same order: `on`, `on`, `on`, `header`, `on`, and
`otherwise`. Each matched route in the shorter form ends with `goto L0`, a jump to the
function's end, which is what an `else` compiles to. `short_g` has 9 more `goto`s and 4
more `if`s than `long_g`: the jump at the end of each route, and the answer test before
`otherwise`:

```c
if (!(... out_g.buf_g.hdr->len == mark_g_6)) goto L207;
if (!((*(*cx_g_27).out_g.stream_g).waiting_g)) goto L206;
...
if ((... (*x_g).mode_g & 15) == 0)) goto L204;
...
rest_otherwise_g4(cx_g_28, (*cx_g_28).router_g, gs_sp + 0);
```

`short60`'s C is 60 routes in one scope function. Goose inlines 58 of them into `v1_g`
and keeps two as calls, past its inliner's size limit: `GET /projects`, which reads
three query parameters, and one `DELETE`. Each of those calls is followed by an
`if (gs_rf)` check for the `return from`. Today's form, `hand60`, keeps `rest::routes`,
`rest::route`, `rest::attempt`, and `v1` as calls in Goose's C, instead. clang `-O2`
inlines further in both.

### Instruction counts

`bench/routes.sh`, full runs: 3 rounds of 2,000,000 requests per case, one worker,
`h2load --h1 -c 256 -m 16 -t 8`. Apple M1 Pro, macOS 26.3.1, Darwin 25.3.0, h2load
nghttp2/1.70.0, 2026-10-20. The load average was 7.9 at the start and 14.8 at the end,
from other work on the machine. On macOS, instructions retired include the kernel's
([bench/README.md](../../bench/README.md#instruction-counts-on-macos)).

| Case | hand60 (today) | short60 (shorter) | Difference |
|---|---|---|---|
| first, `/health` | 18,149 / 18,125 / 18,002 | 18,138 / 18,170 / 17,988 | +7 (+0.04%) |
| last route | 23,602 / 23,593 / 23,703 | 23,587 / 23,580 / 23,699 | −10 (−0.04%) |
| 404 in the last scope | 23,355 / 23,348 / 23,380 | 23,361 / 23,314 / 23,350 | −19 (−0.08%) |
| 404 outside every scope | 18,439 / 18,438 / 18,457 | 18,435 / 18,434 / 18,456 | −3 (−0.02%) |
| 405 in the last scope | 23,696 / 23,697 / 23,694 | 23,662 / 23,768 / 23,657 | −0 (0.00%) |
| query, `GET /v1/projects?...` | 20,625 / 20,675 / 20,660 | 20,667 / 20,700 / 20,691 | +33 (+0.16%) |

Instructions per request, each round, and the difference of the means. Every
difference except the query's is smaller than the spread of either server's own three
rounds. The query case is higher in all three rounds, by 25 to 42 instructions. That's
the route Goose's inliner keeps out of line, with its `gs_rf` check, and it's 0.16%,
inside the 1.5% these counts vary between rounds.

## Adopting it

Adopting means moving these two changes into the package. `rest::routes` gains the
answer test and the `rest::otherwise` call. `rest::get`, `rest::post`, `rest::put`,
`rest::patch`, and `rest::delete` join `rest::on`. Today's programs keep working without
changes: their own `rest::otherwise` answers first, and the test then finds the answer
already written. So moving a program to the shorter form doesn't change its golden
output. The guard's 405 above is the one exception, and only where a program writes
the guard after `rest::on`.

`rest::on` stays the form for the routes of a scope behind middleware, which share one
`rest::route`. A `rest::get` there would open a second route inside the first, which
the inlining rules forbid.
