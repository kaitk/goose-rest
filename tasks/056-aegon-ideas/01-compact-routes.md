# 01: Shorter routes

Status: in-progress. The spike says adopt (2026-10-20). Moving the package and the
programs waits until the problem details branch (056.03) merges to main.

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

## Verdict: adopt (2026-10-20)

[Spike 12](../../spikes/12-compact-routes/README.md) checks both forms on 25 requests,
in its C, and in full `bench/routes.sh` runs of `hand60` against `short60`, the same
60 routes in the shorter form. The two forms answer alike and compile to the same `if`
chain. Each matched route jumps to the end of `routes`, as an `else` does. The means
differ by −19 to +33 instructions per request, on about 18,000 to 23,700. All but one
difference is inside either server's own spread between rounds. The query route is
higher in all three rounds (+33, 0.16%) because Goose's inliner keeps it out of line.

Adopting it needs nothing beyond the two changes. `rest::routes` answers only when the
response is still empty, nothing waits, and no later call is due, the same test that
serve's `settle_kept` makes. So today's programs, a scope's own `rest::otherwise`, and
middleware that answers early, such as `rest::bearer`, keep working unchanged. A guard
is an `if` around the routes it guards. Unlike `rest::on(...) && guard`, it hides the
route from the 405's `Allow` when it fails. The routes of a scope behind middleware
keep `rest::on` inside the scope's one `rest::route`.

To do once 056.03 has merged: `rest::get` and its kin, and the answer test in
`rest::routes`. Then record the decision, and move the quick start, the tutorial, the
best-practices programs, the examples, and `short60` to the package's names, with their
golden outputs unchanged.

## Acceptance criteria

- [x] A spike under `spikes/` checks that both forms compile to the same `if` chain,
      with the same instruction count on tier A. The count is `bench/routes.sh`'s
      60-route chain on macOS.
- [x] The 405 `Allow` field still lists every method whose path matched
- [x] A guard still works with the shorter form
- [ ] If adopted: a decision in `docs/decisions.md`, and the quick start, tutorial, and
      examples moved to it
