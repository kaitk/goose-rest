# Layout by domain

An application's code is grouped by domain: the part of the product it serves, such as
projects, teams, or time entries. Each domain's folder holds that domain's structs,
errors, rules, routes, and services. The kind of code (routes, rules) sets the file
name inside the folder, never the folder.

This is a time-tracking API with eight domains and three audiences, laid out this way:

```text
app/
  main.goose            App, St, and Waiting, the workers, and rest::serve
  dispatch.goose        each audience's scope and stack, then each domain's routes
  stacks.goose          public_routes, user_routes, member_routes
  middleware.goose      authenticate, resolve_organization
  common/
    errors.goose        the errors several domains answer
    members/            Member, and what a member may read
    users/              User
  projects/
    structs.goose       Project, CreateInput, UpdateInput, and the domain's enums
    errors.goose        Error, and the status and code each answers
    rules.goose         new_project, archived: typed input in, no cx
    routes.goose        routes(cx, member), a function per route, its case functions
    service.goose       the jobs the routes send the database thread
  entries/  timer/  teams/  reports/  settings/  availability/  auth/
                        the same files, as far as each needs them
```

[`layout/`](layout/) is a smaller program laid out the same way, with three domains:
`projects`, `teams`, and `settings`.

## A folder per domain

Put all of a domain's code in one folder named for the domain, such as `projects/`.

A change to a feature then touches one folder, a reviewer sees which domain it changes
from the paths alone, and a domain's size shows in its folder. A layout by kind
(`routes/`, `rules/`, `services/`) spreads one feature across every folder.

## The same files in every domain

Each kind of code has one file name, the same in every domain and in `common/`:

| File | Holds | Example |
|---|---|---|
| `structs.goose` | The domain's structs and enums, and their `format` overloads | `Project`, `CreateInput` |
| `errors.goose` | The domain's `Error` enum, and the status and code of each variant | `Error.NotFound` |
| `rules.goose` | Functions of typed input that return a result or an `Error`, with no `cx` | `new_project` |
| `routes.goose` | `routes`, the domain's entry, a function per route, and the domain's `Waiting` case functions | `create` |
| `service.goose` | The jobs the domain's routes send its service thread, with `rest::ask` | `create_project` |

A domain has the files it needs and no others: `settings/` in the program has no rules
or errors. A domain's data access, the queries its service jobs run, gets a file of its
own once goose-rest has database helpers.

Someone who knows one domain then knows where everything is in every other, and a
file's name says what kind of change a diff makes.

## A domain is a namespace

Each file of a domain declares the domain's namespace, `namespace projects;`, so the
names inside don't repeat the domain: `projects::CreateInput`, `teams::CreateInput`.

Goose keeps the two apart by namespace, and a call from outside the domain names it
once: `projects::routes(cx, member)`. A folder in `common/` is a namespace of its own
name, such as `members`, and `common/`'s own files are in `common`.

## Shared code moves to `common/`

Code starts in the domain that needs it. Move it to `common/` when a second domain needs
it, and not before. `common/` is laid out as a domain is, by the entity it serves:
`common/members/structs.goose` holds `Member`, which every member route is given.

Code moved early guesses at what other domains will need. Code moved once a second
domain uses it has two callers that show its shape. Laid out by entity, `common/` reads
the same way as the domains do.

## One file dispatches

`dispatch.goose` holds the routes block: each audience's scope, behind its stack, then
each domain's scope and its `routes`. From [`layout/dispatch.goose`](layout/dispatch.goose):

```rust
fn handle(cx) {
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            if rest::on(cx, "GET", "/health") {
                public_routes(cx) { rest::text(cx, 200, "ok"); };
            } else if rest::scope(cx, "/settings") {
                user_routes(cx) { user => settings::routes(cx, user); };
            } else if rest::scope(cx, "/organization") {
                member_routes(cx) { member =>
                    if rest::scope(cx, "/projects") {
                        projects::routes(cx, member);
                    } else if rest::scope(cx, "/teams") {
                        teams::routes(cx, member);
                    } else {
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

## With a schema

The generator writes one file for the whole API, `api_gen.goose`, beside `main.goose`,
and its router calls every handler in one namespace, `app` by default
([Run it](../generator.md#run-it)). Writing each domain's part into its folder, by each
operation's OpenAPI `tags`, isn't supported yet. Until it is, keep the handlers in one
file, each a call into its domain's rules or service, so that the domains keep the rest
of their code.

---

[Best practices](README.md) · Next: [Routes and rules](routes-and-rules.md)
