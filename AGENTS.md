# Agent rules

## Project context

- What this is and its pins: `README.md`
- Architecture decisions: `docs/architecture/README.md`
- Toolchain and local setup: `docs/development.md`
- Goose compiler and stdlib gaps found here: `docs/goose-findings.md`
- Task tracking: `tasks/` (see `tasks/README.md`)
- Language checks the design relies on: `spikes/`, one folder each, with a README
- Writing docs: `.claude/skills/google-style/SKILL.md`
- The HTTP layer: goose-http's `README.md`, `examples/README.md`, and its task 027,
  which is still changing its API.
- The model: Actix's `App`, scopes, extractors, and middleware, changed where Goose
  differs (architecture doc).
- The generator's input: OpenAPI 3.1 and JSON Schema 2020-12, in the subset
  the architecture doc names.
- The language: the pinned Goose checkout's `docs/tutorial.md`, `docs/goose_spec.md`,
  and `docs/stdlib.md`. Read the tutorial before writing Goose; check the spec before
  assuming a feature exists.

Follow the recorded decisions; if a change contradicts one, update the doc in the same
change or ask first. Record setup facts and environment traps you find (paths, shell
quirks, ports, encodings) in `docs/development.md`, not in agent memory, so the next
agent finds them. Docs and commits name no people: date a decision or a request
(`(2026-10-13)`), and describe the setup without anyone's machine, checkouts, or home
directory. What only one machine needs, such as where its Goose checkout is, goes in
`CLAUDE.local.md`, which git ignores. Benchmark results still name their machine.

## Goose, not an addition to Goose

- The Goose repository changes daily. Fetch the Goose checkout `GOOSE` is built from
  (`../goose` unless `CLAUDE.local.md` says otherwise) at the start of a session and
  move the pin when it lags (`docs/development.md`, "Move the pin"). Rerun the spikes
  when it moves, and update each one's README with the result.
- Don't edit the Goose checkout. When the compiler rejects something it should accept,
  miscompiles, or the stdlib lacks something, reduce it to a minimal program, record it
  in `docs/goose-findings.md`, and work around it here. Report blockers to the maintainer.
- Every finding names the Goose commit it was found on, the pin at the time. When one
  lacks it, recover it from this repository's history: the pin in the commit that added
  the entry.
- `docs/goose-findings.md` lists bugs first and feature requests after, each part from
  the least work a fix is expected to take to the most. Place a new entry by that
  order, and delete an entry once the pin has its fix (2026-10-14).
- Write Goose the way the pinned checkout's `samples/` and `stdlib/` do: flat data,
  references into growing arrays, `return ... from` for errors, untyped parameters for
  generics.
- The package and the generator are Goose with no C. Sockets and syscalls are
  goose-http's; a gap there is fixed in goose-http, not worked around here.

## Generated code

- Generated `_gen.goose` files are never edited by hand. Change the generator or the
  schema, and regenerate.
- A schema construct outside the supported subset is a generator error that names the
  construct and its JSON pointer, never silently dropped.

## Benchmarks

- Every number comes with how it was measured: machine, kernel, command, worker and
  connection counts, and run count. A result without them doesn't go in a doc.
- goose-rest is measured on goose-http's task 021 tiers, against goose-http alone and
  against Axum, actix-web, and dusty (Zig) in their fastest documented configuration,
  built in release mode, with the same worker count. Each framework serves through its
  own router, extractors, and middleware, not one catch-all handler. Losses are recorded as plainly as wins.

## Code conventions

- Comment only where the code is hard to follow without it, and say only what a reader
  of that code needs: why, a constraint, or a contract the code can't show. Don't restate
  the next line, and don't describe earlier versions or the task that added the code;
  history belongs in git.
- Edit files with the Edit tool, not with `sed` or a Python or PowerShell script. On
  Windows, line endings differ by file type and a shell adds a layer of escaping, and
  scripted edits break on both.

## Commits

- One lean sentence in imperative mood, at most 72 characters.
- No body, no `Co-Authored-By` or any other trailers.
- Fetch and rebase before pushing a finished commit to `origin`.
