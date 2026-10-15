# 036: Parameters in a scope's prefix

Status: todo, research (asked for 2026-10-15)

`rest::scope(cx, prefix)` matches one or more literal segments (`/v1`, `/api/v1`) and
narrows the router's path to the rest (`narrowed` in `middleware.goose`). An API whose
routes sit under a resource, such as snowtime's under
`/organizations/:organizationId`, can't scope them there: a stack such as
`member_routes` (task 035) needs the organization's id before the domain's routes match,
to check membership once for all of them.

## Questions

1. Can a scope's prefix hold parameters (`/organizations/:id`), with the value
   readable inside the scope (`rest::param(cx, "id")`, `rest::param_int`) and by the
   middleware around the routes, such as `resolve_organization`?
2. Where goose-http's `http::Router` keeps parameters, and whether a route's
   `rest::on` inside the scope keeps or overwrites the scope's. A route's own `:id` and
   the scope's must both be readable, or the names must differ, said where.
3. The cost: a literal prefix compares bytes; a parameter makes the scope find a
   segment's end. Measured on a route behind a scope, with `bench/routes.sh` or tier R's
   instruction count, against the literal scope.
4. What a program does meanwhile: a literal scope (`/organizations`), then the stack
   reads the next segment itself and narrows past it. Whether that's good enough to be
   the answer, with a helper.
5. The generated router: OpenAPI paths repeat the prefix in every operation
   (`/organizations/{organizationId}/projects`). Whether the generator groups
   operations by a shared prefix with a parameter, so the stack wraps the group, or
   only by literal prefixes as now.
6. Whether it needs goose-http (a router call that narrows past a parameter), or fits
   in goose-rest over `http::Router` as `narrowed` does now.

## Acceptance criteria

- [ ] Each question answered here, with a minimal program for the ones that need one
- [ ] A recommendation: parameters in `rest::scope`, a helper for the workaround, or
      neither, with its cost measured and how
- [ ] If it's built: tests, the reference's `rest::scope` row, and tutorial page 7's
      scopes, in a task of its own or here, as decided with the user
