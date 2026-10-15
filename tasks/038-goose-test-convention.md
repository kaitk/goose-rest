# 038: Move goose-rest's tests to Goose's test convention

Status: todo (asked for 2026-10-15)

Tests follow Goose's own convention in every one of these packages
([decisions](../docs/decisions.md#tests), 2026-10-15): a top-level `test/` by area,
each test a small program checked by its printed output against
`test/expected/<name>.out`, `// error:` fixtures for code that must not compile, and a
runner that batches the builds with `goose --multi-test` and runs the tests in
parallel. goose-rest's tests today are a dozen `test/test_*.goose` programs that
`scripts/test.sh` lists by hand, nine with their own copy of a `same` helper, where the
first failed `assert` ends the program.

As in Goose's own repository, the runner is this repository's own: `test/run_tests.py`,
in Python, modeled on Goose's, with no package or script shared between repositories
(2026-10-15). goose-http and goose-compress get their own the same way (their tasks
041 and 007).

## Acceptance criteria

- [ ] `test/run_tests.py`, modeled on Goose's: finds `test/**/*.goose`, compiles them in batches with
      `goose --multi-test`, runs each as a process of its own and in parallel, at `-O0`
      and `-O2` where they differ, compares output with `test/expected/`, checks
      `// error:` fixtures fail with their message, and reports every failure with a
      count per area; one way to run a single test or area
- [ ] goose-rest's tests split into small programs by area (`test/runtime/`,
      `test/extract/`, `test/middleware/`, `test/generator/`, ...), each printing what
      it checks, with its golden file; the shared helpers in one module
- [ ] `// error:` fixtures for what must not compile, at least: a generated type built
      from a schema outside the subset, and a route given the wrong state type
- [ ] `scripts/test.sh` calls the runner in place of its list of test programs, and
      keeps its other steps (the generator's golden files, the tutorial's programs, the
      spikes, the inlining check)
- [ ] `docs/development.md` says how to run the tests, one test, and one area, and how
      to bless a changed golden file
