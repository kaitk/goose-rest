# 052: Database work on lanes, in one transaction

Status: todo. Settles goose-postgres's open question of where its connections are
driven, on goose-rest's side (2026-10-19).

A use case ported from Hono, Elysia, or Spring, such as eight queries, some in parallel,
with business rules in one transaction, must map to one job on a lane with blocking
calls, so that its cost stays constant per use case. If each query were a wait on the
worker, every query would add a state to the route, as in Tina, and a repository
function that runs two queries could no longer be called from a service function.

The split:

- goose-postgres keeps its protocol without I/O. A blocking facade over it serves lane
  jobs; pipelining in the protocol gives queries "in parallel" on one connection as a
  library call, as `Promise.all` does.
- A route that runs one query may ask the worker's loop directly, as HttpArena's
  `/async-db` does (task 047).
- A transaction is a block whose failure path the compiler checks. `pg::transaction`
  calls an inner target, and `pg::fail` does `return e from` it, as `rest::route` and
  `rest::fail` do (`runtime.goose`). `transaction` rolls back and returns the error,
  and a function that calls `pg::fail` compiles only inside a transaction: the
  "transaction as the last parameter" convention of TypeScript libraries, enforced.

A sketch, with the block's result form still to check against the spec:

```rust
fn ::run(u: Writes.PlaceOrder, db: pg::Conn&, a) {
    let order, err = pg::transaction(db) { tx =>
        let o = orders::insert(tx, u.items);  // may pg::fail at any depth
        stock::reserve(tx, u.items);
        o
    };
    ...
}
```

goose-sqlite takes the same block, where its API allows.

## Acceptance criteria

- [ ] goose-postgres's decisions record the split: protocol without I/O, a blocking
      facade for lanes, and the worker's loop for single queries
- [ ] goose-postgres and goose-sqlite have tasks for the facade, pipelining, and the
      `transaction` block
- [ ] The best practices' data access page ports one multi-query use case with a
      transaction, as one job, once the facade exists (task 035)
- [ ] `docs/decisions.md` records that database work runs on lanes, and why
