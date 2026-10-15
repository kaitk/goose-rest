# 035: One way to lay out an application, as a part of the tutorial

Status: todo (asked for 2026-10-15)

The tutorial's pages teach goose-rest's mechanisms one at a time, and leave how a whole
application is laid out to the reader. A part of its own gives one opinionated way to
do it: the way goose-rest's authors build their own applications, and recommend
following. It isn't required, and says so once, but it doesn't hedge or list
alternatives: one answer to each question a growing application meets, where the other
pages show the options. The value is in a convention everyone follows, so the part
picks one and keeps to it (2026-10-15). Its model is snowtime's backend, which is
grouped by domain: `src/server/<domain>/` holds the domain's routes, its rules, and its
schemas; a route only wires, its handler one call of its rule; and code starts in its
domain and moves out once a second one needs it (snowtime's `AGENTS.md`).

It rebuilds part two's application in that shape, so the reader sees an application
they know laid out, rather than a new one.

## What the part settles

1. **Layout, by domain** (2026-10-15). A folder per domain (or feature) holds all of
   that domain's code: its types (structs), routes, services, and data access, each
   kind in a file of the same name and place in every domain, so a reader finds a
   domain's routes or queries without looking. What several domains use goes in a
   `common/` folder laid out the same way, by the entity it serves; code starts in its
   domain and moves to `common/` once a second domain needs it. One root file serves
   and dispatches to the domains' routes.
2. **Routes and rules.** A route extracts, validates, calls one rule or service, and
   answers; a rule takes typed input and returns a result or a domain error, with no
   `cx`, so it is tested as a plain call.
3. **Middleware and stacks.** A middleware is named for what it does, a verb
   (`authenticate`, `resolve_tenant`, `limit_rate`), not a participle such as
   `authed`. A stack is named for whose routes it serves: its audience, singular, and
   `_routes` (`public_routes`, `member_routes`, `admin_routes`), as it wraps routes the
   way `rest::routes` does, never a name as generic or keyword-like as `api`; the
   stacks live in one file. A block's parameter is named for what it's given (`user`,
   `tenant`) (2026-10-15). Task 034 builds stacks; this part names them.
4. **State and services.** What goes per worker, on a service thread, and in the shared
   store, by what the data is (task 027).
5. **Errors.** One shape, and each domain's codes in one place.
6. **Naming.** The files of a domain by their kind, the same in every domain and in
   `common/`; and the names inside them: types, routes, rules, services, data-access
   functions, `Waiting` variants, case functions, and stacks.
7. **Data access, once goose-rest has database helpers and transactions** (2026-10-15).
   Two layers per domain, and in `common/` for shared entities. A data-access function
   is one database call, and takes the transaction. A service function opens one
   transaction and combines data-access calls in it. In goose-rest a worker doesn't
   block, so the database is a service thread the route asks: a service function is one
   job on that thread, run in one transaction, so a transaction never spans a worker's
   wait, and "service" keeps the meaning it has in goose-rest, the thread a route asks.
   Validation runs in the route, before the ask. The data-access layer's name is open:
   `dao`, or `queries` as snowtime calls its own, one query per function.
8. **Testing.** Rules as plain calls, routes with `rest::serve_one` (replies included),
   and a few tests over HTTP.

## Acceptance criteria

- [ ] The tutorial gets a part of its own, after the mechanism pages, that says once
      that it's the recommended way and not required, with a page per topic above or
      fewer where they're short
- [ ] Part two's application rebuilt in that layout, as the part's program, its answers
      the same as before and checked by `scripts/test.sh`
- [ ] Each kind of code (types, routes, services, data access) has one file name and
      place in every domain and in `common/`, and the part gives them in one table
- [ ] Each convention given once, with its reason, and linked from the mechanism page
      it builds on (page 7 links its naming, page 8 its state, page 16 its testing)
- [ ] The index lists the part, and the README's tutorial link mentions it
- [ ] Later, once goose-rest has database helpers and transactions: the data-access
      page (point 7), with its layer's name decided
