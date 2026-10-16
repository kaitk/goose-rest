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

The benchmark session on Linux settles the first five; the rest can start at any point
unless the table says otherwise.

| Open work | Remaining outcome or dependency |
|---|---|
| 019: serialized JSON | The package's half is done; the Linux run says whether B and C closed on goose-http alone. |
| 020: memory | Fixed; idle and peak RSS rerun on Linux, recorded in `docs/benchmarks.md`. |
| 021: reads beside uploads | Fixed; the Linux rerun confirms it. |
| 023: bodies and responses in pieces | Built; instruction counts on tiers A and M on Linux. |
| 025: middleware fields on later answers, and 029: the gathering budget | Done; tier M's instructions per request on Linux record what each added. |
| 040: rate gaps in the v0.1.0 session | The router's stack frame fixed; open for discussion: goose-rest's per-request overhead on tiers A and M, and a hand-written chain's frame. |
| 032: timers after `begin` | Check whether goose-http arms a timer on an open response first. |
| 036: parameters in a scope's prefix | Research; the best practices' member audience waits on it. |
| 037: data compiled into the binary | Spike. |
| 034: middleware stacks | Built; whether the generator takes a program's stack per security scheme. |
| 035: best practices | Built; the testing page, then data access and a full example once there are database helpers and JWT. |
| 027: a helper over the shared store | Deferred until a program needs it. |
| 022: OpenAPI output | Planned for later. |
| 012: a benchmark app shared with goose-http | Waits on goose-http's task 031. |
| 013: embedded aarch64 | Waits on an x86-64 host and a board. |
| 018: Goose releases | Waits only on a WSL run. |
