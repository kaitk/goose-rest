# Benchmark

Build and run goose-rest's benchmark servers, configure the workloads, and keep their
results. The [benchmark summary](../docs/benchmarks.md) owns the current comparisons and
the tiers. Most of the harness is goose-http's, which this directory wraps:
[its bench/README.md](https://github.com/kaitk/goose-http/blob/main/bench/README.md)
has the toolchain, the method, and how each number is taken.

```sh
bench/rest.sh build    # goose-http's servers and datasets, then this repository's
bench/rest.sh check    # every server on every tier, against both checkers
bench/rest.sh run      # tiers A to D through goose-http's script, then F, R, and M
sudo bench/rest.sh count  # user instructions per request, with perf
bench/all.sh           # both repositories' Goose servers in one unattended session
bench/routes.sh        # instructions per request of the routers, on macOS
bench/stack.sh         # instructions per request of a JSON body and the middleware, on macOS
bench/raw.sh           # pushes raw output to the bench-raw branch, or pulls it
```

`bench/rest.sh` and `bench/stack.sh` use goose-http's benchmark scripts and datasets.
They clone goose-http at the pin `rest.goose` imports into `build/goose-http-<ref>/` on
first use (`scripts/goose-http.sh`), or use the checkout `GOOSE_HTTP` names.
`bench/all.sh` also tests and benchmarks goose-http itself, so it needs `GOOSE_HTTP`
to name a checkout on its `main` ([below](#an-unattended-session)).

`run` and `count` need Linux: `taskset`, `/proc`, and `perf`. Each script's header lists
its settings. [Known issues](../docs/known-issues.md#benchmarks) lists the traps the
scripts work around.

## Servers

The REST servers live under `rest/`:

- `goose-rest/`: goose-http's REST tier server at goose-http's pin, ported onto
  goose-rest: its routes, extractors, and middleware are goose-rest's, and it loads,
  hands over, and holds its records as goose-http's server does, its prebuilt JSON in
  goose-http's shared store.
- `axum/` and `actix-web/`, with `rust-app/` the records and JSON they share.
- `dusty/`: dusty with a route per path.
- `tiers/`: goose-rest's own tiers F, R, and M, with their checker, loads, and summary.

Each framework serves through its own router, extractors or body readers, and JSON,
built in release mode in its fastest documented configuration; each entry's `NOTES.md`
records its configuration. `bench/rest.sh` wraps goose-http's `bench/rest.sh`, from that
checkout.

`rest/goose-rest/github_gen.goose` is generated from `github.json`, which
`rest/tiers/github_goose.py` writes with `github_app.goose` from `github.txt`.
`scripts/test.sh` checks it as a golden file.

`check` runs on macOS too, after `OWN=1 bench/rest.sh build`, which skips goose-http's
build, given goose-http's datasets in its `build/rest` (`goose build` and run its
`bench/rest/gen.goose` into it). dusty needs Zig 0.16.0 there, which Homebrew doesn't
install ([known issues](../docs/known-issues.md#the-rest-benchmark-on-macos)).

## An unattended session

`bench/all.sh` measures goose-http's and this repository's Goose servers in one
unattended session, without the frameworks, whose cells come from earlier runs. It
checks the machine first, then runs both repositories' `scripts/test.sh`, the Goose
builds with `ONLY=goose`, `bench/rest.sh check`, goose-http's `bench/run.sh` and
`bench/files.sh`, `bench/rest.sh run`, and, as root, goose-http's
`bench/instructions.sh` and `bench/rest.sh count`. It stops at the first failure, and
took about 2 h 30 min on the Linux desktop (2026-10-14). Its checks need:

- goose-http's checkout in `GOOSE_HTTP`. Both repositories build
  with the pinned release, or with the compiler `GOOSE` or `GOOSE_COMMIT` names.
- Root, or `sudo` without a password.
- Both checkouts clean and at `origin/main`, so push or pull first, and goose-http's
  code the same as at the tag `rest.goose` pins.
- An idle machine: a 1-minute load average of at most `IDLE_LOAD` (0.5) in two checks
  30 s apart, and on WSL a Windows CPU load of at most `IDLE_CPU` percent (10).

Tiers A to C run at the fixed rates `RATE_A`, `RATE_B`, and `RATE_C` (100,000, 24,000,
and 1,700, the full run of 2026-10-13's), so that their cells compare with earlier
runs. Under one time stamp, goose-http's own runs go to its `bench/results/`, the REST
run to this repository's ([Results](#results)), and the session's log, step times, and
environment to `build/bench-all/<stamp>-<machine>/`. Nothing is committed: writing the
results up is a separate step.

## Instruction counts on macOS

goose-http's `bench/count.sh` counts a server's user instructions with Linux `perf`, and
macOS has none. `bench/routes.sh` uses its load on macOS instead: the server runs under
`/usr/bin/time -l`, whose "instructions retired" include the kernel's, and the count is
divided by the requests
([goose-http's known issues, macOS](https://github.com/kaitk/goose-http/blob/main/docs/known-issues.md#macos)).
Docker Desktop's VM exposes no hardware counters, so `perf` can't run there either, and
a container gives req/s but no instruction counts. These macOS counts vary by less than
1.5% between rounds.

A full `bench/routes.sh` run takes about 5 minutes. To check a change to goose-rest's
request path quickly, run only its servers, once, at a tenth of the requests, in about
20 s, and then do a full run for the numbers you record:

```sh
SERVERS="gen60 hand60" RUNS=1 N=200000 bench/routes.sh
```

`bench/stack.sh` counts a JSON body and the middleware stack the same way, with wrk
pipelined 16 deep, in about 3 minutes (`RUNS=1 D=3` for a quick check). It needs the
datasets goose-http's `bench/rest.sh build` writes, in the goose-http checkout's
`build/rest` unless `REST_DATA` names another folder.

## Results

`bench/rest.sh run` writes `results/<date>-rest-<machine>/`, so runs from several
machines sit side by side; `MACHINE` names the machine, and defaults to the host name.
`env.txt` records the machine in full, and a comparison uses directories from one
machine only. The files in a directory are goose-http's `bench/rest.sh`'s, with tiers F,
R, and M's cells beside them.

`main` tracks only what the docs cite: notes (`*.md`), tables (`*.tsv`), batch scripts,
`env.txt`, `key.txt`, `binaries.txt`, `revs.txt`, `times.txt`, `instructions.txt`, and
`count.txt`, as goose-http's `main` does. `.gitignore` keeps the per-cell output out.
Commit another file a doc cites with `git add -f`. The raw output travels between
machines on the `bench-raw` branch, which shares no history with `main`. The first push
creates it:

```sh
bench/raw.sh push bench/results/<dir>   # on the benchmark machine
bench/raw.sh pull                       # elsewhere: list the directories
bench/raw.sh pull <dir>                 # extract one into bench/results/
```

Runs before 2026-10-15 wrote into goose-http's `bench/results/`, and the
[benchmark summary](../docs/benchmarks.md) links to them there.
