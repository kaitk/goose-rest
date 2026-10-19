# 050: One enum for a route's use cases

Status: todo. Comes before task 047's entry code, because it changes how a program
calls `rest::ask` and what a `resume` gets (2026-10-19).

A route that waits now costs about nine pieces in four files
(`docs/best-practices/lanes/`): a tag constant and a `Waiting` variant in `app.goose`,
the job and reply structs, a branch in the lane's `thread_fn` if chain, the route, the
job function, a `::resume` forwarder, and the `resume`. The count is constant per use
case, however many queries the job runs, but the scatter is what a developer porting
from Hono, Elysia, or Spring finds hard to follow.

The proposal: one fixed-mode enum whose variant is both the job and the wait state, so
that the compiler checks every variant has a case on each side (§8.2), and the tags
and the lane's if chain go:

```rust
enum Use { None, ReportTotals { project: i64 }, ... }
rest::ask(cx, cx.app.reports, Use.ReportTotals { project: id });  // the route
fn run(u: Use.ReportTotals, db: Db&, a) { ... }                      // on the lane
fn resume(u: Use.ReportTotals, cx) { ... }                           // on the worker
```

A job that fails with `return err from` its `run` replies with the error, and
goose-rest fails the route with it before the `resume` runs. That carries an expected
error across the lane, as a `throw` crosses an `await`, and removes the
`guard ok else { rest::fail(cx, 502, "bad_reply"); }` every `resume` has now.

To settle in a spike first:

- Whether §8.2 dispatches `run` overloads whose replies differ in type. If not, each
  `run` sends its own reply.
- The request state grows to the largest job's size, since the variant waits in
  `cx.state`. Measure it against tier M's state.
- Whether the `::resume` forwarders a domain namespace needs (§11.1's overload sets)
  can go too.

## Acceptance criteria

- [ ] A spike under `spikes/` answers the three questions, with its README's verdict
- [ ] `rest::ask`, `rest::lane`'s dispatch, and the `resume` path take a use-case enum;
      no tag constants or lane if chain remain in the tutorial, best practices, or
      examples
- [ ] An error a job returns fails the route with that error's status and code, with a
      test
- [ ] A route that waits costs at most four pieces in two files in
      `docs/best-practices/lanes/`
- [ ] `docs/decisions.md` records the change and what it replaces; `docs/architecture.md`,
      `docs/reference.md`, the tutorial, and best practices follow
- [ ] `scripts/test.sh` passes
