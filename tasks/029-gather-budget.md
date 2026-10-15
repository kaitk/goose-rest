# 029: A per-worker budget for bodies being gathered

Status: todo (asked for 2026-10-15; the answer past the budget decided 2026-10-15)

A worker gathers as many bodies at once as its clients send, each up to its route's
limit, so its spill's high-water mark, which it keeps for its life, has no bound but
the number of connections times the largest limit (task 020's findings). A budget per
worker for bytes being gathered bounds it.

## Decided (2026-10-15)

Past the budget, the route gets 503 at once, with `Retry-After`; the worker doesn't
stop reading the connection. This follows Tina's bounded mailboxes, as goose-http's
does: a size fixed up front, and a full one sheds load rather than holding work in a
wait without a time limit. Held reads would leave clients with stalled uploads, keep
their connections and kernel buffers, and need goose-http to pause and resume reads in
every loop.

- A body with a `Content-Length` reserves its whole size at the head: one that doesn't
  fit is refused before it is sent, and before `100 Continue`. Task 028's run of the
  body's exact size, taken at the first piece, is the reservation.
- A chunked body reserves as it grows, and past the budget gets 503 and the connection
  closes, as a chunked body past its route's limit gets 413.
- A route on `rest::body_in_pieces` doesn't count against it: that's the way to take
  large bodies, and the 503 points a program to it.
- The budget is a setting with a default. The spill's peak then follows the
  configuration, not what clients send.

## Acceptance criteria

- [ ] A `Config`-style setting for the budget, with a default recorded with its reason
- [ ] Past the budget, a route that gathers gets 503 with `Retry-After`, as decided
      above, and the spill's peak stays within the budget under task 020's upload
      workload with tier D gathering (its server before task 020's fix 2), measured
- [ ] Unit tests cover a body with a length refused at its head, a chunked body past
      the budget, a body that fits after another finishes, and a route on
      `rest::body_in_pieces` beside a full budget
- [ ] The reference and tutorial page 10, "Three limits", say what the budget bounds
      and what a client sees past it
