# 09: The context of task 015's A and B in use

Checks task 015's A (the router in the context, `plod::routes(cx) { cx => ... }` with
`plod::on`, `plod::scope`, `plod::param`, and `plod::otherwise` taking `cx` alone) and B
(the worker's state in the context, `cx.app`, from `plod::serve(cfg, app)`) on a program
that does more than the simple cases, built on the package as task 015's prototype
changes it:

- hand-written routes before the generated `dispatch`, on a path the schema has too;
- a route that asks a database thread with `plod::ask` and resumes at the WAKE;
- `app::visible`, a helper three calls below a route that reads the router (`:id`), the
  worker's state (the projects), and the request's (the user);
- `/admin`, a scope with a middleware of the program's own, `audited`;
- the user, looked up through `plod::once` by both the security check and the handler;
- a function that types its context through an alias,
  `type Cx = plod::Cx<St, App, http::Router>;`.

`main` plays goose-http's loop, as spike 06 does: each request goes through
`plod::on_event`, the code `plod::serve` runs, and each reply message addressed to it
comes back as a WAKE, so the output is fixed. `api_gen.goose` is `plod gen`'s from
`api.json`. `refused.goose` holds the calls the context's type refuses.

Goose: commit `f114b5a`, the pin, with the same output as on release `v2026.2` (`3ee3871`), `v2026.1` (`ac759c3`) and `bc3c1f1`. goose-http: `ebb4238`, with the same output as at `v0.5.4`, `v0.5.3`, `v0.5.2`, `cbffc2a`, `5701a0d`, `b5f82a2`, `v0.4.3`, `v0.4.2`, `v0.4.1`, `v0.4.0`, `ff18ecc`, `v0.3.6`, `6e57c42`, `v0.3.5`, `v0.3.4`, `v0.3.3`, `v0.3.2` and `v0.3.1`. goose-rest: task 015's prototype, A
with the router's type in the context, `Cx<S, A, R>`, and B; its report asks the
database lane with task 050's `plod::ask` of a lane's job (2026-10-19), with the same
output.

```sh
GOOSE=<build>/goose
$GOOSE ../../gen/main.goose -- gen api.json -o api_gen.goose
$GOOSE build -o ../../build/spike09 main.goose && ../../build/spike09
$GOOSE check refused.goose   # fails to compile
```

## Verdict: works; outside `plod::routes`, a route's calls don't compile

```text
-- health: HTTP/1.1 200 OK ok
-- generated GET, helper reads :id: HTTP/1.1 200 OK {"id":1,"name":"goose","owner":"ada"}
-- generated GET, another's project: HTTP/1.1 403 Forbidden {"error":"not_owner"}
-- hand-written PUT before dispatch: HTTP/1.1 200 OK {"id":1,"name":"swan","owner":"ada"}
-- 405 across both: HTTP/1.1 405 Method Not Allowed (Allow: PUT, GET, HEAD, DELETE) {"error":"method_not_allowed"}
-- asks the database, resumes, 1 wake: HTTP/1.1 200 OK gander has 6 tasks
-- scope with its own middleware: HTTP/1.1 202 Accepted reindexing; audits 1
-- the same, refused: HTTP/1.1 403 Forbidden {"error":"admin_only"}
-- plod::once across check and handler: HTTP/1.1 200 OK ada sees 2 projects; lookups 7
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
- One `plod::routes` block holds the hand-written routes and `dispatch`, whose 405 lists
  both, without the program passing `r.allow`.

What reads worse:

- `plod::routes(cx) { cx => ... }` rebinds `cx`, one more level of nesting in `handle`.
- A program that keeps per-request state and no worker's state passes a placeholder:
  `var none = plod::NoState { .. }; plod::serve(cfg, none, St { .. })`. Today it's
  `plod::serve(cfg, St { .. })`.
- A typed context names three types, `plod::Cx<St, App, http::Router>` inside
  `plod::routes` and `plod::Cx<St, App, plod::NoRouter>` outside, and an error names them
  all.

### The router's type in the context

The first prototype of A held the router as an optional reference, null outside
`plod::routes` (goose-rest `7ae83b0`). There each of these compiled and answered at run
time, where today's API refuses to compile:

- `plod::on` outside `plod::routes` was false for every route, and `plod::otherwise`
  answered 404. Today a route needs the `http::Router` the program built.
- At a WAKE, where no `plod::routes` block runs, `plod::on` was false and `plod::param`
  read `""`. Today a resume function has no router to pass.
- `app::visible`, called from a generated handler under `dispatch` alone, failed with 400
  `id: integer`. Today the helper takes an `http::Router`, which a generated handler
  doesn't have.

With the router's type a parameter of the context, an `http::Router` inside
`plod::routes` and a `plod::NoRouter` elsewhere, each is refused, as `refused.goose`
shows, one at a time:

```text
refused.goose:11: error: no matching overload for call to plod::param
  candidate plod::param at .../extract.goose:91: argument 1: cannot pass plod::Cx<app::St, app::App, plod::NoRouter> as plod::Cx<S, A, http::Router>&
refused.goose:15: error: no matching overload for call to plod::on
  candidate plod::on at .../middleware.goose:175: argument 1: cannot pass plod::Cx<app::St, app::App, plod::NoRouter> as plod::Cx<S, A, http::Router>&
app.goose:49: error: no matching overload for call to plod::param_int
  candidate plod::param_int at .../extract.goose:96: argument 1: cannot pass plod::Cx<app::St, app::App, plod::NoRouter> as plod::Cx<S, A, http::Router>&
```

One stays silent: inside `plod::routes`, a generated handler that calls `app::visible`
reads the path parameters of the last hand-written route whose path matched, here
`PUT /v1/projects/:id`, which happens to name `:id` the same. A hand-written route that
named it `:pid` would make `visible` fail with 400. The generated handler gets `id` as an
argument, and should pass it on, as `owned(cx, id)` does.

B makes nothing silent: `plod::serve(cfg, St { .. })` written as today no longer
compiles ("no matching overload"), since the worker's state is a reference and a
temporary can't be one, and a handler that reads a field `App` lacks fails to compile
as `state.field` does today.
