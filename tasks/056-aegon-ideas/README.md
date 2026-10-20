# 056: What to take from Aegon

Status: todo. The verdicts below were set 2026-10-20; each subtask holds one idea.

[Aegon's guide](https://udaykhare09.github.io/Aegon/) (41 pages, each read in full
2026-10-20) documents an API, middleware, a data layer, and an engine. This task records
which ideas goose-rest takes and which it leaves, and why. Task 048 measures Aegon
itself. The engine ideas belong to goose-http, in its task 057, including wider vector
scanning of long headers, which bearer JWTs and session cookies make common here.

Every claim is from Aegon's docs, not measured here.

## What goose-rest takes, and on what terms

Aegon's API is close to how TypeScript frameworks work (Elysia, Hono, NestJS, Prisma),
which is the audience goose-rest ports use cases from. Where its concept is sound,
goose-rest takes it (2026-10-20). Two conditions apply: no cost at run time, or only
what the feature needs, and work done at compile time or by the generator wherever it
can be. Nothing is rebuilt only to look like Aegon.

On the 2026-10-19 run (`docs/benchmarks.md`, "Against other frameworks"), goose-rest on
io_uring leads Aegon in six of eight columns, by 1.07 to 1.22 times, and trails it on
tier R and F `/id` within the runs' ranges. Its peak RSS on tiers A and C is 13 and 71
MB, against Aegon's 282 and 578 MB, and 27 and 321 MB with Aegon's small buffers, which
cost Aegon at most 2.4% in rate. Memory is the wider lead, so no idea is taken that
trades memory for rate.

## Taken

| Idea | Aegon | goose-rest now | Subtask |
|---|---|---|---|
| Shorter routes | A 10-line hello world | About 17 lines: an explicit `rest::otherwise`, and `rest::on` with `rest::route` | 01 |
| Every violation in one answer | 422 with a map of JSON paths such as `items[1].quantity` | The first error, as `invalid_body` with `detail` and `at` | 02 |
| RFC 9457 problem details | `ctx.problem()`, and problem+json for every built-in error | A customizable format, with no preset | 03 |
| More auth schemes, and role guards | Basic, API key, and cookie beside bearer; optional auth; `require_role` and `require_any_role` | Bearer only | 04 |
| JWT | Signing and verification; HS, RS, PS, and ES; JWKS served and consumed; a denylist | None; the README lists it ⚪ | 05 |
| Security headers | `security_headers()` with `defaults()` and `api()` presets | None; "Default headers" is ⚪ | 06 |
| Access log options | Formats, levels per status class, a slow threshold, skip rules, a request logger with a correlation ID | `rest::timed`'s one fixed line | 07 |
| Small helpers | SSE, a directory of files with SPA fallback, cookies out, CORS patterns and presets | `rest::begin` and `rest::pause`, `rest::file`, exact CORS origins | 08 |
| An in-process store on its own thread | MemStore: TTL, LRU, and the cache interface Redis meets | Lanes, with no store | 09 |
| A Redis client without C | RESP3 from scratch, pipelines, Cluster, Sentinel, locks, streams | None | 10 |
| A CLI that starts a project and checks the machine | `aegon new`, with options for each part, and `aegon doctor` | `goose-rest gen` only | 11 |
| Layered, typed configuration | YAML, an environment's file, `.env`, `${VAR:default}`, prefixed variables, and flags, bound to a struct | None | 12 |
| Validation beyond the schema | A `validate` method with custom predicates, past and future timestamps, query and form binding, and standalone use | The schema's checks in generated readers | 13 |
| A logger | Levels, an asynchronous writer, sinks for the console, a file, and tests | Programs print | 14 |
| Foundational types | UUID, DateTime, Date, Time, Decimal, IpAddress, and more, accepted by JSON, SQL, and Redis | Formats checked, values kept as text | 15 |
| A data layer | An ORM: table definitions, a query builder, relations with batched loading, optimistic concurrency, transactions, DDL | goose-postgres's and goose-sqlite's calls | 16 |
| Entity and query caching | Normalized rows, epochs, invalidation deferred to the commit | None | 17 |

Subtasks 01 to 08 are small and don't touch goose-http's TLS and h2 work. Subtasks 09
to 17 are larger. 16 and 17 wait on task 052 and goose-postgres.

## Read Aegon's pages first

Whoever builds a subtask reads the pages of Aegon's guide for it first. The guide holds
more than the subtasks record: option names, defaults, edge cases, and error formats
that make a good checklist. Pages are under `https://udaykhare09.github.io/Aegon/guide/`:

| Subtask | Pages |
|---|---|
| 01 | `routing`, `middleware`, `context`, `request`, `response`, `getting-started` |
| 02, 13 | `validation`, `context`, `error-handling` |
| 03 | `error-handling`, `context` |
| 04 | `auth`, `jwt`, `middleware` |
| 05 | `jwt` |
| 06 | `security-headers` |
| 07, 14 | `access-log`, `logging` |
| 08 | `sse`, `static-files`, `response`, `cors`, `compress` |
| 09 | `data/memory/memstore`, `data/sql/cache` |
| 10 | `data/redis/client`, `data/redis/advanced`, `data/redis/topologies` |
| 11 | `cli`, `getting-started` |
| 12 | `config`, `data/sql/config`, `server` |
| 15 | `data/types` |
| 16 | `data/sql/schema`, `data/sql/querying`, `data/sql/mutations`, `data/sql/relations`, `data/sql/transactions`, `data/sql/config` |
| 17 | `data/sql/cache`, `data/sql/transactions`, `data/memory/memstore` |

## Left out

| Idea | Why not |
|---|---|
| Large prefaulted buffer pools on huge pages | They cost memory and buy no rate on these tiers: 16,384 buffers of 4 KB are 256 MB on 4 workers, and 256 buffers a worker came within 2.4% of them in every column. goose-http's task 057 records the same for the engine. |
| A query on every worker's ring, from per-core async pools | Without coroutines each query adds a state to the route; database work runs as one job on a lane (task 052). Each lane thread owning its connections, with no lock, is what carries over. |
| Handlers and middleware registered at run time | `std::function` dispatch and run-time chains. goose-rest inlines routes and middleware into one function ([decisions](../../docs/decisions.md)); subtask 01 shortens the code without changing that. |
| A service registry and a typed per-request bag | goose-rest already has dependency injection, resolved at compile time. `App` is the registry, each `thread_fn worker` that builds it is the composition root, and `cx.app.db` resolves a service as a field read: a missing one is a compile error, not a run-time throw, and a test passes its own `App` to `rest::serve_one`. Request state is `cx.state`, a struct, for the same reason. Aegon needs a registry because every handler is a `std::function` of one signature. Goose couldn't hold one cleanly anyway: it has no general heap, and an ADT is its only dynamic polymorphism (no traits or vtables), so a registry would be an enum of the services, a worse struct. Picking an implementation from configuration remains open (subtask 10). |
| Errors as exceptions, caught at a boundary | `rest::fail` leaves through `return ... from`, and the compiler checks that it runs inside a route. |
| A query builder used at run time for every query | Subtask 16 generates fixed SQL from the schema at build time and keeps a builder only for filters that depend on the request. |
| HTTP/3, and `SEND_ZC` for small responses | goose-http defers HTTP/3; zero-copy sends pay only for large bodies, where goose-http already sends directly. |
| A SIMD router | goose-rest's routes compile to one `if` chain over the path, with no table to search. |

## Acceptance criteria

- [ ] Each subtask done or cancelled with its reason
- [ ] goose-http's task 057 records the engine verdicts
- [ ] The README's status table updated as each taken idea lands
