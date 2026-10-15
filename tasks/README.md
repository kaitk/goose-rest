# Tasks

Markdown-based task tracking. One file per task, or one folder for a task with
several subtasks or its own supporting files.

## Naming

`NNN-short-slug.md` — zero-padded, sequential number plus a kebab-case slug,
e.g. `001-context.md`.

A task with subtasks or supporting files is a folder with the same name,
`NNN-short-slug/`, holding the task itself as `README.md` and one file per
subtask as `NN-short-slug.md`, numbered within the folder. Subtasks use the same format
as tasks.

## Format

```markdown
# NNN: Title

Status: todo | in-progress | done | cancelled

Short description of what and why.

## Acceptance criteria

- [ ] Concrete, verifiable outcome
- [ ] ...
```

Update the status line as work progresses; tick criteria as they are met. A cancelled task
says who cancelled it, when, and why. A task that measures something records the numbers
in its own file, with how they were measured.

## Archive

When a task is done and nothing still builds on its file, move it to `000-archive/` with
`git mv`, keeping its name. The main folder then lists only open work. Numbers stay
unique across both folders: pick the next number after the highest in either. Refer to
tasks by number ("task 001"), not by path, so a move breaks no reference.


## Order

Task 001 makes the package. Tasks 002 and 003 can start at once: the spikes, and the
generator, which doesn't depend on goose-http's API. Task 004 waits on goose-http's task
027 breaking changes, and tasks 005 and 006 follow it. Task 007 measures the if chain
and decides task 008. Task 009 follows spike 06 and task 004. Task 010 benchmarks goose-rest against goose-http alone and three frameworks, and comes last. Task
011 can be settled at any point, and task 013 waits on an x86-64 host and a board.
Task 014 follows tasks 008 and 009. Task 015 can start at any point; what it needs from
goose-http waits on that package's task 027. Tasks 016, the tutorial, and 017 are done.
Task 018 follows goose-http's task 034, and waits only on a WSL run. Task 023, bodies and
responses in pieces, is built with the tutorial's pages 11 and 12, and waits only on
instruction counts measured on Linux. Task 020, the extra memory, and task 021, the reads
beside uploads, block v0.1.0 (2026-10-15): both are fixed, and wait only on a rerun on
Linux. Tasks 027, a helper for read-only
data every worker shares, 028, a body of known length gathered at its exact size, and
029, a per-worker budget for bodies being gathered, come from it. Task 025, the middleware's fields on answers
written after the request, and task 026, the architecture doc's split, follow. Task
024, the tutorial's testing of part two's application, task 031, `serve_one` past
`rest::ask`, and task 033, ASCII strings sized in bytes, are done. Tasks 030, responses
in pieces under `rest::compressed`, and 032, timers for a route that began a response,
can start at any point. Task 034, middleware stacks of the program's own, comes before
task 035, the tutorial's part on one way to lay out an application, which names them.
