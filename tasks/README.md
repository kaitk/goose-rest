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

Work can start at any point unless the table says otherwise.

| Open work | Remaining outcome or dependency |
|---|---|
| 020: memory | Done on Linux (2026-10-20); stays here while task 027 uses its method. |
| 023: bodies and responses in pieces | Done (2026-10-20); three follow-ups under its "Left open": compression in pieces, `TIMEOUT` after a begun response, and precompressed files. |
| 025: middleware fields on later answers, and 029: the gathering budget | Done; tier M's instructions per request on Linux record what each added. |
| 040: rate gaps in the v0.1.0 session | The router's stack frame fixed; open for discussion: goose-rest's per-request overhead on tiers A and M, and a hand-written chain's frame. |
| 036: parameters in a scope's prefix | Research; the best practices' member audience waits on it. |
| 037: data compiled into the binary | Spike. |
| 034: middleware stacks | Built; whether the generator takes a program's stack per security scheme. |
| 035: best practices | Built; the testing page, then data access and a full example once there are database helpers and JWT. |
| 027: a helper over the shared store | Deferred until a program needs it. |
| 022: OpenAPI output | Planned for later. |
| 043: workers started with `http::run` | Done on a pinned Goose commit; the README waits for releases. |
| 046: rename to Plod | Deferred; the name check and the logo come first. |
| 047: HttpArena | After 046; the master plan, with the work in goose-http, goose-tls, goose-sqlite, and goose-postgres. |
| 052: database work on lanes | goose-postgres's and goose-sqlite's decisions and tasks; beside 047. |
| 053: a contained scope in Goose | A design note only; it builds on task 051, cancelled on 2026-10-21, so it waits until restarts are pursued. |
| 048: Aegon in the REST benchmark | Built and checked on the desktop, without tier D; the nightly run measures it. |
| 056: what to take from Aegon | Verdicts set; seventeen subtasks. 01, shorter routes, is merged as skip-based routing with block scopes; tier M's count on Linux and a full `bench/routes.sh` run are todo. 02 to 08 are small and can run beside goose-http's TLS and h2 work; 16 and 17 wait on 052. 05 (JWT) unblocks 035's full example and parts of 047. |
| 055: a documentation site | Any time; its address waits on 046. |
| 049: ACME | goose-acme `v0.0.3` works against Pebble and reaches Let's Encrypt's staging service; a goose-rest server waits on goose-http's `http.tls` choosing a context per connection. |
| 013: embedded aarch64 | Waits on an x86-64 host and a board. |
| 018: Goose releases | Waits only on a WSL run. |
