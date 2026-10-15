# 026: Split the architecture doc into a user's page and a decision log

Status: done (2026-10-15)

`docs/architecture/README.md` is 656 lines of dated decisions, spike results, the Elysia
study, and later uses: a log for contributors and agents more than a page a user reads,
against AGENTS.md's rule that user-facing docs carry no history. It waits on task 023,
which rewrites its "Waiting on another thread".

## Acceptance criteria

- [x] `docs/architecture.md`, for users: how goose-rest works and why, as it is now, in
      about 150 to 250 lines (how Goose shapes it, a request's path, middleware and
      inlining, waiting on a service, the generator in outline, and what each choice
      costs), linking the reference and tutorial rather than repeating them; no dates,
      tasks, or spikes
- [x] `docs/decisions.md`, stated in its first line as the record for contributors and
      agents: each decision, dated, with its reason and what was rejected, the spike
      results, the Elysia study, and later uses
- [x] AGENTS.md's "Architecture decisions" points at `docs/decisions.md`, and every link
      to the old file (README, tutorial, reference, generator, goose-http's docs) points
      at the page that now holds its section
