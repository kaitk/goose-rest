# Layout by domain

An application's code is grouped by domain: the part of the product it serves, such as
projects, teams, or time entries. Each domain's folder holds that domain's structs,
errors, rules, routes and jobs, and queries. The kind of code (routes, rules) sets the
file name inside the folder, never the folder name.

The application this section's pages take their examples from is a time-tracking API
with eight domains and three audiences, laid out this way:

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

Its data model, a box per domain around the tables it owns, with a few columns of each.
`timer` and `reports` own no tables: they work on `entries`'.

![The data model: a box per domain, its tables, and the references between them](layout-model.png)

The three audiences are the public, a signed-in user, and a member of an organization,
each with its stack in `stacks.goose`. The domains:

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
- **`common/`**: `users` (`User`) and `members` (`Member`, a user in an organization),
  which the stacks look up and every user or member route is given, the errors several
  domains answer, and `calendar`: time zones, and the days and weeks that `entries`,
  `timer`, `reports`, and `availability` split time into. No routes.

[`layout/`](layout/) is a smaller program laid out the same way, with three domains:
`projects`, `teams`, and `settings`.

## A folder per domain

Put all of a domain's code in one folder named for the domain, such as `projects/`.

A change to a feature then touches one folder, a reviewer sees which domain it changes
from the paths alone, and a domain's size shows in its folder. A layout by kind
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

Someone who knows one domain then knows where everything is in every other, and a
file's name says what kind of change a diff makes.

A route and its `resume` functions, a job, a query, and a rule are the controller, the
transactional service method, the repository, and the domain logic of a Spring
application ([Concepts and naming](concepts.md#the-concepts)).

A job only orchestrates: it opens the transaction, calls queries to read and write,
calls rules to decide, and commits. When a job grows, what grows is a decision that
belongs in a rule, or a statement that belongs in a query. Rules then hold the domain's
logic, and a test calls them as plain functions, with no server, thread, or database.

## When a domain grows

Split a domain by operation once its `routes.goose` holds more flows than a reader
follows in one file: `routes.goose` keeps `routes` and the paths, and each operation's
flow, its route, jobs, and `resume` functions, moves to a file of its own in a
`routes/` folder beside it. The domain's structs, errors, rules, and queries stay shared:

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

The files in `routes/` declare the domain's namespace too, `namespace reports;`, so
moving a function between files changes no call to it: a domain can start in one file
and split when it's long, where a Java application splits into classes from the start.

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

Code moved early guesses at what other domains will need. Code moved once a second
domain uses it has two callers that show its shape. Laid out by entity, `common/` reads
the same way as the domains do.

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

Every route's path, and the stack that guards it, is then in one file, where a review
checks that no route is left without authentication. A domain doesn't know its prefix,
so moving it to another path changes one line.

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
([Run it](../generator.md#run-it)). Writing each domain's part into its folder, by each
operation's OpenAPI `tags`, isn't supported yet. Until it is, keep the handlers in one
file, each a call into its domain's rules or an ask for its job, so that the domains
keep the rest of their code.

---

[Best practices](README.md) · Previous: [Concepts and naming](concepts.md) · Next:
[Routes and rules](routes-and-rules.md)
