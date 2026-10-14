# 015: Win back the plan's API where Goose and goose-http now allow it

Status: todo (asked for 2026-10-14)

The plan (`docs/plan.md` in `923c4fb`) wrote handlers and the generated router in calls
that read as the route means. The built API drifted from them, call by call, as each
part met Goose or goose-http's API at the time:

| The plan | Built |
|---|---|
| `fn get_project(cx: rest::Cx&, app: App&, ...)` | `fn get_project(cx, state, ...)`: `Cx<S>` is generic in the per-request state |
| `cx.path`, `cx.is("GET")` | `http::path_of(cx.req.target)`, `cx.req.method == "GET"` |
| `return rest::route(cx) { app::health(cx, app) };` | `rest::route(cx) { app::health(cx, state); };` then `return;` |
| `rest::not_allowed(cx, "GET, HEAD")`, `rest::not_found(cx)` | `rest::no_method(cx, "GET, HEAD", allow)`, `rest::not_found(cx, m, path, allow)` |
| `rest::under(path, "/projects/")`, `rest::segment_int(cx, 10)` | `rest::segment(path, at)`, `rest::segment_is(seg, lit, plain)`, `rest::path_int(cx, seg, "id")` |
| A route in `handle` as a `rest::route` block | `var r = http::router(cx.req)`, `if http::on(r, ...)`, and `r` passed on for `rest::param(cx, r, "name")` |

The generated router's calls matter less than a program's: nobody writes them, and the
architecture doc shows them as they are. A handler's signature, the context's fields,
and hand-written routes are what a program reads and writes.

goose-http has worked on its own API since `e27ab21` (its task 027): `Request` helpers
by reference, an `Event` enum, a `Router` built once rather than per request, and a list
of rough edges found against goose-rest, among them a package helper for gathering a
long body, constants for `finish`'s fields, and a supported way to add a field to every
response. Some drifts may be undone by moving the goose-http pin; others by a change
there, which goes through goose-http's task 027.

For each row, record why it drifted (a Goose limit, goose-http's API, or a choice made
here), whether that still holds at the current pins, and what undoing it costs. A
change lands only if `bench/routes.sh` and task 010's tiers show no slowdown, as in
task 014, and the generated router stays at one route's cost.

## Acceptance criteria

- [ ] Each row above, and any drift found beside them, has its reason and whether it
      still holds at the current Goose and goose-http pins, checked by a spike where the
      answer isn't in the docs
- [ ] goose-http's task 027 changes and its rough-edges list are read for what they make
      possible here, and each that would help is named in this file
- [ ] A recommendation per drift: undo it, undo it after a goose-http change (proposed
      to its task 027, after asking first), or keep it, with the reason
- [ ] The drifts undone are built, with the tutorial, reference, examples, and
      generated code updated, and `bench/routes.sh` measured before and after, recorded
      here with how it was measured
- [ ] A Goose limit that keeps a drift is in `docs/goose-findings.md` with a minimal
      program
