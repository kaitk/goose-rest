# 025: Middleware fields on answers written after the request

Status: todo (found 2026-10-15)

`rest::cors` and `rest::timed` add their fields to the answers written while the handler
runs for the request. An answer written later, when a route resumes at a service's
reply, at the end of a body read in pieces, or in a response begun later, gets neither:
the middleware's blocks ran at `REQUEST`, and the request's head is gone by then. A
browser then refuses a cross-origin answer that a waiting route or an upload writes
(task 023's page 11 shows one). Found in task 023's proposal, which leaves it here.

## Acceptance criteria

- [ ] What each middleware decided at `REQUEST` (CORS's allowed origin, the timing's
      start) is kept with the exchange, and an answer written later gets the same fields
- [ ] A program that uses neither middleware pays nothing for it
- [ ] Tests cover a route that resumes at `WAKE` and one that answers at a body's `END`
- [ ] The reference says which answers get which fields
