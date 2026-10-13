# 007: Measure the if chain at 60 routes

Status: todo

Decides whether task 008 is worth doing. A hand-written if chain with prefix scopes, at
60 routes shaped like a real API, against the same server with one route.

## Acceptance criteria

- [ ] Instructions per request with goose-http's `bench/count.sh`, for the first route,
      the last, a 404, and a 405
- [ ] The numbers recorded here with how they were measured, and a decision on task 008
