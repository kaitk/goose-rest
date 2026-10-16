# Concepts and naming

The concepts an application is built from, what each one is, and how each is named.
The other pages define each concept where they use it; this page puts them side by
side.

## The concepts

- **Worker**: a thread that serves thousands of connections, one call at a time
  ([State](state.md)).
- **Domain**: a folder and namespace for one part of the product, such as projects or
  time entries ([Layout by domain](layout.md)).
- **Route**: a function that reads the request, calls a rule or asks for a job, and
  answers ([Routes and rules](routes-and-rules.md)).
- **Middleware**: a function around a route, which may answer instead of running it
  ([Middleware and stacks](middleware.md)).
- **Stack**: the middleware of one audience, under one name.
- **Rule**: a plain function of typed input that decides, with no I/O.
- **Lane**: a thread, or several that run the same jobs, for one kind of slow work
  ([Lanes and jobs](lanes.md)).
- **Box**: the queue of jobs in front of a lane's thread, with a fixed number of slots,
  which a job reaches by mail.
- **Worker state** and **request state**: what a worker keeps for itself, `cx.app`, and
  what one request keeps, `cx.state` ([State](state.md)).
- **Constant**, **store**, and **lane data**: the other places data lives: compiled into
  the program, loaded once at startup into `http.store`, and owned by a lane.
- **Job**: one use case, run on a lane from start to end, in one transaction.
- **Query**: a function per database statement, which jobs call.
- **`Waiting` step and `resume`**: where a route that waits continues when the reply
  comes.
- **Domain error and `check`**: the ways a domain refuses, and the status and code of
  each ([Errors](errors.md)).

<details>
<summary>The same concepts in Actix-web, Axum, Hono, and Spring</summary>

| Concept | Actix-web | Axum | Hono | Spring |
|---|---|---|---|---|
| Worker | A worker thread, one per core | A Tokio worker thread | The event loop, also one thread for many connections | A request thread, which serves one request at a time |
| Worker state | Data given to `app_data` in the `App` each worker builds | The router's `State`, shared by every thread | A module's variables, as the process has one thread | A singleton bean, shared by every thread |
| Request state | The request's extensions | The request's extensions, through `Extension` | The context's variables, `c.set` and `c.get` | A request-scoped bean, or a request attribute |
| Domain | A module, mounted as a `scope` | A module, mounted as a nested `Router` | A sub-app, mounted with `app.route` | A package by feature |
| Route | A handler function | A handler function | A handler, `(c) => ...` | A `@GetMapping` method of a `@Controller` |
| Middleware | Middleware given to `wrap` | A Tower layer, or `middleware::from_fn` | Middleware given to `app.use` | A servlet `Filter`, or a `HandlerInterceptor` |
| Stack | `wrap` on a scope | `layer` on a nested `Router` | `use` on a sub-app | A `SecurityFilterChain` for a path |
| Rule | A plain function | A plain function | A plain function | Domain logic, often inside a service or an entity |
| Lane | A `SyncArbiter` | The `spawn_blocking` pool, which every kind of work shares | A `worker_threads` pool, such as Piscina | The `TaskExecutor` behind `@Async("name")` |
| Box | An actor's mailbox | A bounded Tokio `mpsc` channel | The pool's task queue | The executor's queue |
| Job | A `Message`, and its `Handler` | The closure given to `spawn_blocking` | A task the pool runs | A `@Service` method with `@Transactional` |
| Query | A query function, with sqlx or Diesel | A query function, with sqlx or Diesel | A query function, with Drizzle | A `@Repository` method |
| `Waiting` step, `resume` | The code after `.await` | The code after `.await` | The code after `await` | The callback of a `CompletableFuture` |
| Domain error, `check` | An error type that implements `ResponseError` | An error type that implements `IntoResponse` | An `HTTPException`, and `app.onError` | An `@ExceptionHandler`, or a `ResponseStatusException` |

NestJS follows Spring's model, with modules, controllers, and providers, so Spring's
column reads for it too. Go gives each request a goroutine that may block, so it needs
no `Waiting`; a lane there is a fixed set of goroutines reading one buffered channel,
its box. In Akka, a lane is a dispatcher. A Sidekiq or Celery job is durable, kept in a
store until it runs; a goose-rest job is lost if the server stops.

</details>

## A name doesn't repeat its domain

Each domain is a namespace ([Layout by domain](layout.md#a-domain-is-a-namespace)), so
a name inside it leaves the domain out: `projects::CreateInput`, not
`projects::ProjectCreateInput`, and `projects::routes`, not `projects::project_routes`.

The namespace already says it at every call from outside, and inside the domain the
shorter name is unambiguous.

## A domain is plural, as its paths are

Name a domain for the entity it holds, in the plural, `projects`, as its paths are,
`/organization/projects/42`. What's inside the domain is singular: the struct `Project`,
the code `project_not_found`. A domain that covers an area rather than an entity is
named for the area: `timer`, `auth`, `settings`.

The plural matches the path a client calls, which REST APIs name in the plural (Google's
[AIP-122](https://google.aip.dev/122)), and keeps the namespace apart from the type in
it: `projects::Project`, where a singular domain would read `project::Project`.

## Each layer has a shape of its own

A route is a bare verb, a job a verb and a noun, and a query a query verb and a noun. A
call chain then shows which layer each call is in:

```text
projects::create  ->  create_project  ->  find_project, insert_project
   route              job                  queries
```

The noun in a job's or a query's name is the exception to the first rule: it
distinguishes a job or a query from the route that calls it, and distinguishes the
queries of a job that touches several entities from each other.

## Naming each part

The rules above, applied to each part of an application, from the folders in, then the
way a request takes through it.

### Folders and files

| Part | Named | Examples |
|---|---|---|
| Domain folder, and its namespace | The entity it holds, plural, or the area it covers | `projects/`, `entries/`; `timer/`, `auth/` |
| File in a domain or in `common/` | Its kind ([the files](layout.md#the-same-files-in-every-domain)) | `structs.goose`, `errors.goose`, `rules.goose`, `routes.goose`, `queries.goose` |
| An operation's file, once a domain splits | The operation, in `routes/` ([When a domain grows](layout.md#when-a-domain-grows)) | `routes/totals.goose`, `routes/export.goose` |

### Requests: stacks, middleware, and routes

| Part | Named | Examples |
|---|---|---|
| Stack | Its audience, singular, and `_routes` | `public_routes`, `user_routes`, `member_routes` |
| Middleware | A verb | `authenticate`, `resolve_organization`, `limit_rate` |
| Block parameter | What it's given | `user`, `member` |
| A domain's entry | `routes` | `projects::routes(cx, member)` |
| Route | The operation's verb | `list`, `create`, `archive`, `add_team` |

### The domain: structs, rules, and errors

| Part | Named | Examples |
|---|---|---|
| Struct | A noun, and `<Verb>Input` for what a client sends | `Project`, `CreateInput`, `UpdateInput` |
| Rule | What it returns | `new_project`, `archived`, `readable` |
| Domain error | `Error`, a variant per refusal | `Error.NotFound`, `Error.NameTaken` |
| Error code | The entity, then what went wrong, in snake_case | `project_not_found`, `project_name_taken` |
| Its case function | `check` | `check(err, cx)` |

### Slow work: lanes, jobs, and queries

| Part | Named | Examples |
|---|---|---|
| Lane | What it does | `writer`, `reports`, `hasher` |
| Job | A verb and a noun | `create_project`, `archive_project` |
| Job tag | The job's name, in capitals | `CREATE_PROJECT`, `VERIFY_PASSWORD` |
| `Waiting` variant | The domain, and the operation or what the wait is for | `Waiting.ProjectCreate`, `Waiting.AuthPassword` |
| Its case function | `resume` | `resume(w: Waiting.ProjectCreate, cx)` |
| Query | A query verb and a noun | `find_project`, `list_projects`, `insert_project` |

---

[Best practices](README.md) · Next: [Layout by domain](layout.md)
