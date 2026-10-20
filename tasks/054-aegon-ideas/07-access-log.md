# 07: Access log options

Status: todo. Writes through subtask 14's logger once it exists.

`rest::timed` writes one fixed line to standard error. Aegon's
[access log](https://udaykhare09.github.io/Aegon/guide/access-log) (read 2026-10-20)
has:

- Formats: a combined line, Common Log Format, JSON lines, or the program's own
  formatter
- A level per status class: 2xx and 3xx, 4xx, and 5xx
- A slow threshold that tags the line and raises its level
- Fields to include: the query, the client address (from `X-Forwarded-For` or
  `X-Real-IP`), the byte count, and the protocol
- Request and response fields to copy onto the line, such as `x-request-id` and
  `user-agent`
- Paths to skip, such as `/health`, and a predicate to skip by
- A request logger for the route: every line the route writes carries the correlation
  ID (a header named in the options, `x-request-id` by default), the method, and the path

The options are fixed per scope, so the choices compile into the middleware's block.

## Acceptance criteria

- [ ] The formats, levels, slow threshold, fields, and skip rules above
- [ ] A request ID header, echoed in the response when present, on every line the route
      logs
- [ ] Tests on each format's output, and `docs/reference.md` updated
- [ ] Tier A's instructions per request with the log on, against `rest::timed`
