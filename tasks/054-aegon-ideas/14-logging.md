# 14: A logger

Status: todo (asked for 2026-10-20)

goose-rest has no logger: `rest::timed` writes to standard error, and programs print.
Aegon's [logging guide](https://udaykhare09.github.io/Aegon/guide/logging) (read
2026-10-20) describes one that fits goose-rest's limits:

- Levels from trace to fatal, and off, settable while running. A call below the level
  does one check and formats nothing.
- The caller's file and line on each line. Goose has no `source_location`, so check
  what the compiler offers before choosing.
- An asynchronous writer: workers hand records to a writer thread over a bounded queue,
  flushed in batches at an interval, so a worker never waits on a disk or a terminal.
  Error and fatal flush at once. In goose-rest the writer is a lane, and a full box
  drops records and counts them rather than block the worker.
- Sinks: the console, with color when it's a terminal; a file; and memory, for tests
  that check what was logged.
- The engine's own events at debug and trace: listeners, the loop, io_uring setup, and
  fallbacks. goose-http writes these, so the levels and the sink belong to whichever
  package both share.

Subtask 07's access log and request logger write through it.

To settle: whether it's a package of its own, which goose-http and goose-postgres can
use too, and how a format string is checked against its arguments at compile time in
Goose.

## Acceptance criteria

- [ ] Where it lives decided, and recorded in `docs/decisions.md`
- [ ] Levels, the writer lane with a bounded box and a drop count, and the three sinks
- [ ] A filtered call measured at a single check, on tier A's instructions per request
- [ ] Tests through the memory sink, and `docs/reference.md` updated
