# Agent rules

## Project context

- What this is: `README.md`; what each tag adds: `CHANGELOG.md`; the framework step
  by step: `docs/tutorial.md`; every middleware, extractor, and error:
  `docs/reference.md`; what the generator reads, writes, and refuses:
  `docs/generator.md`
- Architecture decisions: `docs/architecture/README.md`
- Current benchmark results, the tiers, and their pins: `docs/benchmarks.md`; the
  benchmark servers, scripts, and where results go: `bench/README.md`
- Layout, the Goose release, toolchain, and local setup: `docs/development.md`
- Environment traps and incidents, by platform: `docs/known-issues.md`
- Goose compiler and stdlib gaps found here: `docs/goose-findings.md`
- Task tracking: `tasks/` (see `tasks/README.md`)
- Language checks the design relies on: `spikes/`, one folder each, with a README
- Writing docs: `.claude/skills/google-style/SKILL.md`, and "Writing" below
- The HTTP layer: goose-http's `README.md`, `docs/api.md`, `docs/patterns.md` (request
  bodies, long responses, mail between threads, slow work), and `examples/README.md`.
  Link to those rather than explain goose-http's mechanisms again. goose-http's task
  027 is still changing its API.
- The model: Actix's `App`, scopes, extractors, and middleware, changed where Goose
  differs (architecture doc).
- The generator's input: OpenAPI 3.1 and JSON Schema 2020-12, in the subset
  the architecture doc names.
- The language: the pinned Goose release's `docs/tutorial.md`, `docs/goose_spec.md`,
  and `docs/stdlib.md`. Read the tutorial before writing Goose; check the spec before
  assuming a feature exists.

Follow the recorded decisions; if a change contradicts one, update the doc in the same
change or ask first. Record setup facts you find (paths, versions, install steps) in
`docs/development.md`, and environment traps (shell quirks, ports, encodings, dated
incidents) in `docs/known-issues.md`, not in agent memory, so the next agent finds
them. Docs and commits name no people: date a decision or a request
(`(2026-10-13)`), and describe the setup without anyone's machine, checkouts, or home
directory. What only one machine needs, such as where its Goose checkout is, goes in
`CLAUDE.local.md`, which git ignores. Benchmark results still name their machine. The
docs and scripts must work for a developer on a clean machine without LLM tools:
`CLAUDE.local.md` holds conveniences, never a step the setup needs, and a script fetches
what it needs or says how to get it, rather than assume a sibling checkout (2026-10-15).

## Writing

- `README.md` is for people who use the package: what it provides, a status table, a
  quick start, concepts, benchmark highlights, and links. Layout, pins, process, tasks,
  and rules for agents go in `docs/` or here (2026-10-15).
- User-facing docs (`README.md`, `docs/`, `bench/README.md`) reference no tasks, and
  keep nothing only an agent needs, nor history: say what is, not what used to be.
  Open work, causes not yet measured, and plans go in a task (2026-10-15).
- Keep each fact in one place and link to it elsewhere. `CHANGELOG.md` names the Goose
  compiler each tag was built with.
- Say what doesn't work yet, plainly, without blame on Goose or its maintainer.

## Goose, not an addition to Goose

- Build with the official Goose release that `scripts/goose.sh` pins, and move the pin
  to each new release ("Move the Goose pin" below).
- Don't edit a Goose checkout. When the compiler rejects something it should accept,
  miscompiles, or the stdlib lacks something, reduce it to a minimal program, record it
  in `docs/goose-findings.md`, and work around it here. Report blockers to the maintainer.
- Every finding names the Goose commit it was found on, the pin at the time (for a
  release, its commit). When one lacks it, recover it from this repository's history:
  the pin in the commit that added the entry.
- `docs/goose-findings.md` lists bugs first and feature requests after, each part from
  the least work a fix is expected to take to the most. Place a new entry by that
  order, and delete an entry once the pin has its fix (2026-10-14).
- Write Goose the way the pinned release's `samples/` and `stdlib/` do: flat data,
  references into growing arrays, `return ... from` for errors, untyped parameters for
  generics.
- The package and the generator are Goose with no C. Sockets and syscalls are
  goose-http's; a gap there is fixed in goose-http, not worked around here.

## Move the Goose pin

The pin is an official Goose release, which builds the same on every platform. At the
start of a session, check for a newer one:

```sh
gh release list -R aardappel/goose --limit 3
```

To move to a new release, update `goose_release` and the four archives' SHA-256 sums in
`scripts/goose.sh`, as goose-http does in the same file. GitHub lists each asset's
digest:

```sh
gh api repos/aardappel/goose/releases/tags/<tag> -q '.assets[] | "\(.name) \(.digest)"'
```

Then run `scripts/test.sh`, which reruns every spike against its recorded output, update
the commit and verdict in each spike's README, and update the release in
`docs/development.md` ("Get Goose") and `README.md`'s quick start, in its own commit.

Pin a commit only when a Goose fix that this repository needs isn't in a release yet,
and return to a release once one has it (2026-10-15). Set `GOOSE_COMMIT` in the
scripts' environment (`docs/development.md`, "Use another compiler"), and record the
commit and the reason in `docs/development.md`, "Get Goose".

## Move the goose-http pin

The import in `rest.goose` is the pin: a release tag, or a full commit hash for a fix
not yet released, since git can't fetch an abbreviated one. The same reference is in
each of the package's files, in each root file under `test/`, `examples/`,
`docs/tutorial/`, `spikes/`, and `bench/`, in `README.md`'s quick start, and in
`docs/tutorial.md`. `scripts/move-http-pin.sh` changes every one:

```sh
scripts/move-http-pin.sh v0.3.1
```

Move it in its own commit once `scripts/test.sh` passes, and update the goose-http
reference each spike's README names. A root that declares goose-http at another commit
than `rest.goose` gets a warning, and from another source an error, so a test can't
point at a local goose-http checkout instead.

## Generated code

- Generated `_gen.goose` files are never edited by hand. Change the generator or the
  schema, and regenerate.
- A schema construct outside the supported subset is a generator error that names the
  construct and its JSON pointer, never silently dropped.

## Benchmarks

- Every number comes with how it was measured: machine, kernel, command, worker and
  connection counts, and run count. A result without them doesn't go in a doc.
- goose-rest is measured on goose-http's REST tiers and its own (`docs/benchmarks.md`), against goose-http alone and
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
