# 03: RFC 9457 problem details as a preset

Status: todo

Errors are JSON with a snake_case `error` code, and a program can write another shape.
A preset that writes `application/problem+json` (RFC 9457, which replaces RFC 7807)
gives programs that follow it a one-line switch: `type`, `title`, `status`, `detail`,
and `instance` from the request's path.

## Acceptance criteria

- [ ] The preset in `runtime.goose` or a module of its own, covering every error in
      `docs/reference.md`'s table, `rest::fail` included
- [ ] A golden test per field, and one for an error with `detail` and `at`
- [ ] `docs/reference.md`, section 5, shows the switch
