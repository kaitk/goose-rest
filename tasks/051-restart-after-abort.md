# 051: Workers and lanes that restart after an abort

Status: todo. Reopens task 044, which the maintainer cancelled on 2026-10-19, with
goose-http's parked `restart-workers` branch (`c0954f5`) as its base (2026-10-19).

A bug in a lane or a handler should end only its thread, and the program should serve
on, as actix-web restarts a worker. Since Goose `ce1adbe` (#38), in the pin,
`thread_spawn_contained` gives that boundary. goose-http's branch already restarts
workers in `http::run`, shares the policy as `http::restart_after`, and settles an
aborted lane's box with `http::mail_adopt`. Lanes need no Goose change: since
`fb56981` (#37), a generic `fn` called from a program's `thread_fn` spawns the
`thread_fn` it's handed.

What a program writes:

```rust
thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
    var db = pg::open(DB_URL, box);   // closes what an aborted thread on this box left open
    rest::lane(box, jobs) { u, a => run(u, db, a); };
}
// Restarts writer on the same box after an abort, with http::run's policy.
thread_fn kept_writer(box: http::Box, jobs: rest::Jobs<Writes>) { rest::keep(box, jobs, writer); }

writer: rest::lane_open<Writes>(http::LaneConfig { slots: WRITER_SLOTS, .. }, Use.Write, kept_writer),
```

Workers, routes, jobs, and `resume`s don't change. A lane without the wrapper still
ends the process on an abort.

Two pieces are new, in goose-http:

- **The job in flight.** The box keeps the reply address of the job its owner took,
  and `rest::keep` replies to it after an abort, so the route answers 500
  `lane_aborted` at once rather than 504 at its time limit.
- **Handles a thread holds.** The box keeps the handles its owner registers, as it
  keeps `mail_adopt`'s count, so the next owner closes them. A Postgres socket left
  open keeps its transaction's row locks until the process ends, and a SQLite handle
  keeps the write lock from the restarted lane.

Draft decision, to replace "An abort ends the process" (2026-10-19) when this lands:

> Decided (date): an abort ends only its thread. `http::run` restarts a worker, and a
> lane restarts when the program opens it through a `thread_fn` that calls
> `rest::keep`: after 100 ms, twice as long for each abort in a row, and the process
> ends after `Config.restarts`, 5 by default, for the service manager to restart. The
> route whose job was in flight gets 500 `lane_aborted`; the jobs queued behind it wait
> for the restarted thread. The next owner of a box closes the handles its predecessor
> registered, so a database rolls back the aborted transaction. A restarted lane starts
> with empty lane data. This replaces the process-wide end for a thread's bug, and
> keeps it for an abort on main, a stack overflow, and repeated aborts. Rejected: a
> Goose change letting a `thread_fn` take a function value (goose-http's task 052),
> since the wrapper is three lines and needs none; a supervisor block on `http::run`;
> and child processes per lane.

## Acceptance criteria

- [ ] goose-http's `restart-workers` branch on its `main` and in the pin, with the job
      in flight and held handles
- [ ] `rest::keep(box, W)` and `rest::keep(box, v, W)`, with no restart after
      `http::lane_stop`
- [ ] A test: a handler and a lane that abort, the program still answering after both,
      and the route whose job was in flight answered 500 `lane_aborted`
- [ ] The tutorial and best practices open their lanes through `rest::keep`, and say
      what an abort costs: the worker's connections, or the lane's job in flight and
      its lane data
- [ ] The decision above in `docs/decisions.md`, replacing the 2026-10-19 entry, and
      `docs/architecture.md` updated in the same change
- [ ] `scripts/test.sh` passes
