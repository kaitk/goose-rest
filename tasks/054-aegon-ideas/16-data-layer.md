# 16: A data layer generated from the schema

Status: todo (asked for 2026-10-20). After task 052, and goose-postgres's tasks 002 to 004.

Aegon's ORM (`data/sql/schema`, `querying`, `mutations`, `relations`, `transactions`,
and `config`, read 2026-10-20) is close to what TypeScript developers use in Prisma,
Drizzle, or TypeORM. goose-rest takes its concepts. The question is the mechanism: Aegon
builds SQL at run time from member pointers. goose-rest should do at build time what it
can, as its generator does from OpenAPI.

What Aegon offers:

- **A table definition** on the struct: the primary key (auto-increment for an
  integer, the generated ID filled in on insert); `not_null`, `nullable` (the default
  for an optional field), `unique`, `indexed`, `length(n)`, and `default_value`; foreign
  keys with cascade, set null, or restrict on delete and update; `created_at` and
  `updated_at` maintained automatically; and a `version` column for optimistic
  concurrency.
- **Lookups:** by primary key, and by a unique column.
- **A query builder:**
  - a typed `where` with `=`, `!=`, `<`, `<=`, `>`, `>=`, `LIKE`, `IN`, `BETWEEN`, and
    null checks, joined by `and` and `or`
  - projections, `group_by` and `having`, ordering, limit, and offset
  - `fetch_all`, `fetch_one` (adds `LIMIT 1`), and `fetch_into` a reused array
  - `count`, `sum`, `avg`, `min`, and `max`
  - `paginate`: count and page in one call, with page, totals, and whether there's a next
  - `to_sql` to inspect the SQL and its parameters
- **Writes:**
  - `insert`, `insert_get_id`, and `insert_all` in one round trip
  - `update_entity` with the version check (`WHERE version = $n`, then `+ 1`), failing
    when another write came first
  - an update builder (`set`, `where`) and a delete builder for many rows
  - `delete_by_id`
- **Relations:** has one, has many, and many to many through a junction table, with
  `link` and `unlink`. Eager loading by `include` runs one batched `WHERE fk IN (...)`
  query, with no N+1, filtered and ordered per relation. `where_has` and
  `where_doesnt_have` filter parents by their children. Lazy `load`.
- **Transactions:** a block that commits on return and rolls back on failure, with the
  same calls inside it as outside, and savepoints.
- **Configuration:** Postgres and SQLite dialects; SQLite opened with WAL and foreign
  keys on; statements prepared once at startup; and reads spread over replicas, with
  writes and transactions on the primary.
- **DDL:** `CREATE TABLE` and `CREATE INDEX` from the definitions.

How it maps to goose-rest:

- **The definition is input to the generator,** as a JSON Schema with extensions or as
  SQL DDL. From it the generator writes the struct, its row reader, the key and unique
  lookups, insert, update with the version check, delete, the relations' batched
  loaders, and the DDL. All of these are fixed SQL, prepared once, with no builder at
  run time.
- **Named queries** in `.sql` files become typed functions, as sqlc does: parameters
  and result rows checked against the schema at build time.
- **A filter whose clauses depend on the request,** as a list endpoint's optional
  filters do, needs SQL built per request. The generator can write typed column
  constants, so a small builder appends clauses to a buffer and binds parameters, with
  no strings from the request in the SQL. Measure it against a fixed query.
- **Transactions** are task 052's `pg::transaction` block, with failure leaving through
  `pg::fail`, not an exception. Writes queue their cache invalidations until the commit
  (subtask 17).
- **Where it runs:** on a lane, as task 052 decides. Read replicas are a second lane, or
  a second set of connections on the same lane.
- **Both dialects** come from one definition, with goose-sqlite's task 003 matching
  goose-postgres's transaction block.

This is the largest of the subtasks: a design first, then a spike, before any of it is
built.

## Acceptance criteria

- [ ] A design: the definition's format, what's generated, the dynamic filter's shape,
      and which of Aegon's calls are left out and why, reviewed and recorded in
      `docs/decisions.md`
- [ ] A spike: one table with a relation, generated, on goose-postgres and goose-sqlite,
      with its instruction count per query against hand-written calls
- [ ] Optimistic concurrency, timestamps, and batched eager loading tested
- [ ] A best-practices page on data access (task 035 waits on it)
