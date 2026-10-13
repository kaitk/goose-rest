# Development

goose-rest is Goose with no C of its own. It runs on goose-http, whose shim is the only
C in a program, so it builds and runs wherever goose-http does: Linux, macOS, and
Windows ([goose-http's development.md](https://github.com/kaitk/goose-http/blob/main/docs/development.md)).
The spikes have run on macOS (2026-10-13).

## Toolchain

| Tool | macOS (2026-10-13) | For |
|---|---|---|
| Goose compiler | `a6249a4`, the pin in `README.md` | everything |
| OS | macOS 26.3.1, Apple M1 Pro | |
| C compiler | Apple clang 21.0.0 (`clang-2100.0.123.102`) | `goose build`, and reading the generated C (spike 04) |

## Set up the Goose compiler

The spikes and scripts run the compiler that `GOOSE` names, or `goose` on `PATH` without
it, so the checkout can live anywhere; this page puts it next to this repository, at
`../goose`. Leave it on the pinned commit and don't edit it (`AGENTS.md`).

```sh
git clone -o upstream https://github.com/aardappel/goose.git ../goose
git -C ../goose checkout a6249a4
cmake -S ../goose -B ../goose/build-macos -DCMAKE_BUILD_TYPE=Release
cmake --build ../goose/build-macos -j
export GOOSE=$PWD/../goose/build-macos/goose
```

On Linux, name the build directory `build-linux`. goose-http's development.md covers
Windows.

### Move the pin

The Goose repository changes daily. Fetch it at the start of a session, and move the pin
in its own commit once the spikes still give their recorded results:

```sh
git -C ../goose fetch upstream
git -C ../goose log --oneline HEAD..upstream/master
git -C ../goose checkout upstream/master
cmake --build ../goose/build-macos -j
```

Then rerun each spike as its README says, update the commit and verdict there, and
update the pin in `README.md` and the table above.

### Move the goose-http pin

goose-rest imports goose-http by its full commit hash; git can't fetch an abbreviated
one. Move it to a pushed commit of goose-http's `main`, in its own commit, once the
tests pass. The hash appears in `rest.goose`, in each root file under `test/`, and in
the README's Pins table and Use section; change all of them. A root that declares
goose-http at another commit than `rest.goose` gets a warning, and from another source
an error, so a test can't point at a local goose-http checkout instead. Until goose-http's task 027 lands its
breaking changes, expect each move to need code changes here.

## Run the tests

`scripts/test.sh` runs every test and stops at the first failure:

1. `goose check` on each root file under `test/`. `rest.goose` isn't checked on its own:
   `goose check` refuses a file without `main` ("program needs exactly one global fn
   main()"), so the tests' roots check it.
2. `scripts/test-unit.sh`, which runs each `test/test_*.goose` through TinyCC. Each test
   asserts what it tests and exits nonzero on the first failed `assert`.
3. Each spike's `main.goose`, whose standard output must match the `expected.txt` beside
   it. The compiler's own lines (`parsed ok`, `typechecked ok`, `bce`) go to standard
   error and aren't compared. TinyCC can't run threads, so a `main.goose` that calls
   `thread_spawn` (spike 06) is built with `goose build` into `build/spike` and run
   from there.
4. Spike 04's `-O2` C, which must keep `main_g` as its only Goose function.

```sh
GOOSE=$PWD/../goose/build-macos/goose scripts/test.sh
```

The first run fetches goose-http at its pin into `~/.goose/pkg`, so it needs network
access; later runs don't. Both scripts write only into `build/`, which git ignores.

## Run the spikes

Each spike under `spikes/` is a root file that TinyCC runs in process:

```sh
$GOOSE spikes/02-middleware-exit/main.goose
```

A spike that spawns a thread is built instead, as spike 06 is:

```sh
$GOOSE build -o build/spike06 spikes/06-resume-waiting/main.goose && build/spike06
```

Its README gives the exact commands, including any `goose -O2 -o file.c` that reads the
generated C, and the output it expects. When a pin move changes a spike's output on
purpose, update its README and its `expected.txt` together.

## Use the package from git

A program outside the repository imports the package as a user's does, at a pushed
commit, by its full hash, next to goose-http at the pin (README, "Use"). The compiler
fetches it into `~/.goose/pkg/github.com/kaitk/goose-rest/<12-hex hash>/`. Check it
with `goose build` and a program whose `main` spawns a `thread_fn` that calls
`http::serve`: `goose run` refuses it ("JIT mode does not support threads yet"), as
TinyCC can't place thread-local storage. This held on 2026-10-13, at goose-rest
`d3e847b`, on macOS: the program built, and its server answered `curl` with
`rest::path_of`'s result.

Before pushing, a `file:///<absolute path to this repository>@<hash>` source runs the
same git fetch on a local commit.
