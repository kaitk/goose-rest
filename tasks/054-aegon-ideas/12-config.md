# 12: Layered, typed configuration

Status: todo (asked for 2026-10-20)

Aegon's configuration ([its guide](https://udaykhare09.github.io/Aegon/guide/config),
read 2026-10-20) binds layers into one typed struct. Later layers override earlier ones:

1. The struct's default values
2. A base YAML file (`config.yaml`)
3. An optional file per environment (`config.production.yaml`)
4. A `.env` file, optional, so a container can use real environment variables
5. Placeholders in the files: `${VAR}` is required, `${VAR:default}` falls back, and
   `\${X}` is literal
6. Prefixed variables mapped to nested keys: `AEGON__SERVER__PORT` sets `server.port`
7. Command-line flags: `--server.port=9090`

A missing required variable or malformed YAML is an error with the file, line, and
column. Aegon has no validation of the values beyond their types.

goose-rest can do better on validation. It already generates a struct and a checked
reader from a JSON Schema (`docs/generator.md`). A configuration schema would give the
struct, its defaults, and checked bounds (a port from 1 to 65535, a pool size above 0)
from one source, with each error naming its key. The generator refuses `default` now,
so it needs to accept it for configuration.

To settle, each recorded in `docs/decisions.md`:

- The file format. YAML is what most deployments write. A YAML 1.2 parser is large, and
  a subset (block mappings and sequences, plain and quoted scalars, comments; no anchors,
  tags, or flow style) may be enough. TOML is smaller to parse, and JSON already has a
  reader. Choose by the size of the parser and what users expect.
- Where it lives. Configuration isn't HTTP, and a goose-http program wants it too, so
  it's likely a package of its own, as goose-hash is.
- Whether the server's own settings (workers, port, TLS files, limits) bind from the
  same file by default.

## Acceptance criteria

- [ ] The decisions above recorded
- [ ] The seven layers, in Aegon's order, bound into a generated struct, with defaults
      and bounds checked
- [ ] Errors that name the file, line, and key, or the variable or flag that set the
      value
- [ ] A best-practices page and program, and `goose-rest new` (subtask 11) writing a
      configuration file
- [ ] Golden tests for each layer's precedence, a missing required variable, a value
      out of bounds, and an escaped placeholder
