# 09: The context of task 015's A and B in use

Checks task 015's A (the router in the context, `rest::routes(cx) { cx => ... }` with
`rest::on`, `rest::scope`, `rest::param`, and `rest::otherwise` taking `cx` alone) and B
(the worker's state in the context, `cx.app`, from `rest::serve(cfg, app)`) on a program
that does more than the simple cases, built on the package as task 015's prototype
changes it:

- hand-written routes before the generated `dispatch`, on a path the schema has too;
- a route that asks a database thread with `rest::ask` and resumes at the WAKE;
- `app::visible`, a helper three calls below a route that reads the router (`:id`), the
  worker's state (the projects), and the request's (the user);
- `/admin`, a scope with a middleware of the program's own, `audited`;
- the user, looked up through `rest::once` by both the security check and the handler;
- a function that types its context through an alias,
  `type Cx = rest::Cx<St, App, http::Router>;`.

`main` plays goose-http's loop, as spike 06 does: each request goes through
`rest::on_event`, the code `rest::serve` runs, and each reply message addressed to it
comes back as a WAKE, so the output is fixed. `api_gen.goose` is `goose-rest gen`'s from
`api.json`. `refused.goose` holds the calls the context's type refuses.

Goose: release `v2026.1` (`ac759c3`), with the same output as on `bc3c1f1`. goose-http: `v0.3.3`, with the same output as at `v0.3.2` and `v0.3.1`. goose-rest: task 015's prototype, A
with the router's type in the context, `Cx<S, A, R>`, and B.

```sh
GOOSE=<build>/goose
$GOOSE ../../gen/main.goose -- gen api.json -o api_gen.goose
$GOOSE build -o ../../build/spike09 main.goose && ../../build/spike09
$GOOSE check refused.goose   # fails to compile
```

## Verdict: works; outside `rest::routes`, a route's calls don't compile

```text
-- health: HTTP/1.1 200 OK ok
-- generated GET, helper reads :id: HTTP/1.1 200 OK {"id":1,"name":"goose","owner":"ada"}
-- generated GET, another's project: HTTP/1.1 403 Forbidden {"error":"not_owner"}
-- hand-written PUT before dispatch: HTTP/1.1 200 OK {"id":1,"name":"swan","owner":"ada"}
-- 405 across both: HTTP/1.1 405 Method Not Allowed (Allow: PUT, GET, HEAD, DELETE) {"error":"method_not_allowed"}
-- asks the database, resumes, 1 wake: HTTP/1.1 200 OK gander has 6 tasks
-- scope with its own middleware: HTTP/1.1 202 Accepted reindexing; audits 1
-- the same, refused: HTTP/1.1 403 Forbidden {"error":"admin_only"}
-- rest::once across check and handler: HTTP/1.1 200 OK ada sees 2 projects; lookups 7
-- generated DELETE: HTTP/1.1 204 No Content
audits 1, lookups 8
```

(`expected.txt` keeps the space after `204 No Content`.)

What reads better:

- Every function below `handle` takes `cx` alone: `visible(cx)`, `admin(cx)`,
  `report(cx)`, and the generated handlers. Today each takes `cx`, the worker's state,
  and, where it matches routes or reads a path parameter, `r`: `visible(cx, app, r)`.
- `audited`, the program's middleware, reaches the user and the worker's counts through
  `cx`, so its block is `{ admin(cx); }`, with nothing to thread through.
- The resume functions read the worker's state, `cx.app.projects`, where today the
  program passes it to the handler and on to each `resume`.
- One `rest::routes` block holds the hand-written routes and `dispatch`, whose 405 lists
  both, without the program passing `r.allow`.

What reads worse:

- `rest::routes(cx) { cx => ... }` rebinds `cx`, one more level of nesting in `handle`.
- A program that keeps per-request state and no worker's state passes a placeholder:
  `var none = rest::NoState { .. }; rest::serve(cfg, none, St { .. })`. Today it's
  `rest::serve(cfg, St { .. })`.
- A typed context names three types, `rest::Cx<St, App, http::Router>` inside
  `rest::routes` and `rest::Cx<St, App, rest::NoRouter>` outside, and an error names them
  all.

### The router's type in the context

The first prototype of A held the router as an optional reference, null outside
`rest::routes` (goose-rest `7ae83b0`). There each of these compiled and answered at run
time, where today's API refuses to compile:

- `rest::on` outside `rest::routes` was false for every route, and `rest::otherwise`
  answered 404. Today a route needs the `http::Router` the program built.
- At a WAKE, where no `rest::routes` block runs, `rest::on` was false and `rest::param`
  read `""`. Today a resume function has no router to pass.
- `app::visible`, called from a generated handler under `dispatch` alone, failed with 400
  `id: integer`. Today the helper takes an `http::Router`, which a generated handler
  doesn't have.

With the router's type a parameter of the context, an `http::Router` inside
`rest::routes` and a `rest::NoRouter` elsewhere, each is refused, as `refused.goose`
shows, one at a time:

```text
refused.goose:11: error: no matching overload for call to rest::param
  candidate rest::param at .../extract.goose:91: argument 1: cannot pass rest::Cx<app::St, app::App, rest::NoRouter> as rest::Cx<S, A, http::Router>&
refused.goose:15: error: no matching overload for call to rest::on
  candidate rest::on at .../middleware.goose:175: argument 1: cannot pass rest::Cx<app::St, app::App, rest::NoRouter> as rest::Cx<S, A, http::Router>&
app.goose:49: error: no matching overload for call to rest::param_int
  candidate rest::param_int at .../extract.goose:96: argument 1: cannot pass rest::Cx<app::St, app::App, rest::NoRouter> as rest::Cx<S, A, http::Router>&
```

One stays silent: inside `rest::routes`, a generated handler that calls `app::visible`
reads the path parameters of the last hand-written route whose path matched, here
`PUT /v1/projects/:id`, which happens to name `:id` the same. A hand-written route that
named it `:pid` would make `visible` fail with 400. The generated handler gets `id` as an
argument, and should pass it on, as `owned(cx, id)` does.

B makes nothing silent: `rest::serve(cfg, St { .. })` written as today no longer
compiles ("no matching overload"), since the worker's state is a reference and a
temporary can't be one, and a handler that reads a field `App` lacks fails to compile
as `state.field` does today.
