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
waiting.goose     lanes of jobs: ask one, run its jobs, and resume with its reply
compression.goose rest::compressed, a module rest doesn't import (goose-compress)
check.goose       what generated code calls: code points, string formats, numbers
gen/              goose-rest gen, the generator (gen/main.goose)
ts/               the TypeScript helper: types for the generator's subset, api.mts
examples/         JSON APIs with and without a schema, waiting on a thread, compressed
                  answers, and a device
test/             tests by area, test/<area>/<name>.goose, with golden files in
                  test/expected/ and the runner, run_tests.py; test/gen/ the
                  generator's golden files
spikes/           language checks the design relies on, one folder each with a README
bench/            benchmark servers, scripts, and results (bench/README.md)
scripts/          test scripts, and the Goose and goose-http setup and pin scripts
docs/             the tutorial and its programs (docs/tutorial/), the best practices and
                  theirs (docs/best-practices/), references, architecture, decisions,
                  benchmarks, development setup, known issues, Goose findings
tasks/            task tracking (tasks/README.md)
CHANGELOG.md      what each tag adds
```

## Get Goose

Until the next release, the scripts build Goose master `dcc2747` (2026-10-19), which
`goose_commit` in `scripts/goose.sh` pins, as goose-http does: the pinned goose-http's
`http::run` and `http::lane_open` need
[aardappel/goose#37](https://github.com/aardappel/goose/pull/37), which no release has
yet. Building it needs CMake and a C++ compiler. Otherwise the scripts use the official
Goose release that `scripts/goose.sh` pins: `v2026.2` (`3ee3871`), since 2026-10-16.
The first script that needs the compiler fetches it into
`build/`, as goose-http's does
([its Get Goose](https://github.com/kaitk/goose-http/blob/main/docs/development.md#get-goose)).
`scripts/goose.sh` is a copy of goose-http's script: keep the two the same. To fetch the compiler
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

When using `GOOSE_COMMIT` or Linux on arm64, which has no Goose release archive, the
scripts build Goose from source; also run `sudo apt-get install -y cmake g++`. Both sets passed the suite on a
clean `ubuntu:26.04` for arm64 (2026-10-15).

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

`scripts/test.sh` runs every test and stops at the first step that fails:

1. `test/run_tests.py`, which runs the tests under `test/<area>/` and reports every
   failure among them ([below](#run-the-tests-by-area)).
2. The generator on each schema under `test/gen/`, `examples/`, and `docs/tutorial/`,
   whose output must match the golden `_gen.goose` beside it byte for byte. A change to
   the generator regenerates them ([generator.md](generator.md#8-tests)).
   Then the TypeScript helper's tests, with `tsc`, or one npx or bunx fetches
   ([below](#run-the-typescript-helpers-tests)).
3. `scripts/test-examples.sh`, which builds each example under `examples/` and each
   program under `docs/tutorial/` and `docs/best-practices/`, serves it on `127.0.0.1`
   from port 18081 up, sends the requests its `requests.sh` lists with `curl`, and
   compares the answers with its `expected.txt`. A port in use there fails the run. A
   request that gives up, such as one with `-m`, is recorded as status `000` without a
   body: `docs/tutorial/13-limits` closes two clients early that way, and expects its
   database to count them, with a margin of 0.5 s. Then each tutorial and
   best-practices program's `test.goose`, through TinyCC, and each `rust` and `json` block of the tutorial's and
   the best practices' pages, which must appear as it is in a program or an example.
   `examples/device` reads its fake sysfs from `build/examples/` and takes paths of up
   to 1 KB ([known issues](known-issues.md#tests)).
4. Each spike's `main.goose`, whose standard output must match the `expected.txt` beside
   it ([below](#run-the-spikes)).
5. Spike 04's `-O2` C, which must keep `main_g` as its only Goose function, and
   `test/inline_route.goose`'s, whose middleware, route, and failing helpers must all be
   inlined into its handler.

### Run the tests by area

The tests follow Goose's own convention ([decisions](decisions.md#tests)). Each
`test/<area>/<name>.goose` with a `main` is a test: a small program that asserts what it
checks and prints it. Its standard output must match `test/expected/<name>.out`, every
nonblank line of `test/expected/<name>.stderr`, where there is one, must occur in its
standard error, and `test/expected/<name>.aborts` marks a test that must exit nonzero. A
file with `// error: <message>` lines is a fixture that must fail to compile with each
message; `test/errors/` holds them. Any other file in an area, `common.goose`, holds what
that area's tests share, and `test/expect.goose` holds what all of them share: `expect::same`,
`expect::body_of`, and the like.

`test/run_tests.py` needs Python 3 and nothing else. It checks every test and fixture in
batches, a `goose --multi-test --check` per batch, then builds each test with
`goose build` at `-O0` and at `-O2` and runs it in a directory of its own under
`build/test/`, the tests in parallel. It reports every failure, with a unified diff for
changed output, then a count per area:

```sh
python3 test/run_tests.py              # every test, about a minute
python3 test/run_tests.py --jit        # through TinyCC, without a C compiler: seconds
python3 test/run_tests.py router       # one area
python3 test/run_tests.py cors -O 0    # one test, at one level
python3 test/run_tests.py cors --bless # rewrite test/expected/cors.out from its output
```

`--bless` writes what each test printed to its golden file; review the change with
`git diff test/expected/` before committing it. `-j` sets how many processes run at
once, and `-v` prints the checks that passed too. The runner takes `GOOSE` and
`GOOSE_COMMIT` as the scripts do, and `goose build` takes `GOOSE_CC`.

A test's root declares the package as `import rest from "../../";`, and `test/` itself as
`import expect from "../";`, which reaches `test/expect.goose` and, as
`import expect.gen.api_gen;`, the generated modules under `test/gen/`. A root imports a
module of the package by name once it declares the package: `test/generator/` imports
`gen/gen.goose` as `import rest.gen.gen;`. Goose traps met while writing the generator
and its tests are in [known issues](known-issues.md#goose).

### macOS

**OS:** tested on macOS 26.3.1, Apple M1 Pro (2026-10-13).

| Tool | Version used | For |
|---|---|---|
| C compiler | Apple clang 21.0.0 (`clang-2100.0.123.102`) | `goose build`, and reading the generated C (spike 04) |
| Node or Bun, TypeScript (optional) | Node 24.14.1, Bun 1.4.2, TypeScript 7.0.2 through npx or bunx (2026-10-14) | the TypeScript helper's tests |

### Windows

**OS:** tested on Windows 11 Pro 10.0.26300, in Git Bash, with MSVC 19.51, Python
3.14.6, Node 24.18.0, TypeScript 7.0.2, and Git for Windows' curl 8.7.1 (2026-10-18).

The package runs natively on Windows on goose-http's IOCP loop. Set up the C compiler as
goose-http's
[Windows](https://github.com/kaitk/goose-http/blob/main/docs/development.md#windows)
section says, then run the suite in Git Bash:

```sh
nice -n 19 scripts/test.sh
```

`nice -n 19` starts native programs in the Idle priority class. The scripts name each
program they build with its `.exe`, so a Linux build left in the same tree by WSL
doesn't run instead. Git Bash has traps of its own
([known issues](known-issues.md#git-bash-on-windows)).

### Windows through WSL

**OS:** tested on WSL2 Ubuntu 26.04.1, with Clang 21.1.8, Node 24.14.1, and TypeScript
7.0.2 (2026-10-14).

WSL runs the suite on Linux, with io_uring. Set it up as goose-http's
[WSL2 on Windows](https://github.com/kaitk/goose-http/blob/main/docs/development.md#wsl2-on-windows)
says. Select the Ubuntu distribution explicitly from PowerShell:

```powershell
wsl -d Ubuntu -e bash -lc 'cd <repository-path-in-WSL> && GOOSE_CC=clang TSC="npx -y -p typescript tsc" scripts/test.sh'
```

Keep the actual paths in git-ignored `CLAUDE.local.md`. Put Linux Node and npx first on
WSL's `PATH`, use Node 24.14.1's Linux distribution, and set a Git identity in WSL
before committing from it
([known issues](known-issues.md#wsl2-on-windows) says why).

### Run the TypeScript helper's tests

`ts/` holds the TypeScript helper and its tests, and goose-rest doesn't install a
JavaScript toolchain for them. `scripts/test.sh` runs `TSC`, or `tsc` on `PATH`, on
`ts/tsconfig.json`, which also covers the tutorial's `.mts` files, then runs
`ts/test/*.mts` and `docs/tutorial/05-schema/api.mts` with `JS`: `node`, or `bun` where
Node isn't installed. Without `tsc` on `PATH`, npx or bunx fetches TypeScript 7.0.2 for
the run, the release `scripts/test.sh` pins. With neither, or offline, it prints
`skipped` and goes on. `TSC` names another compiler:

```sh
TSC="npx -y -p typescript@7.0.2 tsc" scripts/test.sh
TSC="bunx -p typescript@7.0.2 tsc" scripts/test.sh
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

A program outside the repository imports the package in the same way as a user's program,
at a release tag or a pushed commit identified by its full hash, alongside goose-http at the pin
([README](../README.md#quick-start)). The compiler fetches it into
`~/.goose/pkg/github.com/kaitk/goose-rest/<12-hex hash>/`. Check it with `goose build`
and a program whose `main` spawns a `thread_fn` that calls `http::serve`: `goose run`
refuses it ("JIT mode does not support threads yet"), as TinyCC can't place
thread-local storage. Before pushing, a
`file:///<absolute path to this repository>@<hash>` source runs the same git fetch on a
local commit.

## Benchmarks

The REST benchmark runs on Linux. Its checks and the instruction counts from
`bench/routes.sh` and `bench/stack.sh` also run on macOS. [bench/README.md](../bench/README.md)
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
repositories build with the same compiler, and record it in `env.txt`. Goose `v2026.2`
has no `--version` option, so `scripts/goose.sh`'s `goose_version` names a compiler by
its release directory or its checkout's commit, and `bench/all.sh` adds the binary's
SHA-256 (2026-10-15).
