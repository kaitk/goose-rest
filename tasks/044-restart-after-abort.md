# 044: Workers and lanes that survive an abort

Status: todo. Waits on goose-http's task 049, which waits on
[aardappel/goose#38](https://github.com/aardappel/goose/pull/38) in the Goose pin.

With `thread_spawn_contained`, an abort ends only its thread, and `thread_wait` returns
false for it. goose-http's `http::run` restarts an aborted worker on its listener (its
task 049), so programs that start their workers with it (task 043) get that without a
change. Two parts are goose-rest's:

- **Lanes.** A lane is a thread a program spawns itself, with a box `main` opens
  (`docs/best-practices/lanes/`, `docs/tutorial/12-two-lanes/`). It can be restarted
  the same way: `main` keeps the box, and a watcher spawns the lane again with
  `thread_spawn_contained` on the same box, so jobs queued meanwhile wait for it. What
  the runtime doesn't free is what a lane opened through C, such as a SQLite connection.
  The lane, or its watcher, must reopen that, and the docs say plainly that the old one
  isn't closed. `rest::lane` can hold the watcher, as long as the helper stays short.
- **The docs.** The tutorial and best practices say what an abort does: it ends only the
  thread, the worker or lane restarts, and the requests that thread was answering get
  no answer. A handler should still return errors rather than abort, where it can.

## Acceptance criteria

- [ ] goose-http's `http::run` restarts aborted workers in the pin
- [ ] The lanes in the best practices and tutorial restart after an abort, on the same box
- [ ] A test: a handler and a lane that abort, and the program still answering after both
- [ ] The tutorial and best practices describe what an abort does, and what a lane must
      reopen
- [ ] `docs/decisions.md` and `docs/architecture.md` link to goose-http's decision that
      replaces "a crash ends the process", or record goose-rest's own where it differs
- [ ] `scripts/test.sh` passes
