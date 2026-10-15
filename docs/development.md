# Development

goose-rest is Goose with no C of its own. It runs on goose-http, whose shim is the only
C in a program, so it builds and runs wherever goose-http does: Linux, macOS, and
Windows ([goose-http's development.md](https://github.com/kaitk/goose-http/blob/main/docs/development.md)).
The spikes have run on macOS (2026-10-13) and WSL2 Linux (2026-10-14).

## Toolchain

| Tool | macOS (2026-10-13) | For |
|---|---|---|
| Goose compiler | release `v2026.1`, fetched by `scripts/goose.sh` into `build/` ([below](#set-up-the-goose-compiler)) (2026-10-15) | everything |
| OS | macOS 26.3.1, Apple M1 Pro | |
| C compiler | Apple clang 21.0.0 (`clang-2100.0.123.102`) | `goose build`, and reading the generated C (spike 04) |
| Node or Bun, TypeScript (optional) | Node 24.14.1, Bun 1.4.2, TypeScript 7.0.2 through npx or bunx (2026-10-14) | the TypeScript helper's tests |

## Set up the Goose compiler

The scripts use the Goose release pinned in `scripts/goose.sh` (`v2026.1`, 2026-10-15)
unless told otherwise. The first script that needs the compiler downloads the release's
archive for the platform from
[the releases page](https://github.com/aardappel/goose/releases), checks its SHA-256,
and unpacks it into `build/goose-v2026.1-<platform>/`; later runs reuse it. Run
`scripts/goose.sh` to fetch it and print the compiler's path, for running a spike or
the compiler by hand:

```sh
GOOSE=$(scripts/goose.sh)
```

The release needs the C library's headers on Linux and the Xcode command line tools on
macOS ([Goose's README](https://github.com/aardappel/goose#install-a-release)). Linux on
arm64 has no release archive, so there the script builds the release's tag from source,
as `GOOSE_COMMIT` does below. `scripts/goose.sh` is goose-http's, copied: keep the two
the same.

Use another compiler only when the release can't do the job, such as a Goose fix not yet
released. Two settings choose one, and the first set wins:

| Setting | Compiler |
|---|---|
| `GOOSE` | The binary it names, such as a checkout's build or a release unpacked elsewhere. |
| `GOOSE_COMMIT` | That commit of `aardappel/goose`, cloned into `build/goose-<commit>/` and built with CMake (and Ninja if installed) on first use. Give the full 40-hex hash; a shallow fetch can't resolve an abbreviated one. |

`bench/rest.sh` and `bench/all.sh` record which one ran in `env.txt`: the release's tag,
or a checkout's commit. Both pass `GOOSE` on to goose-http's scripts, so the two
repositories build with the same compiler.

To build a checkout by hand, clone it anywhere, build it with CMake, and point `GOOSE` at
its build. Don't edit it (`AGENTS.md`). goose-http's development.md covers Windows.

```sh
git clone -o upstream https://github.com/aardappel/goose.git ../goose
cmake -S ../goose -B ../goose/build-macos -DCMAKE_BUILD_TYPE=Release
cmake --build ../goose/build-macos -j
export GOOSE=$PWD/../goose/build-macos/goose
```

### Move the pin

The pin is a Goose release. At the start of a session, check for a newer one:

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
the commit and verdict in each spike's README, and update the pin in `README.md` and the
table above, in its own commit.

Pin a commit only when a Goose fix that this repository needs isn't in a release yet:
set `GOOSE_COMMIT` in the scripts' environment, record the commit in the README's Pins
table with the reason, and return to a release once one includes the fix.

### Move the goose-http pin

goose-rest imports goose-http at a release tag or a full commit hash; git can't fetch an
abbreviated hash. Move it to a pushed release or commit in its own commit once the
tests pass. The reference appears in each of the package's files, in each root file under
`test/`, `examples/`, `docs/tutorial/`, `spikes/`, and `bench/`, in the README's Pins
table and Quick start, and in `docs/tutorial.md`. `scripts/move-http-pin.sh` changes
every one:

```sh
git -C ../goose-http fetch --tags
scripts/move-http-pin.sh v0.3.1
```

A release tag is for a release; a commit hash is for a fix not yet released. For a tag,
the script writes the commit it resolves to in `../goose-http` (or `GOOSE_HTTP`) into
the README's Pins row, so fetch that checkout's tags first. Then update the row's date and the goose-http
reference each spike's README names, once `scripts/test.sh` passes. A root that declares
goose-http at another commit than `rest.goose` gets a warning, and from another source
an error, so a test can't point at a local goose-http checkout instead.

## Run the tests

`scripts/test.sh` runs every test and stops at the first failure:

1. `goose check` on each root file under `test/`. `rest.goose` isn't checked on its own:
   `goose check` refuses a file without `main` ("program needs exactly one global fn
   main()"), so the tests' roots check it.
2. `scripts/test-unit.sh`, which runs each `test/test_*.goose` through TinyCC. Each test
   asserts what it tests and exits nonzero on the first failed `assert`.
3. The generator on each schema under `test/gen/`, `examples/`, and `docs/tutorial/`,
   whose output must match the golden `_gen.goose` beside it byte for byte. A change to the generator
   regenerates them ([generator.md](generator.md#tests)).
   Then the TypeScript helper's tests, where `tsc` is installed
   ([below](#run-the-typescript-helpers-tests)).
4. `scripts/test-examples.sh`, which builds each example under `examples/` and each
   tutorial program under `docs/tutorial/`, serves it on `127.0.0.1` from port 18081
   up, sends the requests its `requests.sh` lists with `curl`, and compares the answers
   with its `expected.txt`. A port in use there fails the run. A request that gives up,
   such as one with `-m`, is recorded as status `000` without a body:
   `examples/waiting` closes two clients early that way, and expects its database to
   count them, with a margin of 0.6 s. Then each tutorial
   program's `test.goose`, through TinyCC. `examples/device` reads its fake sysfs from
   `build/examples/` and takes paths of up to 1 KB, so a checkout deeper than that fails
   its run as "no answer on port", with "THERMAL is too long" in
   `build/examples/device.log`.
5. Each spike's `main.goose`, whose standard output must match the `expected.txt` beside
   it. The compiler's own lines (`parsed ok`, `typechecked ok`, `bce`) go to standard
   error and aren't compared. TinyCC can't run threads, so a `main.goose` that calls
   `thread_spawn` (spike 06) is built with `goose build` into `build/spike` and run
   from there.
6. Spike 04's `-O2` C, which must keep `main_g` as its only Goose function, and
   `test/inline_route.goose`'s, whose middleware, route, and failing helpers must all be
   inlined into its handler.

A test can import a module of the package by name once its root declares the package:
`test/test_generator.goose` declares `import rest from "../";` and then imports
`gen/gen.goose` as `import rest.gen.gen;`.

Goose traps met while writing the generator and its tests (2026-10-13):

- A `"""` string must start its text on the line after the `"""` if it spans lines.
  Keep a one-line JSON document on one line.
- A slice that starts as `""` can't later point into a buffer, nor into the JSON
  document: start it from that buffer (`r.text[..0]`), or return it from a function
  (spike 05).
- An optional reference field is rebound with `.=`, not assigned: `ty.minimum .= n`.
- Mutually recursive emitters need `recursive fn`; split them instead where one level
  is enough (`write_value` and `write_one`).

```sh
scripts/test.sh
```

The first run fetches the Goose release into `build/` and goose-http at its pin into
`~/.goose/pkg`, so it needs network access; later runs don't. `GOOSE` and
`GOOSE_COMMIT` pass through to the scripts it runs. Both scripts write only into
`build/`, which git ignores.

goose-rest has no `.build` sidecar, so nothing excludes `build/` from the package, as
goose-http's `http.build` must: there, the unpacked release's stdlib `extern fn`s would
enter the package's JIT library and fail to link. goose-rest's package has no C and no
`extern fn`, and the suite passes with the release unpacked in `build/` (2026-10-15).

### Run the TypeScript helper's tests

`ts/` holds the TypeScript helper and its tests, and goose-rest doesn't install a
JavaScript toolchain for them. `scripts/test.sh` runs `TSC`, or `tsc` on `PATH`, on
`ts/tsconfig.json`, which also covers the tutorial's `.mts` files, then runs
`ts/test/*.mts` and `docs/tutorial/06-schema/api.mts` with `JS`: `node`, or `bun` where Node
isn't installed. Without `tsc`, it prints `skipped` and goes on. With Node or Bun
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

### Run from Windows through WSL

Validated (2026-10-14): WSL2 Ubuntu 26.04.1, Clang 21.1.8, Node 24.14.1, and
TypeScript 7.0.2. Select the Ubuntu distribution explicitly from PowerShell:

```powershell
wsl -d Ubuntu -e bash -lc 'cd <repository-path-in-WSL> && GOOSE_CC=clang TSC="npx -y -p typescript tsc" scripts/test.sh'
```

Keep the actual paths in git-ignored `CLAUDE.local.md`. Put Linux Node and npx first
on WSL's `PATH`: Windows npx accepts neither the Linux paths passed by the suite nor
its Linux TypeScript package. Ubuntu's Node 22.22.1 was built without TypeScript
support, despite its version; Node 24.14.1's Linux distribution runs the `.mts` files.
Git Bash's converted paths also differ from the exact generator diagnostics the
suite checks, so run this suite in WSL.

The Ubuntu distribution runs as `root`. Without a global Git identity there, Git
records the author as `root@<hostname>`, so set `user.name` and `user.email` in WSL
before committing from it (2026-10-14).

Goose `v2026.1` has no `--version` option, so `scripts/goose.sh`'s `goose_version` names
a compiler by its release directory or its checkout's commit, and `bench/all.sh` adds
the binary's SHA-256 (2026-10-15).

## Run the examples on arm64

`scripts/test-aarch64.sh` cross-builds every example for aarch64 Linux in an amd64
`ubuntu:26.04` container, with Ubuntu's `gcc-aarch64-linux-gnu` and arm64 liburing,
then runs `scripts/test-examples.sh` on the builds in an arm64 `ubuntu:26.04` container
and prints each example's peak RSS (task 013). It follows goose-http's script of the
same name, and goose-http's
[docs/embedded.md](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers cross compilers, Yocto SDKs, and the checks to run on a board.

```sh
GOOSE_HTTP=../goose-http scripts/test-aarch64.sh
```

The cross-build needs a Linux build of the Goose compiler that runs in that amd64
container. With `GOOSE` unset, the script uses the pinned release's `linux-x64` archive,
which `scripts/goose.sh` fetches on any host, macOS included. With `GOOSE_COMMIT`, it
builds that commit in the amd64 container instead, into `build/aarch64/goose/`, apart
from a host build of the same commit. A `GOOSE` of its own must be a Linux x86-64 build
that runs on Ubuntu 26.04, beside its stdlib or in its checkout. With `GOOSE_HTTP` set,
it also cross-builds goose-http's `examples/device` from a copy of that checkout's HEAD
under `build/aarch64/goose-http`, and prints its peak RSS on one worker, for comparison.

`scripts/test-examples.sh` takes the switches the script needs: `BIN`, where the
examples are; `PREBUILT=1`, to run them without building; and `RSS=1`, to print each
example's peak RSS (VmHWM) once it answers and after its requests.

What the setup met (2026-10-14, Docker Desktop 29.8.2 on an Apple M1 Pro):

- On an arm64 host, the arm64 container runs natively in Docker Desktop's VM, and the
  amd64 one under Rosetta. On an x86-64 host it's the reverse: the checks run under
  qemu, whose own memory adds to each RSS.
- The compiler fetches goose-http with git into `build/aarch64/goose-home`, and git
  refuses the mounted directory ("detected dubious ownership"), as it refuses the clone
  of a `GOOSE_COMMIT` build there (2026-10-15). The script sets `safe.directory` through
  `GIT_CONFIG_*` variables for both.
- Docker's seccomp profile blocks `io_uring_setup`, so `rest::serve` runs on goose-http's
  emulated ring over epoll there.

## Run the spikes

Each spike under `spikes/` is a root file that TinyCC runs in process:

```sh
GOOSE=$(scripts/goose.sh)
$GOOSE spikes/02-middleware-exit/main.goose
```

A spike that spawns a thread is built instead, as spike 06 is:

```sh
$GOOSE build -o build/spike06 spikes/06-resume-waiting/main.goose && build/spike06
```

Its README gives the exact commands, including any `goose -O2 -o file.c` that reads the
generated C, and the output it expects. When a pin move changes a spike's output on
purpose, update its README and its `expected.txt` together.

## Count instructions per request

goose-http's `bench/count.sh` counts a server's user instructions with Linux `perf`, and
macOS has none. `bench/routes.sh` uses its load on macOS instead: the server runs under
`/usr/bin/time -l`, whose "instructions retired" include the kernel's, and the count is
divided by the requests (goose-http's development.md, "macOS"). Docker Desktop's VM
exposes no hardware counters, so `perf` can't run there either.

```sh
bench/routes.sh
```

A full run takes about 5 minutes. To check a change to goose-rest's request path
quickly, run only its servers, once, at a tenth of the requests, in about 20 s, and
then do a full run for the numbers you record:

```sh
SERVERS="gen60 hand60" RUNS=1 N=200000 bench/routes.sh
```

`bench/stack.sh` counts a JSON body and the middleware stack the same way, with wrk
pipelined 16 deep, in about 3 minutes (`RUNS=1 D=3` for a quick check). It needs the
datasets goose-http's `bench/rest.sh build` writes, in `../goose-http/build/rest`
unless `REST_DATA` names another folder.

```sh
bench/stack.sh
```

A Docker container gives req/s but no instruction counts, for the reason above. These
macOS counts vary by less than 1.5% between rounds.

Traps met measuring task 007 (2026-10-13, h2load 1.70.0):

- h2load counts a 4xx response as "failed", not "succeeded", and `count.sh` exits unless
  every request succeeded. `bench/routes.sh` checks h2load's status-code line instead.
- `h2load -d /dev/null` fails with "Could not mmap file" at `-t 8`; an empty regular
  file can't be mapped either.
- h2load's POSTs ran at a tenth of its GETs' rate against the same server, which kept
  the connection open: about 35,000 requests a second against 330,000. The kernel's
  share then buries a router's cost, so `bench/routes.sh` sends only GETs.

## Run the REST benchmark

Task 010's servers live under `bench/rest/`: `goose-rest/`, a fork of goose-http's
task 021 server onto goose-rest; `axum/` and `actix-web/`, with `rust-app/` the records
and JSON they share; `dusty/`, dusty with a route per path; and `tiers/`, goose-rest's
own tiers F, R, and M, with their checker, loads, and summary. `bench/rest.sh` wraps
goose-http's `bench/rest.sh`, which it finds in `GOOSE_HTTP` (`../goose-http`), checked
out at the pin `rest.goose` imports. Its header lists the commands and settings.

```sh
bench/rest.sh build    # goose-http's servers and datasets, then this repository's
bench/rest.sh check    # every server on every tier, against both checkers
bench/rest.sh run      # tiers A to D through goose-http's script, then F, R, and M
sudo bench/rest.sh count
```

`bench/all.sh` measures goose-http's and this repository's Goose servers in one
unattended session, without the frameworks, whose cells come from earlier runs. It
checks the machine first, then runs both repositories' `scripts/test.sh`, the Goose
builds with `ONLY=goose`, `bench/rest.sh check`, goose-http's `bench/run.sh` and
`bench/files.sh`, `bench/rest.sh run`, and, as root, goose-http's
`bench/instructions.sh` and `bench/rest.sh count`. It stops at the first failure, and
took about 2 h 30 min on the Linux desktop (2026-10-14). Its checks need:

- goose-http's checkout in `GOOSE_HTTP` (`../goose-http`). Both repositories build
  with the pinned release, or with the compiler `GOOSE` or `GOOSE_COMMIT` names.
- Root, or `sudo` without a password.
- Both checkouts clean and at `origin/main`, so push or pull first, and goose-http's
  code the same as at the tag `rest.goose` pins.
- An idle machine: a 1-minute load average of at most `IDLE_LOAD` (0.5) in two checks
  30 s apart, and on WSL a Windows CPU load of at most `IDLE_CPU` percent (10).

Tiers A to C run at the fixed rates `RATE_A`, `RATE_B`, and `RATE_C` (100,000, 24,000,
and 1,700, the full run of 2026-10-13's), so that their cells compare with earlier
runs. The results go to goose-http's `bench/results/` under one time stamp, and the
session's log, step times, and environment to `build/bench-all/<stamp>-<machine>/`.
Nothing is committed: writing the results up is a separate step. The header lists every
setting.

`run` and `count` need Linux: `taskset`, `/proc`, and `perf`. `check` runs on macOS too,
after `OWN=1 bench/rest.sh build`, which skips goose-http's build, given goose-http's
datasets in its `build/rest` (`goose build` and run its `bench/rest/gen.goose` into
it). What the setup met on macOS (2026-10-14):

- dusty pins Zig 0.16.0, and Homebrew's `zig` is 0.17.0. ziglang.org's 0.16.0 tarball
  for `aarch64-macos` works; set `ZIG` to its `zig`. zio 0.19.1 runs on kqueue.
- Zig 0.16 fetches packages into `zig-pkg/` beside `build.zig.zon`, so `bench/rest.sh`
  builds dusty from a copy in `CACHE`, and passes tier R's route list with `-Dgithub`.
- `bench/rest/goose-rest/github_gen.goose` is generated from `github.json`, which
  `bench/rest/tiers/github_goose.py` writes with `github_app.goose` from `github.txt`.
  `scripts/test.sh` checks it as a golden file.
- In zsh, `env $v` passes a variable holding `A=1 B=2` as one argument; `bench/rest.sh`
  is `sh`, where it splits.

## Use the package from git

A program outside the repository imports the package as a user's does, at a pushed
commit, by its full hash, next to goose-http at the pin ([README](../README.md#quick-start)). The compiler
fetches it into `~/.goose/pkg/github.com/kaitk/goose-rest/<12-hex hash>/`. Check it
with `goose build` and a program whose `main` spawns a `thread_fn` that calls
`http::serve`: `goose run` refuses it ("JIT mode does not support threads yet"), as
TinyCC can't place thread-local storage. This held on 2026-10-13, at goose-rest
`d3e847b`, on macOS: the program built, and its server answered `curl` with
`rest::path_of`'s result.

Before pushing, a `file:///<absolute path to this repository>@<hash>` source runs the
same git fetch on a local commit.
