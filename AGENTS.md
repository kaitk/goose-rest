# Agent rules

This file holds what every session needs. `agents/` holds the rules for particular work:
read the file a task touches before starting it.

## Project context

- What this is: `README.md`; what each tag adds: `CHANGELOG.md`; the framework step
  by step: `docs/tutorial/README.md`, a page each, with its programs beside the
  pages; how to lay out an application: `docs/best-practices/README.md`, with its
  programs too; every middleware, extractor, and error:
  `docs/reference.md`; what the generator reads, writes, and refuses:
  `docs/generator.md`
- Architecture decisions: `docs/decisions.md`, each dated with its reason and what it
  rejected; how the package works as it is now, for users: `docs/architecture.md`
- Current benchmark results, the tiers, and their pins: `docs/benchmarks.md`; the
  benchmark servers, scripts, and where results go: `bench/README.md`
- Layout, the Goose release, toolchain, and local setup: `docs/development.md`
- Environment traps and incidents, by platform: `docs/known-issues.md`
- Goose compiler and stdlib gaps found here: `docs/goose-findings.md`
- Task tracking: `tasks/` (see `tasks/README.md`)
- Language checks the design relies on: `spikes/`, one folder each, with a README
- The HTTP layer: goose-http's `README.md`, `docs/api.md`, `docs/patterns.md` (request
  bodies, long responses, mail between threads, slow work), and `examples/README.md`.
  Link to those rather than explain goose-http's mechanisms again. goose-http's task
  027 is still changing its API.
- The model: Actix's `App`, scopes, extractors, and middleware, changed where Goose
  differs (`docs/architecture.md`).
- The generator's input: OpenAPI 3.1 and JSON Schema 2020-12, in the subset
  `docs/generator.md` lists.
- The language: the pinned Goose release's `docs/tutorial.md`, `docs/goose_spec.md`,
  and `docs/stdlib.md`. Read the tutorial before writing Goose; check the spec before
  assuming a feature exists.
- Rules for particular work: `agents/goose.md` (writing Goose, and recording what it
  lacks), `agents/writing.md` (docs, tasks, and prose), `agents/pins.md` (moving the
  Goose, goose-http, and goose-compress pins), and `agents/benchmarks.md` (measuring,
  the rivals, and reporting a number)

Follow the recorded decisions in `docs/decisions.md`; if a change contradicts one, record
the new decision there, saying which it replaces, and update `docs/architecture.md`, in
the same change, or ask first. Record setup facts you find (paths, versions, install steps) in
`docs/development.md`, and environment traps (shell quirks, ports, encodings, dated
incidents) in `docs/known-issues.md`, not in agent memory, so the next agent finds
them. Docs and commits name no people: date a decision or a request
(`(2026-10-13)`), and describe the setup without anyone's machine, checkouts, or home
directory. What only one machine needs, such as where its Goose checkout is, goes in
`CLAUDE.local.md`, which git ignores. Benchmark results still name their machine. The
docs and scripts must work for a developer on a clean machine without LLM tools:
`CLAUDE.local.md` holds conveniences, never a step the setup needs, and a script fetches
what it needs or says how to get it, rather than assume a sibling checkout (2026-10-15).

## Keep changes small

Agreed 2026-10-20, after several fixes solved problems that a second look showed
weren't there.

- Meet the requirement's intent with the least machinery. Before building around an
  obstacle, ask whether the requirement needs it at all. Browsers ignore HSTS sent over
  plain HTTP, so the security headers need no TLS check.
- When a fix starts to need a new public API, a change in another repository, or a
  workaround, stop. Say so in a sentence or two, and propose the simpler reading of the
  requirement.
- A feature's cost falls on the programs that use it: no fields in shared structs such
  as `Cx`, and no code on shared paths, for one feature. Let the program choose where it
  calls the feature: a route that needs another policy picks it where it calls the
  middleware.
- When a design makes other code compensate (a fallback, a rescan, a special case
  elsewhere), change the design rather than add the compensation.
- Add a setting, a check, or a script option only for a failure that isn't visible
  already.

## Working beside other agents

Several agents work in these repositories at once (2026-10-20).

- Work in a worktree of your own, on a branch from `origin/main`:
  `git worktree add ../plod-<topic> -b <topic> origin/main`. Remove it once the
  branch is merged.
- Leave alone a branch, a commit, or an uncommitted change that isn't yours, in any
  checkout. Ask if it's in your way.
- Keep logs, exports, and scratch files in a directory of your own.
- Problems with your own sandbox, such as no network or no SSH, go in your report,
  not in the docs.

## Goose

- Build with the official Goose release that `scripts/goose.sh` pins. Check for a newer
  one at the start of a session (`agents/pins.md`).
- Don't edit a Goose checkout. Work around a compiler or stdlib gap here, record it in
  `docs/goose-findings.md` as `agents/goose.md` says, and report blockers to the
  maintainer.
- The package and the generator are Goose with no C. Sockets and syscalls are
  goose-http's; a gap there is fixed in goose-http, not worked around here.

## Generated code

- Generated `_gen.goose` files are never edited by hand. Change the generator or the
  schema, and regenerate.
- A schema construct outside the supported subset is a generator error that names the
  construct and its JSON pointer, never silently dropped.

## Code conventions

- Comment only where the code is hard to follow without it, and say only what a reader
  of that code needs: why, a constraint, or a contract the code can't show. Don't restate
  the next line, and don't describe earlier versions or the task that added the code;
  history belongs in git.
- Edit files with the Edit tool, not with `sed` or a Python or PowerShell script. On
  Windows, line endings differ by file type and a shell adds a layer of escaping, and
  scripted edits break on both.
- Tests follow Goose's own convention: a top-level `test/` by area, each test a small
  program whose printed output a golden file in `test/expected/` checks, `// error:`
  fixtures for code that must not compile, and a runner that batches them with
  `goose --multi-test` ([decisions](docs/decisions.md#tests), 2026-10-15).

## Commits

- One lean sentence in imperative mood, at most 72 characters.
- No body, no `Co-Authored-By` or any other trailers.
- Fetch and rebase before pushing a finished commit to `origin`.
