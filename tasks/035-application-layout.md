# 035: Best practices, a section of the docs on laying out an application

Status: built (2026-10-15); the testing page, the data-access page, and a full example
application open (asked for 2026-10-15; a docs section, not a tutorial part)

The tutorial's pages teach goose-rest's mechanisms one at a time, and leave how a whole
application is laid out to the reader. A "Best practices" section of its own, beside
the tutorial and the reference, gives one opinionated way to do it, as Angular's "Best
Practices" (its style guide), Spring Boot's "Structuring Your Code", and Elysia's "Best
Practice" do apart from their tutorials (2026-10-15). It's the way goose-rest's
authors build their own applications, and recommend following. It isn't required, and
says so once, but it doesn't hedge or list alternatives: one answer to each question a
growing application meets, where the tutorial shows the options. The value is in a
convention everyone follows, so the section picks one and keeps to it (2026-10-15). Its model is snowtime's backend, which is
grouped by domain: `src/server/<domain>/` holds the domain's routes, its rules, and its
schemas; a route only wires, its handler one call of its rule; and code starts in its
domain and moves out once a second one needs it (snowtime's `AGENTS.md`).

Its pages show the conventions with short excerpts, not a whole application: one built
now would fake its data access and authentication, the parts a layout most needs to
show. A full example application waits until goose-rest has database helpers and a JWT
implementation (2026-10-15). Each page's excerpts come from a small program of its
own, checked as the tutorial's are, so they keep compiling.

The conventions stick best where tooling follows them, as Rails's and Phoenix's
generators create files where the conventions put them: the generator's placement by
tag (below) is that step, later.

## What the section settles

1. **Layout, by domain** (2026-10-15). A folder per domain (or feature) holds all of
   that domain's code: its structs, routes, services, and data access, each
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
   `tenant`) (2026-10-15). Task 034 builds stacks; this section names them.
4. **State and services.** What goes per worker, on a service thread, and in the shared
   store, by what the data is (task 027).
5. **Errors.** One shape, and each domain's codes in one place.
6. **Naming.** The files of a domain by their kind, the same in every domain and in
   `common/`; and the names inside them: structs, routes, rules, services, data-access
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
   Decided (2026-10-16), replacing the names above: the thread is a *lane* and the use
   case a *job* (`docs/decisions.md`, "Waiting on another thread"); a domain's jobs are
   in its `routes.goose`, after the route that asks for each, in flow order; data access
   is `queries.goose`; a growing domain splits by operation into `routes/`.
8. **Testing** (2026-10-15). Goose's own convention, which every one of these packages
   follows ([decisions](../docs/decisions.md#tests)):
   - **A top-level `test/`, a folder per domain**: `test/projects/`, `test/entries/`.
     Each test is a small program that prints what it checks, against its golden file
     in `test/expected/`: the domain's rules as plain calls, and its routes,
     middleware, and stacks through `rest::serve_one`, a service's reply or timeout
     included. The runner batches the builds, so many small tests cost little, and a
     failure ends one test, not the run.
   - **Scenarios over HTTP**: a folder per scenario under `test/`, which runs the real
     program (its workers, service threads, and later its database) and compares its
     answers with a golden file, plus `test/fixtures/` for their data. By scenario,
     not domain, since they cross domains.
   - **`// error:` fixtures** for what must not compile, such as a route given the wrong
     state type.
   - The rule: a test that needs a socket, a thread, or more than one domain is a
     scenario; every other is a small test in its domain's folder, and most should be.

## Proposal: snowtime's API laid out this way (2026-10-15)

snowtime's backend has eight domains (`auth`, `availability`, `entries`, `projects`,
`reports`, `settings`, `teams`, `timer`) and three audiences, set by middleware order:
public, signed in (`signedIn`), and a member of the organization in the path
(`organization`, under `/organizations/:organizationId`). In goose-rest:

```text
app/
  main.goose            App, St, Waiting, the workers, and serve
  dispatch.goose        audiences by scope, then each domain's routes
  stacks.goose          public_routes, user_routes, member_routes
  middleware.goose      authenticate, resolve_organization
  common/
    scope/              roles, and what a member may read
    errors.goose        the error shape and the shared codes
  projects/
    structs.goose       Project, CreateInput, UpdateInput, ..., and the domain's enums
    errors.goose        Error, and a check case function per variant: status and code
    rules.goose         new_project, archived: typed input in, no cx
    routes.goose        routes(cx, member), one function per route, its case functions
    service.goose       the jobs on the database thread, one transaction each
    dao.goose           one query per function
  entries/  timer/  teams/  reports/  settings/  availability/  auth/
                        the same files, as far as each needs them
```

Each domain is a namespace, so a name doesn't repeat its domain, and each layer has a
name shape of its own, so a call chain shows the layer:

| Kind | Shape | Examples |
|---|---|---|
| Stack | audience, singular, `_routes` | `public_routes`, `user_routes`, `member_routes` |
| Middleware | verb | `authenticate`, `resolve_organization` |
| Block parameter | what it's given | `user`, `member` |
| A domain's entry | `routes` | `projects::routes(cx, member)` |
| Route | the operation's verb | `list`, `create`, `archive`, `add_team` |
| Rule | what it returns | `new_project`, `archived`, `readable` |
| Service job | verb and noun | `create_project`, `archive_project` |
| Data access | query verb and noun | `find_project`, `list_projects`, `insert_project` |
| Structs | noun, and `<Verb>Input` | `Project`, `CreateInput` |
| `Waiting` variant | domain and operation | `Waiting.ProjectCreate` |

Decided in review (2026-10-15):

- A domain has `errors.goose`, its `Error` enum and a `check` case function per variant
  giving its status and code, and `rules.goose`, its rules. `common/errors.goose` holds
  the shared errors the same way.
- A rule is named for what it returns (`new_project`, `archived`, `readable`).
- A domain's entry is `routes`.
- `App`, the per-request state `St`, and `Waiting` are declared in `main.goose`, as
  they're program-wide.
- The section's programs use only goose-rest's public API. `rest::scope` matches
  literal prefixes only, so the member audience's `/organizations/:id` waits on task
  036. Until then, the programs scope the member routes under a literal
  `/organization`, and `resolve_organization` reads the id from an `X-Organization`
  header with `rest::header`.

Later, in the generator (may become its own task): with one schema for the application,
write each domain's part into its folder. An operation's place is its OpenAPI `tags`,
which many schemas already set; a schema's is the domain of the operations that use
it, or `common/` for one that several domains use. An extension (`x-goose-domain`)
only overrides that, and a configuration names the folders.

## Open: authentication when sessions are in the database (2026-10-16)

The middleware page's `authenticate` reads sessions from a global. With sessions in a
database, a stack can't look one up without waiting, and page 13 puts a database check
that comes before the route's work in the route's job. snowtime-native does the same:
its session check runs on the database lane, in the call that serves the route.
Proposed: the stack checks only what needs no database (the token's form, and a signed
token's HMAC), and the job checks the session and the member's role in its
transaction, as it needs the member's scope for its queries anyway. Not decided: the
stacks' shape changes with it, so the middleware page waits for the decision.

## Acceptance criteria

- [x] `docs/best-practices/lanes.md`: a lane for each kind of slow work, CPU work on a
      lane, reports behind a small box of their own, a route on two lanes,
      and the domains' `resume` forwarded from global ones (2026-10-16)
- [ ] The decision above, and the middleware page and its program changed to it
- [x] `docs/best-practices/`, an index (`README.md`) that says once that it's the
      recommended way and not required, and a page per topic above, or fewer where
      they're short; each rule with its reason, and an anchor a review can link
- [ ] The testing page's examples: a stub states the rule until task 038 moves
      goose-rest's own tests to the convention the page shows
- [x] Each page's excerpts come from a small program of its own under
      `docs/best-practices/`, and `scripts/test.sh` checks them as it checks the
      tutorial's code
- [x] Each kind of code (structs, routes and jobs, queries) has one file name and place
      in every domain and in `common/`, given in one table (2026-10-16)
- [x] `concepts.md` in place of `naming.md`: each concept, its Spring, Actix-web, and
      Axum equivalent, and its name (2026-10-16)
- [x] Each convention given once, and linked from the tutorial page it builds on (page
      7 links its naming, page 8 its state, page 16 its testing); the tutorial's index
      and last page, and the README, link the section
- [ ] Later, once goose-rest has database helpers and transactions: the data-access
      page (point 7), with `queries.goose` in the lanes program; open, as goose-rest has
      no database helpers yet
- [ ] Later, once goose-rest also has a JWT implementation: a full example application
      laid out this way, in `examples/`; open, as it would fake its data access and
      authentication
