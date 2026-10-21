# 01: Shorter routes

Status: in-progress. Cancelled on 2026-10-20 under the bar first set, today's
instruction count, and reopened the same day by request under a new one: a reasonable
cost. Design A was adopted, by request (2026-10-20), and paused (2026-10-21): moving
the programs found the snags below, which spike 12 didn't check
([Open](#open-the-snags-moving-the-programs-found-2026-10-21)). Skip-based routing
with block scopes only is adopted instead (2026-10-21,
[verdict](#verdict-skip-based-routing-with-block-scopes-2026-10-21)), and merged.
Todo, deferred by request (2026-10-21): `sudo bench/rest.sh count` on the Linux
desktop, to check tier M's +431 on the merged server against today's form's 5,030.4
(tier A 4,271.4, tier R 39,065.4, from `bench/results/2026-10-20T2001-rest-Tiamat`),
and a full `bench/routes.sh` run on macOS; then record both
([criteria](#acceptance-criteria)). A count in Docker on macOS wouldn't compare: it
runs arm64 in a VM, against x86-64 baselines.

## Verdict: skip-based routing with block scopes (2026-10-21)

Decided, by request: candidate 3 below. A matched route marks the request taken in
goose-http's `Router.bad`, with no goose-http change, and returns normally. Scopes are
blocks only, as Actix's `web::scope`; the `bool` `rest::scope` is removed, and
`rest::on` and `rest::otherwise` stay as the lower-level pieces, `rest::otherwise`
answering nothing after a route that took the request. `rest::scoped` is the building
block for middleware that works after its block or adds fields, and goose-rest's
`cors`, `timed`, `security_headers`, and `compressed` keep one name each
([decisions](../../docs/decisions.md#the-api)). It depends on what `Router.bad` means,
which goose-http's task 027 could change.

On macOS, in quick runs at `acae7d3`, block scopes cost −74 to +149 instructions per
request at 60 routes and +107 to +135 at 1,111, and +225 to +257 in a scope behind
`rest::cors`
([spike 12](../../spikes/12-compact-routes/README.md#skip-based-routing-2026-10-21)).
An earlier quick round on `689cc0e` put them at +69 to +229 at 1,111 routes. One
earlier run had 97,084 of 2,000,000 responses short of 2xx, which didn't repeat in
four tries, nor in these; the scripts print h2load's output if it does.

## Skip-based routing (2026-10-21)

By request, the middleware contract first proposed (outside-only middleware, and
scoped versions that catch `rest::get`'s leave in an inner `routes`) gave way to the
idea without a long-distance return. A matched route marks the router, goose-http's
`Router.bad`, and the routes and scopes after it don't match. Control returns through
every block, so a middleware's work after its block runs.
[Spike 12](../../spikes/12-compact-routes/README.md#skip-based-routing-2026-10-21) has
the prototype, its checks, and its counts.

- Snag 1 is gone for every middleware, a program's untyped ones included.
- Snag 2 is gone for goose-rest's middleware: inside `rest::routes`, each runs its
  block in `rest::scoped`, a route of its own that also gives the default answer, so
  a failure, a 404, and a 405 in a scope behind `rest::cors` get its fields. A
  program's middleware that adds fields builds on `rest::scoped`, as today it holds a
  `rest::route`; one that doesn't misses them on a failure, as today.
- Snag 3: a block form, `rest::scope(cx, "/p") { ... };`, owns its prefix. The `bool`
  form still leaves the path narrowed.
- Snag 4 turns around: the statements after a matched route run.
- The generated `dispatch` begins with `guard rest::untaken(cx)`, so it answers
  nothing after a program's route that took the request.

Cost on macOS against today's form, instructions per request: the request's one route,
+115 to +173 on `/health`, as in A; elsewhere on 60 routes, −39 to +138, with tier M's
stack outside `rest::routes` costing nothing beyond that route; a scope behind
`rest::cors`, +147 to +286. At 1,111 routes with an area behind `rest::cors`, +105
to +161 with scopes in `if` chains and +108 to +278 with block scopes, the block form
keeping one `rest::scope` out of line. Requests per second stay within 1% of today's.

### The syntax: candidates

Each keeps `rest::get` and its kin, and one name for each middleware. The
`scoped_cors` names, and outside-only middleware, aren't needed with skip-based
routing. Tutorial page 7's handler, and `examples/compress`'s per-scope compression,
in each:

**1. Scopes in `if` chains**, design A's syntax as the branch's docs have it. The
docs keep the rule that a scope comes after the routes beside it.

```goose
rest::routes(cx) { cx =>
    rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
    if rest::scope(cx, "/v1") {
        resolve_tenant(cx) { tenant => v1(cx, tenant); };
    } else if rest::scope(cx, "/admin") {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            admin(cx);
        };
    } else if rest::scope(cx, "/v2") {
        member_routes(cx) { tenant => v1(cx, tenant); };
    }
};

rest::routes(cx) { cx =>
    rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
    if rest::scope(cx, "/v1") {
        rest::compressed(cx) { cx => events(cx); };
    } else if rest::scope(cx, "/archive") {
        rest::compressed(cx, ARCHIVE) { cx => events(cx); };
    }
};
```

**2. Block scopes**, as Actix's `web::scope` and Aegon's groups read. Each scope is a
statement that owns the paths under its prefix wherever it stands: a route after it
on such a path never matches.

```goose
rest::routes(cx) { cx =>
    rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
    rest::scope(cx, "/v1") { resolve_tenant(cx) { tenant => v1(cx, tenant); }; };
    rest::scope(cx, "/admin") {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            admin(cx);
        };
    };
    rest::scope(cx, "/v2") { member_routes(cx) { tenant => v1(cx, tenant); }; };
};

rest::routes(cx) { cx =>
    rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
    rest::scope(cx, "/v1") { rest::compressed(cx) { cx => events(cx); }; };
    rest::scope(cx, "/archive") { rest::compressed(cx, ARCHIVE) { cx => events(cx); }; };
};
```

**3. Block scopes only**: as 2, with the `bool` `rest::scope` removed, so that no
scope leaves the path narrowed. `rest::on` and `rest::otherwise` stay for today's
form.

In all three, `events` loses its `if` chain and `rest::otherwise`:

```goose
fn events(cx) {
    rest::get(cx, "/events") { ... };
    rest::get(cx, "/export") { ... };
    rest::get(cx, "/events/:id") { ... };
}
```

A program's own middleware, an audit log, builds on `rest::scoped`, and works outside
`rest::routes` and in a scope alike:

```goose
// Logs each request its block answers, with the status and the time it took.
inline fn audited<F>(cx) {
    let begun = clock_ns();
    rest::scoped(cx) { F(); };
    audit(cx.state, cx.req.method, cx.req.target, cx.out.stream.status, clock_ns() - begun);
}
```

Without `rest::scoped`, it logs status 0 for a 404 in its scope, and nothing for a
failure. Other names for the building block: `rest::guarded`, `rest::wrapped`,
`rest::answered`.

## Open: the snags moving the programs found (2026-10-21)

Spike 12 tested `rest::bearer` and stacks of it inside `rest::routes`. Each does
nothing after its block, and fails only before the route it guards. The snags below
come from everything else a scope can hold.

### 1. Work after a middleware's block is skipped when a route matches

Checked: `spikes/12-compact-routes/after_block.goose`. `rest::get` leaves through
`return from routes`, which unwinds every frame between it and `rest::routes`, so a
middleware inside `routes` around a matched `rest::get` never runs the code after its
block. None of this fails to compile.

- `rest::timed`: `Server-Timing: app;dur=` stays blank, and no log line is written.
- `rest::compressed`: the answer stays in its buffer, and the client gets 500.
- `rest::cors` and `rest::security_headers`: the answer is right, but their fields
  aren't kept for an answer at a later call, after a lane's reply or a body read in
  pieces.
- A program's own middleware that works after its block, the same.

Of the programs moved, only `examples/compress/` had such middleware inside `routes`,
compressing `/v1` and `/archive` differently. The reference offers security headers
per scope.

### 2. A failure inside a scope's middleware is answered outside it

Not run yet; it follows from the code. `rest::fail` returns from the innermost
`attempt`, and in design A the only route is the one `rest::routes` opens, since
`rest::route` inside `routes` joins it. So a `rest::fail` in a route inside a
scope's `rest::cors` is answered after `cors` has been unwound: a 404 without the
CORS fields, which a browser reports as a CORS error. The same holds for a scope's
`security_headers`, `compressed`, and `timed`. Today's form answers it inside the
middleware, by putting `rest::route` inside it. Catching a route's leave (snag 1) doesn't
help: a failure doesn't go through `rest::get`.

### 3. A scope leaves the path narrowed

`rest::scope` shortens the router's path when it matches, and nothing restores it. The
routes after a scope that matched, but answered nothing, match against the shortened
path. Today's form never reaches them, since they're in the `else`. Design A's
programs put scopes after the routes beside them, and scopes beside each other in one
`if` chain. A block form, `rest::scope(cx, "/v1") { ... };`, could restore the path
after its block.

### 4. Code after a matched route doesn't run

A matched `rest::get` leaves `routes`, so the statements after it in the block don't
run, as in an `else`. That's the design, but code there, such as a log line at the
end of the block, runs only for requests no route took.

### Ideas, none chosen

- **Middleware outside the routes only.** `timed`, `cors`, `security_headers`, and
  `compressed` take `Cx<S, A, rest::NoRouter>&`, so that inside `rest::routes` they
  don't compile, as `rest::on` doesn't outside it. That turns snags 1 and 2 into
  compile errors for goose-rest's middleware, and takes away per-scope middleware.
- **Two kinds by name.** Beside those, scoped versions such as `rest::scoped_cors` take
  only `Cx<S, A, http::Router>&`, so that they compile only inside `routes`. Each runs
  its block in a route of its own, which answers a failure inside the middleware (snag
  2), and catches a matched route's leave in an inner overload of `routes` (a
  `return ... from` lands in the innermost call of the overload set, spec §7.9), does
  its work, and leaves again (snag 1). This removes the snags for goose-rest's own
  middleware, not for a program's: an untyped `inline fn m<F>(cx)` still compiles in
  both places, and one that works after its block misbehaves inside `routes` without a
  word. Docs would cover that: the template for a program's middleware names its
  context type, and a scoped one builds on a block goose-rest provides. To measure: a
  route inside the request's route keeps both out of line
  ([decisions](../../docs/decisions.md#inlining)), so the scopes that use a scoped
  middleware pay for it, and the outside-only versions should cost nothing over
  today's. Neither is measured.
- **Forward the leave in the same function.** One middleware for both places, which
  forwards the leave only when given a router context. It leaves snag 2, and a
  program's own needs a public pair to do the same.
- **A rule, no new API.** Middleware that works after its block goes outside
  `rest::routes`, and a scope with middleware of its own keeps the `if` chain of
  `rest::on` and `rest::otherwise` inside it. Mistakes show at run time.
- **No long-distance return.** A matched route marks the router, and the routes and
  scopes after it don't match. Middleware then runs as written (snag 1), but snag 2
  stays. The mark goes in a router type of goose-rest's own, the `R` of `Cx`, so
  neither `Cx` nor goose-http changes. It costs a check for each route after the match,
  and generated dispatch after hand-written routes needs one too.
- **Only the default answer.** `rest::routes` answers 404, 405, and 501 when its block
  left the request unanswered and nothing waits, without `rest::get`. No long-distance
  return, so none of the snags. `rest::otherwise` stays, and code that calls it keeps
  working. It saves the `else { rest::otherwise(cx); }`, about two lines a block, and
  costs a check after the block; not measured. The docs would move with design A's
  change, if that comes back, rather than twice.

### What the branch holds

Branch `short-routes`, uncommitted and unmerged, in the worktree
`../goose-rest-short-routes`:

- The package: `rest::routes` opens the request's one route and gives the default
  answer, `rest::get` and its kin from spike 12's `compact.goose`, and `rest::route`
  joining inside `routes`. Tests: `test/runtime/routes.goose`,
  `test/serve_one/routes_waiting.goose`, and `test/errors/get_outside_routes.goose`.
  `test/run_tests.py` passed with them, before the docs moved.
- A draft decision in `docs/decisions.md` and `docs/architecture.md` moved to it. The
  draft predates these snags.
- Moved to design A: the README's quick start, the tutorial, the best practices, the
  reference, and the generator reference. Their programs typecheck. Pages 1 and 2 were
  served and requested; the rest weren't.
- Not moved: `examples/`, the tests in today's form, `test/inline_route.goose`, the
  benchmark servers, and `FORM=short`. Nothing is measured on the package.

Branch `routes1100` holds the spike's measurements and the REST benchmark's `FORM=short`.

Aegon's hello world is 10 lines; goose-rest's is about 17. Two changes could bring ours
to about 12 without changing what the routes compile to:

- `rest::routes` answers 404, 405, and 501 itself when no route answered, so the
  `else { rest::otherwise(cx); }` goes away.
- An inline `rest::get(cx, "/hello/:name") { ... }`, and one for each method, does
  `rest::on` and `rest::route` in one call.

The `thread_fn worker` stays: `thread_spawn` can't name a `thread_fn` passed through a
generic function in another module (task 043).

This touches the decision that guards are `if` conditions: a guard has to stay possible
beside the shorter form.

## Verdict: adopt design A (2026-10-20)

Under a reasonable cost, design A is adopted. On macOS (clang), it costs a fixed 57 to
165 instructions per request at 60, 1,111, and 5,001 routes, under 1%. On Linux (gcc),
on the REST benchmark, it costs nothing on tiers A, F, and R (−84 to +1), and
+431 instructions per request on tier M (+8.6%), the middleware stack. Requests per
second are within the rounds' spread everywhere, on both platforms
([spike 12](../../spikes/12-compact-routes/README.md#the-rest-benchmark)). The +431 on
tier M is unexplained; the adoption checks it on `rest::routes` itself rather than on
the spike's `compact`.

## The first verdict: don't adopt (2026-10-20)

The bar: one form that works everywhere, scopes behind middleware included. Real
programs have middleware, so two forms would be mixed, and the wrong one goes out of
line without a word. [Spike 12](../../spikes/12-compact-routes/README.md) has the
numbers.

- **The first version** gave each `rest::get` a route of its own. It cost nothing
  measurable (−19 to +33 instructions per request), but a scope behind middleware
  shares one `rest::route`, and a `rest::get` there opens a second route. That needed
  today's form in such scopes: two forms.
- **Design A**: `rest::routes` opens the request's one route, and `rest::get` only
  matches. One form works everywhere and answers byte for byte as today's does, bearer's
  401 inside a scope included. It costs +42 to +164 instructions per request (+0.2 to
  +0.9%) on `bench/routes.sh`'s 60 routes, above the runs' spread in every case. Goose
  keeps the one route out of line around a large block, so every request pays its calls,
  including `/health` and 404s that today's form answers with no route.
- **Design B**: `rest::route` hands its block a context of a marked type, and
  `rest::get` is overloaded on it. One form works everywhere and answers alike. It costs
  +26 to +83 instructions per request in a scope behind its route (+0.1 to +0.4%), above
  the spread, for the marked context each route builds and the extra reference on every
  match. It also changes signatures: every `rest::route` block and every stack takes
  `cx =>`, every call that reads the router gains an overload, and typed helpers need a
  second alias. Code that names the outer `cx` inside a route still opens a second
  route out of line.

Both designs answer a request no route took from `rest::routes`, after checking that
the block wrote nothing and waits for nothing. A guard is an `if` around the routes it
guards. That much works, but neither is worth adopting alone: the line it saves is the
`else`, and the `rest::on` and `rest::route` pair stays.

A's cost comes from its design, not from Goose's size limit for a function called once:
every request opens the route that today's form opens only for routes behind middleware.
Removing the limit, and inlining everything else that kept the chain of calls, made both
forms slower behind middleware (task 057). At 1,111 routes, A costs +60 to +135
instructions per request (+0.2 to +0.7%), and at 5,001 routes with nested roles +57 to
+165 (+0.2 to +0.6%), so the cost doesn't grow with the program
([spike 12](../../spikes/12-compact-routes/README.md#larger-programs)). B stays
rejected for its signatures.

Found along the way: Goose inlines a function called in a block whose arm ends in a
`return` only below half the usual size
([findings](../../docs/goose-findings.md#a-block-that-ends-in-a-return-keeps-its-calls-out-of-line)).

## Acceptance criteria

- [x] A spike under `spikes/` checks that both forms compile to the same `if` chain,
      with the same instruction count on tier A. The count is `bench/routes.sh`'s
      60-route chain on macOS: neither one-form design matches it.
- [x] The 405 `Allow` field still lists every method whose path matched
- [x] A guard still works with the shorter form
- [x] A decision in `docs/decisions.md`, replacing the one it changes, and
      `docs/architecture.md` updated
- [x] `rest::routes` opens the request's one route and answers 404, 405, 501, and
      OPTIONS itself; `rest::get`, `post`, `put`, `patch`, and `delete` in the package,
      with tests
- [x] The quick start, tutorial, best practices, reference, examples, generated
      router, and benchmark servers moved to the shorter form, with the REST
      benchmark's `FORM=short` and the spike's `compact` import removed
- [ ] Tier M's +431 instructions per request on Linux checked with
      `bench/rest.sh count` on the adopted form: explained, or fixed
- [ ] `bench/routes.sh` and the REST benchmark's counts recorded after the change
