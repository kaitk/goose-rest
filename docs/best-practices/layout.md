# Layout by domain

An application's code is grouped by domain: the part of the product it serves, such as
projects, teams, or time entries. Each domain's folder holds that domain's structs,
errors, rules, routes, jobs, and queries. The kind of code (routes, rules) sets the
file name inside the folder, never the folder name.

The examples in this guide come from a time-tracking API with eight domains and three
audiences, laid out as follows:

```text
app/
  main.goose            App, St, and Waiting, the lanes, the workers, and rest::serve
  dispatch.goose        each audience's scope and stack, then each domain's routes
  stacks.goose          public_routes, user_routes, member_routes
  middleware.goose      authenticate, resolve_organization
  common/
    errors.goose        the errors several domains answer
    calendar/           time zones, days, and weeks
    members/            Member, and what a member may read
    users/              User
  projects/
    structs.goose       Project, CreateInput, UpdateInput, and the domain's enums
    errors.goose        Error, and the status and code each answers
    rules.goose         new_project, archived: typed input in, no cx
    routes.goose        routes(cx, member), then each route's flow in the order it
                        runs: the route, its job, its resume
    queries.goose       find_project, insert_project: one statement each
  entries/              (structs, errors, rules, routes, queries)
  timer/                (structs, errors, rules, routes)
  teams/                (structs, errors, rules, routes, queries)
  reports/              (structs, rules, queries, routes.goose and routes/)
  settings/             (structs, routes, queries)
  availability/         (structs, errors, rules, routes, queries)
  auth/                 (structs, errors, rules, routes, queries)
```

The data model below groups each domain's tables in a box and shows a few columns from
each table. `timer` and `reports` own no tables: they use the tables owned by `entries`.

![The data model: a box per domain, its tables, and the references between them](layout-model.png)

The three audiences are the public, a signed-in user, and a member of an organization.
Each has a stack in `stacks.goose`. The domains serve these purposes:

- **`auth`**: signing in and out, and the session it opens. Public routes:
  `POST /auth/session` signs in, `DELETE /auth/session` signs out. Signing in checks the
  password on a lane of its own, the hasher ([Lanes and jobs](lanes.md)).
- **`settings`**: a user's own preferences, such as time zone and the first day of the
  week, the same in every organization. User routes: `GET` and `PUT /settings`.
- **`projects`**: what an organization tracks time on, and the teams on each. Member
  routes under `/organization/projects`: list, create, update, archive.
- **`teams`**: groups of members, and who is in each. Member routes under
  `/organization/teams`: list, create, add and remove a member.
- **`entries`**: the time recorded, each entry a member's span on a project. Member
  routes under `/organization/entries`: list a week, create, edit, delete.
- **`timer`**: the running entry, one per member at most. Member routes under
  `/organization/timer`: `GET` it, `POST` to start, `DELETE` to stop. It owns no data
  of its own: it starts and stops entries.
- **`reports`**: totals of entries by project, team, or member over a period, and the
  entries behind them, for export. Member routes, read only:
  `GET /organization/reports/...`. It owns no data either. Its rules sum the entries,
  and its jobs run on a lane of their own, so that under load they are refused before
  other work ([Lanes and jobs](lanes.md#choosing-which-work-is-refused-under-load)).
  An export's entries are a long answer, sent in pieces
  ([A reply in pieces](../tutorial/12-two-lanes.md#a-reply-in-pieces)). Its five
  operations each have a file in `reports/routes/`
  ([When a domain grows](#when-a-domain-grows)).
- **`availability`**: the hours each member expects to work on each weekday, which
  reports compare with the time recorded. Member routes under
  `/organization/availability`: `GET` and `PUT`.
- **`common/`**: shared code, with no routes. `users` holds `User`, and `members` holds
  `Member`, a user in an organization. The stacks look these up and pass them to every
  user or member route. This folder also holds errors used by several domains and
  `calendar`: time zones and the days and weeks that `entries`, `timer`, `reports`, and
  `availability` split time into.

[`layout/`](layout/) is a smaller program laid out the same way, with three domains:
`projects`, `teams`, and `settings`.

## A folder per domain

Put all of a domain's code in one folder named for the domain, such as `projects/`.

A feature change then touches one folder. Reviewers can identify the domain from the
paths alone, and the folder shows the domain's size. A layout by kind
(`routes/`, `rules/`, `queries/`) spreads one feature across every folder.

## The same files in every domain

Each kind of code has one file name, the same in every domain and in `common/`:

| File | Holds | Example |
|---|---|---|
| `structs.goose` | The domain's structs and enums, and their `format` overloads | `Project`, `CreateInput` |
| `errors.goose` | The domain's `Error` enum, and the status and code of each variant | `Error.NotFound` |
| `rules.goose` | Functions of typed input that return a result or an `Error`, with no `cx` | `new_project` |
| `routes.goose` | `routes`, the domain's entry, then each route's flow in the order it runs: the route, the jobs it asks lanes for, and its `resume` case functions | `create`, `create_project` |
| `queries.goose` | The domain's data access: a function per database statement, which jobs call | `find_project` |

A domain has the files it needs and no others: `settings/` in the program has no rules
or errors, and a domain with no tables of its own, such as `timer`, has no queries.

Someone familiar with one domain can find the same kinds of code in every other.
A file's name tells a reviewer what kind of change to expect.

A route and its `resume` functions, a job, a query, and a rule are the controller, the
transactional service method, the repository, and the domain logic of a Spring
application ([Concepts and naming](concepts.md#the-concepts)).

A job only orchestrates: it opens the transaction, calls queries to read and write,
calls rules to decide, and commits. When a job grows, what grows is a decision that
belongs in a rule, or a statement that belongs in a query. Rules then hold the domain's
logic, and a test calls them as plain functions, with no server, thread, or database.

## When a domain grows

Split a domain by operation once its `routes.goose` holds too many flows to follow in
one file. Keep `routes` and the paths in `routes.goose`. Move each operation's flow,
including its route, jobs, and `resume` functions, to its own file in a `routes/` folder
beside it. The domain's structs, errors, rules, and queries stay shared:

```text
reports/
  structs.goose       Report, Breakdown, the inputs, the jobs' and replies' structs
  errors.goose        Error, and check
  rules.goose         totals, split_days: the sums, with no I/O
  queries.goose       find_settings, list_entries: one statement each
  routes.goose        routes(cx, member): the paths, each calling its operation
  routes/
    totals.goose      GET /totals: the route, its job on the reports lane, its resume
    breakdown.goose   GET /breakdown: the route, its job, its resume
    export.goose      GET /export: the route, its job, its reply in pieces
```

The files in `routes/` also declare the domain's namespace, `namespace reports;`.
Moving a function between files therefore requires no changes to its callers. A domain
can start in one file and split as it grows, whereas a Java application splits into
classes from the start.

## A domain is a namespace

Each file of a domain declares the domain's namespace, `namespace projects;`. A call
from outside the domain names it once, `projects::routes(cx, member)`, and the names
inside leave it out ([A name doesn't repeat its domain](concepts.md#a-name-doesnt-repeat-its-domain)).
A folder in `common/` has a namespace with the same name, such as `members`, and
`common/`'s own files are in `common`.

## Shared code moves to `common/`

Code starts in the domain that needs it. Move it to `common/` when a second domain needs
it, and not before. `common/` is laid out as a domain is, by the entity it serves:
`common/members/structs.goose` holds `Member`, which every member route is given.

Moving code early means guessing what other domains will need. Once a second domain
uses it, two callers show what the shared code needs to do. Organizing `common/` by
entity makes it read the same way as the domains.

## All routing in one file

`dispatch.goose` holds the routes block: each audience's scope, behind its stack, then
each domain's scope and its `routes`. From [`layout/dispatch.goose`](layout/dispatch.goose):

```rust
fn handle(cx) {
    // Middleware every answer gets, the 404s included, goes outside the routes.
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            // A scope per audience, each behind its stack (stacks.goose).
            if rest::on(cx, "GET", "/health") {
                public_routes(cx) { rest::text(cx, 200, "ok"); };
            } else if rest::scope(cx, "/settings") {
                // Authenticates, or answers 401; the block gets the user.
                user_routes(cx) { user => settings::routes(cx, user); };
            } else if rest::scope(cx, "/organization") {
                // The user, then their membership of the organization the
                // request names; the block gets the member.
                member_routes(cx) { member =>
                    if rest::scope(cx, "/projects") {
                        projects::routes(cx, member);
                    } else if rest::scope(cx, "/teams") {
                        teams::routes(cx, member);
                    } else {
                        // Behind the stack: a stranger gets 401, not 404.
                        rest::otherwise(cx);
                    }
                };
            } else {
                rest::otherwise(cx);
            }
        };
    };
}
```

A domain's `routes` matches the rest of the path, after its scope. From
[`layout/projects/routes.goose`](layout/projects/routes.goose):

```rust
fn routes(cx, member: members::Member) {
    if rest::on(cx, "GET", "") {
        list(cx, member);
    } else if rest::on(cx, "POST", "") {
        create(cx, member);
    } else {
        rest::otherwise(cx);
    }
}
```

Every route's path and the stack that guards it are then in one file, so reviewers can
check that no route lacks authentication. A domain doesn't depend on its prefix, so
moving it to another path changes one line.

## The program's types are in `main.goose`

Declare `App`, the worker state, `St`, the request state, and `Waiting`, the steps
of the routes that wait, in `main.goose`, beside the workers that pass them to
`rest::serve`.

Each is one type for the whole program: every domain's routes get the same `cx`, so no
domain owns them. A domain still owns its `Waiting` variants, named for it, and their
`resume` functions are in its `routes.goose`
([Structuring a route that waits](lanes.md#structuring-a-route-that-waits)).

## With an OpenAPI schema

The generator writes one file for the whole API, `api_gen.goose`, beside `main.goose`,
and its router calls every handler in one namespace, `app` by default
([Run it](../generator.md#run-it)). The generator doesn't yet support writing each
domain's part into its folder according to the operations' OpenAPI `tags`. Until it
does, keep the handlers in one file. Each handler calls its domain's rules or asks for
its job; the rest of the code stays in the domain.

---

[Best practices](README.md) · Previous: [Concepts and naming](concepts.md) · Next:
[Routes and rules](routes-and-rules.md)
