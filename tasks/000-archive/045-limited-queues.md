# 045: Limited queues for a pool of lanes

Status: cancelled by the maintainer on 2026-10-19, after an independent review: a pool
of threads is a lane, `http::Lane`, the one mechanism, so a queue pool isn't offered
(goose-http's task 051, cancelled too). The text below is the proposal as it stood.

With #39, a typed queue takes a limit (`qlimit<T>(n)`), `qput` returns false at once when
it's full, and `qget<T>(ms)` waits with a time limit. goose-rest sends work to a lane by
mail today (`rest::ask` in `waiting.goose`): each lane has a box and an address. A queue
chosen by type fits where several identical lanes share one kind of job, such as a pool
of hashers: any of them takes the next one, and a full queue answers 503. Replies to the
waiting request stay on mail, since they go to one particular worker.

Decide whether goose-rest offers that, as `rest::ask` to a queue rather than an address,
or leaves it to the program and documents it.

## Acceptance criteria

- [ ] The pin has #39, and goose-http's task 051 is done
- [ ] A decision in `docs/decisions.md`: a pool of lanes on a limited queue through
      `rest::ask`, or in the program, with the reason
- [ ] If it's goose-rest's: the API, a test of a full queue answering 503, and the best
      practices' lanes page showing a pool
- [ ] `scripts/test.sh` passes
