# 029: A per-worker budget for bodies being gathered

Status: todo (asked for 2026-10-15)

A worker gathers as many bodies at once as its clients send, each up to its route's
limit, so its spill's high-water mark, which it keeps for its life, has no bound but
the number of connections times the largest limit (task 020's findings). A budget per
worker for bytes being gathered bounds it: past the budget, a route that asks for a
body either gets 503 at once, or the worker stops reading the connection until other
bodies finish. Stopping a connection's reads may need a goose-http call it doesn't
have; that part is then goose-http's to add first.

## Acceptance criteria

- [ ] A `Config`-style setting for the budget, off by default or with a default
      recorded with its reason
- [ ] Past the budget, a route that gathers gets a recorded answer (503 or held reads),
      decided with the user, and the spill's peak stays within the budget under task
      020's upload workload, measured
- [ ] The reference and tutorial page 10, "Three limits", say what the budget bounds
      and what a client sees past it
