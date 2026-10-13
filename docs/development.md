# Development

goose-rest is Goose with no C of its own. It runs on goose-http, whose shim is the only
C in a program, so it builds and runs wherever goose-http does: Linux, macOS, and
Windows ([goose-http's development.md](https://github.com/kaitk/goose-http/blob/main/docs/development.md)).
The spikes have run on macOS (2026-10-13).

## Toolchain

| Tool | macOS (2026-10-13) | For |
|---|---|---|
| Goose compiler | `0bdbd18`, the pin in `README.md` | everything |
| OS | macOS 26.3.1, Apple M1 Pro | |
| C compiler | Apple clang 21.0.0 (`clang-2100.0.123.102`) | `goose build`, and reading the generated C (spike 04) |

## Set up the Goose compiler

The spikes and scripts run the compiler that `GOOSE` names, or `goose` on `PATH` without
it, so the checkout can live anywhere; this page puts it next to this repository, at
`../goose`. Leave it on the pinned commit and don't edit it (`AGENTS.md`).

```sh
git clone -o upstream https://github.com/aardappel/goose.git ../goose
git -C ../goose checkout 0bdbd18
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
tests pass. The hash appears in `rest.goose`, in each root file under `test/` and
`bench/routes/`, and in the README's Pins table and Use section; change all of them. A root that declares
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
3. The generator on each schema under `test/gen/` and `examples/`, whose output must
   match the golden `_gen.goose` beside it byte for byte. A change to the generator
   regenerates them ([generator.md](generator.md#tests)).
4. `scripts/test-examples.sh`, which builds each example under `examples/`, serves it
   on `127.0.0.1` from port 18081 up, sends the requests its `requests.sh` lists with
   `curl`, and compares the answers with its `expected.txt`. A port in use there fails
   the run.
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

## Count instructions per request

goose-http's `bench/count.sh` counts a server's user instructions with Linux `perf`, and
macOS has none. `bench/routes.sh` uses its load on macOS instead: the server runs under
`/usr/bin/time -l`, whose "instructions retired" include the kernel's, and the count is
divided by the requests (goose-http's development.md, "macOS"). Docker Desktop's VM
exposes no hardware counters, so `perf` can't run there either.

```sh
GOOSE=$PWD/../goose-upstream/build-macos/goose bench/routes.sh
```

Traps met measuring task 007 (2026-10-13, h2load 1.70.0):

- h2load counts a 4xx response as "failed", not "succeeded", and `count.sh` exits unless
  every request succeeded. `bench/routes.sh` checks h2load's status-code line instead.
- `h2load -d /dev/null` fails with "Could not mmap file" at `-t 8`; an empty regular
  file can't be mapped either.
- h2load's POSTs ran at a tenth of its GETs' rate against the same server, which kept
  the connection open: about 35,000 requests a second against 330,000. The kernel's
  share then buries a router's cost, so `bench/routes.sh` sends only GETs.

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
