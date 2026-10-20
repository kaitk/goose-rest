# Writing docs, tasks, and prose

Writing docs follows `.claude/skills/google-style/SKILL.md`, and the rules below.

- `README.md` is for people who use the package: what it provides, a status table, a
  quick start, concepts, benchmark highlights, and links. Layout, pins, process, tasks,
  and rules for agents go in `docs/`, or in `AGENTS.md` and `agents/` (2026-10-15).
- User-facing docs (`README.md`, `docs/`, `bench/README.md`) reference no tasks, and
  keep nothing only an agent needs, nor history: say what is, not what used to be.
  Open work, causes not yet measured, and plans go in a task (2026-10-15).
- Keep each fact in one place and link to it elsewhere. `CHANGELOG.md` names the Goose
  compiler each tag was built with.
- Say what doesn't work yet, plainly, without blame on Goose or its maintainer.
