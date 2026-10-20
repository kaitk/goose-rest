# 01: Shorter routes

Status: todo

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

## Acceptance criteria

- [ ] A spike under `spikes/` checks that both forms compile to the same `if` chain,
      with the same instruction count on tier A
- [ ] The 405 `Allow` field still lists every method whose path matched
- [ ] A guard still works with the shorter form
- [ ] If adopted: a decision in `docs/decisions.md`, and the quick start, tutorial, and
      examples moved to it
