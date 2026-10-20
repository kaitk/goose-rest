# 01: Shorter routes

Status: cancelled (2026-10-20), by request, under the bar the request set: adopt only
one form that works everywhere at today's instruction count. Neither design meets it.

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

## Verdict: don't adopt (2026-10-20)

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

Found along the way: Goose inlines a function called in a block whose arm ends in a
`return` only below half the usual size
([findings](../../docs/goose-findings.md#a-block-that-ends-in-a-return-keeps-its-calls-out-of-line)).

## Acceptance criteria

- [x] A spike under `spikes/` checks that both forms compile to the same `if` chain,
      with the same instruction count on tier A. The count is `bench/routes.sh`'s
      60-route chain on macOS: neither one-form design matches it.
- [x] The 405 `Allow` field still lists every method whose path matched
- [x] A guard still works with the shorter form
- [ ] ~~If adopted: a decision in `docs/decisions.md`, and the quick start, tutorial,
      and examples moved to it~~ Not adopted.
