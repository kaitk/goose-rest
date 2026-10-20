# 11: `goose-rest new` and `goose-rest doctor`

Status: todo (asked for 2026-10-20)

Aegon's CLI (`aegon new`, `build`, `run`, `doctor`, `version`;
[its guide](https://udaykhare09.github.io/Aegon/guide/cli)) takes a new user from
nothing to a running server, and tells them what their machine supports. goose-rest
already has a CLI, `goose-rest gen` (`docs/generator.md`). Two commands would sit beside
it. `build` and `run` would only wrap `goose build` and `goose run`, so they're left
out.

- **`goose-rest new <name>`** writes a project that builds and runs as it is: a root
  file importing goose-rest and goose-http at the pins of goose-rest's latest release, a
  hello world, a test run through `rest::serve_one` with its golden file, a
  `.gitignore`, and a README with the commands. Options add an OpenAPI document with
  its generated file (`--openapi`), and TLS (`--tls`). The files come from one template
  directory in this repository, checked by `scripts/test.sh` as the tutorial's programs
  are, so the template can't fall behind the API.
- **`goose-rest doctor`** reports what affects whether a server builds and how fast it
  runs:
  - the Goose release found, against the one goose-rest's release needs
  - on Linux, the kernel, whether io_uring starts or the loop falls back to the
    emulation, `RLIMIT_MEMLOCK`, and whether kTLS is available
    (`/proc/sys/net/ipv4/tcp_available_ulp`)
  - the instruction sets that `simd` functions use
  - OpenSSL, when the program uses TLS
  - the traps in `docs/known-issues.md` that a program can detect, such as a Docker
    Desktop kernel without the `tls` module

  The checks are Goose with no C. The engine checks call goose-http (for example
  `http::ring_probe()`), and any gap there goes in goose-http.

The configuration file `new` writes comes from subtask 12, once it's built.

## Acceptance criteria

- [ ] `goose-rest new hello && cd hello` and the README's two commands serve the hello
      world and pass its test, on Linux, macOS, and Windows
- [ ] The template checked by `scripts/test.sh`
- [ ] `goose-rest doctor`'s checks above, each line saying what it found and what it
      means for the server, on Linux, macOS, and Windows
- [ ] Both documented in `docs/generator.md` (or a CLI page of its own), and the README's
      quick start starting from `goose-rest new`
