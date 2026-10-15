# Development

This guide sets up a machine to build, test, and benchmark goose-rest. goose-rest is
Goose with no C of its own. It runs on goose-http, whose shim is the only C in a program,
so it builds and runs wherever goose-http does: Linux, macOS, and Windows. Most of the
setup is goose-http's, and this guide links to
[its development guide](https://github.com/kaitk/goose-http/blob/main/docs/development.md)
for it.

When a step fails in a way this guide doesn't explain, check
[known issues](known-issues.md), which lists environment traps and incidents by
platform.

## Layout

```text
rest.goose        the package's entry, namespace rest
runtime.goose     Cx, serve, route, fail, json, text, otherwise, and the error shape
extract.goose     the extractors: parameters, headers, cookies, take, once
middleware.goose  CORS, bearer, timed, and scope
waiting.goose     ask another thread, and resume with its reply
check.goose       what generated code calls: code points, string formats, numbers
gen/              goose-rest gen, the generator (gen/main.goose)
ts/               the TypeScript helper: types for the generator's subset, api.mts
examples/         JSON APIs with and without a schema, waiting on a thread, and a device
test/             unit tests, test_*.goose, each a root file; test/gen/ golden files
spikes/           language checks the design relies on, one folder each with a README
bench/            benchmark servers, scripts, and results (bench/README.md)
scripts/          test scripts, and the Goose and goose-http setup and pin scripts
docs/             the tutorial and its programs (docs/tutorial/), references, architecture,
                  benchmarks, development setup, known issues, Goose findings
tasks/            task tracking (tasks/README.md)
CHANGELOG.md      what each tag adds
```

## Get Goose

The scripts use the official Goose release that `scripts/goose.sh` pins: `v2026.1`
(`ac759c3`), since 2026-10-15. The first script that needs the compiler fetches it into
`build/`, as goose-http's does
([its Get Goose](https://github.com/kaitk/goose-http/blob/main/docs/development.md#get-goose)).
`scripts/goose.sh` is goose-http's, copied: keep the two the same. To fetch the compiler
and use it by hand:

```sh
GOOSE=$(scripts/goose.sh)
```

goose-rest needs no `.build` sidecar to exclude `build/`, as goose-http's `http.build`
does: its package has no C and no `extern fn`, and the suite passes with the release
unpacked there (2026-10-15).

## Build and test

The tests need git, `curl`, a C compiler, and on Linux liburing; the TypeScript
helper's tests also need Node or Bun ([below](#run-the-typescript-helpers-tests)). On
Ubuntu or Debian:

```sh
sudo apt-get install -y git curl gcc libc6-dev liburing-dev
```

On macOS, the Xcode command line tools (`xcode-select --install`) have all of them. On
Windows, run the tests in WSL ([below](#windows-through-wsl)). goose-http's guide has
each platform in full
([Linux](https://github.com/kaitk/goose-http/blob/main/docs/development.md#linux),
[macOS](https://github.com/kaitk/goose-http/blob/main/docs/development.md#macos)).
Then:

```sh
scripts/test.sh
```

The first run fetches the Goose release into `build/` and goose-http at its pin into
`~/.goose/pkg`, so it needs network access; later runs don't. `GOOSE` and
`GOOSE_COMMIT` pass through to the scripts it runs, which write only into `build/`,
which git ignores.

### Run every test

`scripts/test.sh` runs every test and stops at the first failure:

1. `goose check` on each root file under `test/`. `rest.goose` isn't checked on its own:
   `goose check` refuses a file without `main` ("program needs exactly one global fn
   main()"), so the tests' roots check it.
2. `scripts/test-unit.sh`, which runs each `test/test_*.goose` through TinyCC. Each test
   asserts what it tests and exits nonzero on the first failed `assert`.
3. The generator on each schema under `test/gen/`, `examples/`, and `docs/tutorial/`,
   whose output must match the golden `_gen.goose` beside it byte for byte. A change to
   the generator regenerates them ([generator.md](generator.md#tests)).
   Then the TypeScript helper's tests, where `tsc` is installed
   ([below](#run-the-typescript-helpers-tests)).
4. `scripts/test-examples.sh`, which builds each example under `examples/` and each
   tutorial program under `docs/tutorial/`, serves it on `127.0.0.1` from port 18081
   up, sends the requests its `requests.sh` lists with `curl`, and compares the answers
   with its `expected.txt`. A port in use there fails the run. A request that gives up,
   such as one with `-m`, is recorded as status `000` without a body:
   `examples/waiting` closes two clients early that way, and expects its database to
   count them, with a margin of 0.6 s. Then each tutorial program's `test.goose`,
   through TinyCC. `examples/device` reads its fake sysfs from `build/examples/` and
   takes paths of up to 1 KB ([known issues](known-issues.md#tests)).
5. Each spike's `main.goose`, whose standard output must match the `expected.txt` beside
   it ([below](#run-the-spikes)).
6. Spike 04's `-O2` C, which must keep `main_g` as its only Goose function, and
   `test/inline_route.goose`'s, whose middleware, route, and failing helpers must all be
   inlined into its handler.

A test can import a module of the package by name once its root declares the package:
`test/test_generator.goose` declares `import rest from "../";` and then imports
`gen/gen.goose` as `import rest.gen.gen;`. Goose traps met while writing the generator
and its tests are in [known issues](known-issues.md#goose).

### macOS

**OS:** tested on macOS 26.3.1, Apple M1 Pro (2026-10-13).

| Tool | Version used | For |
|---|---|---|
| C compiler | Apple clang 21.0.0 (`clang-2100.0.123.102`) | `goose build`, and reading the generated C (spike 04) |
| Node or Bun, TypeScript (optional) | Node 24.14.1, Bun 1.4.2, TypeScript 7.0.2 through npx or bunx (2026-10-14) | the TypeScript helper's tests |

### Windows through WSL

**OS:** tested on WSL2 Ubuntu 26.04.1, with Clang 21.1.8, Node 24.14.1, and TypeScript
7.0.2 (2026-10-14).

Run the suite in WSL, set up as goose-http's
[WSL2 on Windows](https://github.com/kaitk/goose-http/blob/main/docs/development.md#wsl2-on-windows)
says. Select the Ubuntu distribution explicitly from PowerShell:

```powershell
wsl -d Ubuntu -e bash -lc 'cd <repository-path-in-WSL> && GOOSE_CC=clang TSC="npx -y -p typescript tsc" scripts/test.sh'
```

Keep the actual paths in git-ignored `CLAUDE.local.md`. Put Linux Node and npx first on
WSL's `PATH`, use Node 24.14.1's Linux distribution, run this suite in WSL rather than
Git Bash, and set a Git identity in WSL before committing from it
([known issues](known-issues.md#wsl2-on-windows) says why).

### Run the TypeScript helper's tests

`ts/` holds the TypeScript helper and its tests, and goose-rest doesn't install a
JavaScript toolchain for them. `scripts/test.sh` runs `TSC`, or `tsc` on `PATH`, on
`ts/tsconfig.json`, which also covers the tutorial's `.mts` files, then runs
`ts/test/*.mts` and `docs/tutorial/06-schema/api.mts` with `JS`: `node`, or `bun` where
Node isn't installed. Without `tsc`, it prints `skipped` and goes on. With Node or Bun
installed and no `tsc`, npx or bunx fetches one for the run:

```sh
TSC="npx -y -p typescript tsc" scripts/test.sh
TSC="bunx -p typescript tsc" scripts/test.sh
```

Node and Bun run the `.mts` files directly, stripping their types; Node needs 22.18 or
later for that. The files are `.mts`, not `.ts`: without a `package.json` that says
`"type": "module"`, `tsc` reads a `.ts` file as CommonJS, where `import` is an error, and
Node warns before it rereads one as a module. The tests passed with TypeScript 7.0.2,
under Node 24.14.1 and under Bun 1.4.2, which print the same JSON (2026-10-14).

### Run the examples on arm64

`scripts/test-aarch64.sh` cross-builds every example for aarch64 Linux and runs
`scripts/test-examples.sh` on the builds in an arm64 `ubuntu:26.04` container, with each
one's peak RSS. It works as goose-http's script of the same name does, with the same
compiler choice and Docker setup
([its ARM under Docker](https://github.com/kaitk/goose-http/blob/main/docs/development.md#arm-under-docker));
goose-http's [embedded Linux](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers cross compilers, Yocto SDKs, and the checks to run on a board.

```sh
scripts/test-aarch64.sh
```

With `GOOSE_COMMIT`, it builds that commit in the amd64 container, into
`build/aarch64/goose/`, apart from a host build of the same commit. With `GOOSE_HTTP`
naming a goose-http checkout, it also cross-builds goose-http's `examples/device` from a copy of that checkout's
HEAD under `build/aarch64/goose-http`, and prints its peak RSS on one worker, for
comparison. `scripts/test-examples.sh` takes the switches the script needs: `BIN`,
where the examples are; `PREBUILT=1`, to run them without building; and `RSS=1`, to
print each example's peak RSS (VmHWM) once it answers and after its requests. What the
setup met under Docker Desktop is in [known issues](known-issues.md#arm-under-docker).

### Run the spikes

Each spike under `spikes/` is a root file that TinyCC runs in process:

```sh
GOOSE=$(scripts/goose.sh)
$GOOSE spikes/02-middleware-exit/main.goose
```

TinyCC can't run threads, so a spike that spawns one is built instead, as spike 06 is.
The compiler's own lines (`parsed ok`, `typechecked ok`, `bce`) go to standard error,
and `scripts/test.sh` compares only standard output:

```sh
$GOOSE build -o build/spike06 spikes/06-resume-waiting/main.goose && build/spike06
```

Its README gives the exact commands, including any `goose -O2 -o file.c` that reads the
generated C, and the output it expects. When a pin move changes a spike's output on
purpose, update its README and its `expected.txt` together.

### Use the package from git

A program outside the repository imports the package as a user's does, at a release tag
or a pushed commit by its full hash, next to goose-http at the pin
([README](../README.md#quick-start)). The compiler fetches it into
`~/.goose/pkg/github.com/kaitk/goose-rest/<12-hex hash>/`. Check it with `goose build`
and a program whose `main` spawns a `thread_fn` that calls `http::serve`: `goose run`
refuses it ("JIT mode does not support threads yet"), as TinyCC can't place
thread-local storage. Before pushing, a
`file:///<absolute path to this repository>@<hash>` source runs the same git fetch on a
local commit.

## Benchmarks

The REST benchmark runs on Linux, and its checks and the instruction counts of
`bench/routes.sh` and `bench/stack.sh` on macOS too. [bench/README.md](../bench/README.md)
sets them up: the servers, the scripts and their settings, and where results go.
[benchmarks.md](benchmarks.md) owns the current comparisons, the tiers, and the build
and Goose compiler each one measured.
[Known issues](known-issues.md#benchmarks) lists what can spoil a run.

## Use another compiler

Use another compiler only when the release can't do the job, such as for a Goose fix not
yet released. `GOOSE` names a binary, and `GOOSE_COMMIT` a commit of `aardappel/goose`
that the scripts clone and build into `build/goose-<commit>/`, as in goose-http
([its Use another compiler](https://github.com/kaitk/goose-http/blob/main/docs/development.md#use-another-compiler),
which also covers building a checkout by hand). Don't edit a checkout (`AGENTS.md`).

`bench/rest.sh` and `bench/all.sh` pass `GOOSE` on to goose-http's scripts, so the two
repositories build with the same compiler, and record it in `env.txt`. Goose `v2026.1`
has no `--version` option, so `scripts/goose.sh`'s `goose_version` names a compiler by
its release directory or its checkout's commit, and `bench/all.sh` adds the binary's
SHA-256 (2026-10-15).
