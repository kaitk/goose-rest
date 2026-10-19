# 044: Workers and lanes that survive an abort

Status: cancelled by the maintainer on 2026-10-19, after an independent review. An
abort ends the process, which a service manager restarts, for workers and lanes alike
([goose-http's decision](https://github.com/kaitk/goose-http/blob/main/docs/decisions.md#a-crash-ends-the-process-and-a-service-manager-restarts-it)).
goose-http's worker restart is parked on its branch `restart-workers`. The text below
describes the plan as it stood.

With `thread_spawn_contained`, an abort ends only its thread, and `thread_wait` returns
false for it. goose-http's `http::run` restarts an aborted worker (its task 050,
`588eadd`), so every program here, which starts its workers with it (task 043), gets
that without a change.

**Lanes** are the rest. A lane's thread has to be started again by a thread that can
name the program's `thread_fn`, and only `lane_open`'s caller can: `main`, which then
blocks in `http::run`. A watcher thread can't, since a `thread_fn` can't be generic.
Two ways round it were rejected (2026-10-19):

- The lane's own `thread_fn` as its watcher, which `rest::lane` would run in a watcher
  mode: the code before and after `rest::lane` in that `thread_fn`, such as opening a
  database connection, would run in the watcher too.
- A block for `http::run`'s supervisor, one line per lane in every program: API that the
  Goose change below would retire.

So lanes wait for Goose to let a `thread_fn` take a function value, bound at
`thread_spawn` as a call binds one (goose-http's task 052). Then `lane_open` spawns a
`thread_fn watch<W>` for each lane thread, which starts it with
`thread_spawn_contained` on the same box, waits 100 ms and twice as long after each
abort in a row, ends the process after 5, and stops restarting once `lane_stop` has
stopped the box. Programs don't change. Jobs queued meanwhile wait in the box; the job
in progress gets no reply, and its route answers when its wait's time limit passes.
What the lane opened through C, such as a database connection, isn't closed, and the
restarted thread opens its own.

Until then, an abort in a lane ends the process, and the service manager restarts it.

## Acceptance criteria

- [x] goose-http's `http::run` restarts aborted workers in the pin (`588eadd`)
- [ ] Goose's change merged and in the pin (goose-http's task 052)
- [ ] `lane_open` restarts each lane thread through a `watch<W>`, on the same box, with
      the delay, the limit, and no restart after `lane_stop`; programs unchanged
- [ ] A test: a handler and a lane that abort, and the program still answering after both
- [ ] The tutorial and best practices describe what an abort does, and that a restarted
      lane opens again what it opened through C, the old one left open
- [ ] `docs/decisions.md` and `docs/architecture.md` link to goose-http's decision that
      replaces "a crash ends the process", and record the lane restart
- [ ] `scripts/test.sh` passes
