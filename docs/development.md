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
tests pass, and update the README's Pins table. Until goose-http's task 027 lands its
breaking changes, expect each move to need code changes here.

## Run the spikes

Each spike under `spikes/` is a root file that TinyCC runs in process:

```sh
$GOOSE spikes/02-middleware-exit/main.goose
```

Its README gives the exact commands, including any `goose -O2 -o file.c` that reads the
generated C, and the output it expects.
