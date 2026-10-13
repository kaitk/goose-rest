# 001: The package and its tests

Status: todo

Make the repository a Goose package that programs import, laid out as goose-http and
goose-compress are, with one command that runs every test.

## Acceptance criteria

- [ ] `rest.goose` at the root, `namespace rest`, importing goose-http at the commit in
      the README's Pins table, by its full hash
- [ ] `scripts/test.sh` checks each root file, runs `scripts/test-unit.sh`, and reruns
      the spikes; `scripts/test-unit.sh` runs each `test/test_*.goose` through TinyCC
- [ ] `docs/development.md` describes both scripts and how to move the goose-http pin
- [ ] A program outside the repository imports the package by commit and builds
