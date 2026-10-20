# 17: Entity and query caching

Status: todo (asked for 2026-10-20). After subtasks 09 (or 10) and 16.

Aegon's [ORM cache](https://udaykhare09.github.io/Aegon/guide/data/sql/cache) (read
2026-10-20) caches rows in front of the database, behind one cache interface (`get`,
`mget`, `set` with TTL, `del`, `del_many`, `incr`) that Redis and MemStore both meet:

- **Normalized entries.** A row is cached once, under `table:id:<pk>`. A query caches
  only its list of primary keys, under `table:q:v<epoch>:<fingerprint>`, and reads the
  rows with one `MGET`. An update to a row shows in every query that lists it. A row
  missing from the cache is fetched alone, and the cache healed.
- **Unique pointers.** `table:email:<value>` points to the primary key, for lookups by
  a unique column.
- **Invalidation by epoch.** A write bumps a counter that the query fingerprint
  includes, so older entries become unreachable and expire on their TTL, with no `KEYS`
  or `SCAN`. The epoch can be the table's (strict), per tenant or parent key
  (partitioned), or per column value (predicate-aware). It can also be off, leaving the
  TTL alone, for dashboards.
- **On a write:** evict the row's entry, or rewrite it, chosen per table.
- **Deferred to the commit.** Inside a transaction, invalidations are queued and applied
  after `COMMIT`, or dropped on rollback, so the cache never holds data that didn't
  commit.
- **Configured per table:** TTL, unique pointers, partition key, invalidation mode, and
  write policy, in the table's definition.
- **A fingerprint** is SHA-256 of the dialect's SQL, the bound parameters, and the
  active epoch.

In goose-rest the settings go in subtask 16's definition, so the generated lookups and
writes include the cache calls, with nothing decided per request. The backend is the
lane store or Redis, chosen as subtask 10 decides. The queued invalidations live in the
transaction's state on the lane, which `pg::transaction` returns from, so no exception
path is needed.

## Acceptance criteria

- [ ] Normalized entries, unique pointers, and the strict and partitioned epochs, in
      the generated code
- [ ] Invalidations deferred to the commit and dropped on rollback, tested
- [ ] Hole healing tested: a row evicted while its query entry remains
- [ ] Hit and miss rates and the rate on a read-heavy tier measured, with and without
      the cache
