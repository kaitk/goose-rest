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
| 042: ntex on the desktop | Built and checked on macOS; build, check, and measure on the Linux desktop. |
| 040: rate gaps in the v0.1.0 session | The router's stack frame fixed; open for discussion: goose-rest's per-request overhead on tiers A and M, and a hand-written chain's frame. |
| 036: parameters in a scope's prefix | Research; the best practices' member audience waits on it. |
| 037: data compiled into the binary | Spike. |
| 034: middleware stacks | Built; whether the generator takes a program's stack per security scheme. |
| 035: best practices | Built; the testing page, then data access and a full example once there are database helpers and JWT. |
| 027: a helper over the shared store | Deferred until a program needs it. |
| 022: OpenAPI output | Planned for later. |
| 012: a benchmark app shared with goose-http | Done in Docker on a Mac; the Linux desktop's idle VmRSS recheck remains, before task 010's run. |
| 043: workers started with `http::run` | Done on a pinned Goose commit; the README waits for releases. |
| 046: rename to Plod | Deferred; the name check and the logo come first. |
| 047: HttpArena | After 046; the master plan, with the work in goose-http, goose-tls, goose-sqlite, and goose-postgres. |
| 051: restart after an abort | Un-parks goose-http's `restart-workers` branch; any time, beside 047. |
| 052: database work on lanes | goose-postgres's and goose-sqlite's decisions and tasks; beside 047. |
| 053: a contained scope in Goose | A design note only; not proposed until 051 has run in an application. |
| 048: Aegon in the REST benchmark | Built and checked on the desktop, without tier D; the nightly run measures it. |
| 049: ACME | A package of its own; waits on goose-tls's tasks 001 and 003. |
| 054: tier C templated's cost at v0.2.0 | Bisected to code layout and goose-http `v0.4.0`'s loops; a deterministic layout and the loops' cost remain. |
| 013: embedded aarch64 | Waits on an x86-64 host and a board. |
| 018: Goose releases | Waits only on a WSL run. |
