# Benchmark

Build and run Plod's benchmark servers, configure the workloads, and keep their
results. The [benchmark summary](../docs/benchmarks.md) owns the current comparisons and
the tiers. Most of the harness is goose-http's, which this directory wraps:
[its bench/README.md](https://github.com/kaitk/goose-http/blob/main/bench/README.md)
has the toolchain, the method, and how each number is measured.

```sh
bench/rest.sh build    # goose-http's servers and datasets, then this repository's
bench/rest.sh check    # every server on every tier, against both checkers
bench/rest.sh run      # tiers A to D through goose-http's script, then F, R, and M
sudo bench/rest.sh count  # user instructions per request, with perf
bench/all.sh           # both repositories' Goose servers in one unattended session
bench/routes.sh        # instructions per request of the routers, on macOS
bench/stack.sh         # instructions per request of a JSON body and the middleware, on macOS
bench/httparena.sh validate   # HttpArena's validation of Plod's entry, in Docker
bench/httparena.sh run        # HttpArena's harness, with Plod's entry
```

`bench/rest.sh` and `bench/stack.sh` use goose-http's benchmark scripts and datasets.
They clone goose-http at the pin `plod.goose` imports into `build/goose-http-<ref>/` on
first use (`scripts/goose-http.sh`), or use the checkout `GOOSE_HTTP` names.
`bench/all.sh` also tests and benchmarks goose-http itself, so it needs `GOOSE_HTTP`
to name a checkout on its `main` ([below](#an-unattended-session)).

`run` and `count` need Linux: `taskset`, `/proc`, and `perf`. Each script's header lists
its settings. [Known issues](../docs/known-issues.md#benchmarks) lists the traps the
scripts work around.

## Servers

The REST servers live under `rest/`:

- `plod/`: goose-http's REST tier server at goose-http's pin, served through
  Plod: `main.goose` holds its routes, extractors, middleware, error shapes, and
  threads, and imports the rest from goose-http's `bench/rest/goose/app.goose` as
  `http.bench.rest.goose.app`: the records, their loaders and JSON, and tier D's work
  on a body. Both Goose servers do the same work outside the framework, and load, hand
  over, and hold their records the same way, their prebuilt JSON in goose-http's shared
  store. The servers `goose-uring-plod` and `goose-epoll-plod` run it as
  `rest-goose-plod`, by goose-http's `bench/rest.sh`'s naming.
- `axum/`, `actix-web/`, and `ntex/`, with `rust-app/` holding the records and JSON they
  share. Axum and actix-web run on epoll through Tokio; ntex runs on its own runtime,
  on io_uring on Linux.
- `dusty/`: dusty with a route per path.
- `aegon/`: Aegon (C++), a CMake project that fetches Aegon and glaze at their pins,
  built twice: `rest-aegon` with HttpArena's entry's buffers, and `rest-aegon-small`
  with the entry's buffers for a low memlock limit. Linux only; its `NOTES.md` lists
  what the build needs.
- `tiers/`: Plod's own tiers F, R, and M, with their checker, loads, and summary.

Each framework serves through its own router, extractors or body readers, and JSON,
built in release mode in its fastest documented configuration; each entry's `NOTES.md`
records its configuration. Where one rival's configuration has a setting the others
take as readily, all of them use it: the Rust servers share one release profile, the
strongest of their TechEmpower entries' (`opt-level = 3`, `codegen-units = 1`, fat LTO,
`panic = "abort"`), with `-C target-cpu=native`. ntex pins each worker to a CPU, as its
entry does, and `AFFINITY=0` unpins them; the other servers don't pin theirs. `bench/rest.sh` wraps goose-http's `bench/rest.sh`, from that
checkout.

`rest/plod/github_gen.goose` is generated from `github.json`, which
`rest/tiers/github_goose.py` writes with `github_app.goose` from `github.txt`.
`scripts/test.sh` checks it as a golden file.

`check` runs on macOS too, after `OWN=1 bench/rest.sh build`, which skips goose-http's
build, given goose-http's datasets in its `build/rest` (`goose build` and run its
`bench/rest/gen.goose` into it). dusty needs Zig 0.16.0 there, which Homebrew doesn't
install. Both Goose servers call glibc's `mallopt`, so they build only on Linux: on a
Mac, in an arm64 Linux container
([known issues](../docs/known-issues.md#the-rest-benchmark-on-macos)).

## The HttpArena entry

`bench/httparena/plod/` is Plod's entry in [HttpArena](https://github.com/MDA2AV/HttpArena),
as it's submitted: its `README.md` says how it serves each profile and why each setting
is what it is. It holds `meta.json`, which lists the profiles it subscribes to, a
Dockerfile, which downloads Goose's release, and the server, `app.goose`'s routes under
two root files, `server.goose` without TLS and `server_tls.goose` with it. The root
files import Plod at its latest release, as an application would, so a change to the
package reaches the entry with the next release. The gateway profiles start the server
from compose files instead, `compose.gateway.yml`, `compose.gateway-h3.yml`, and
`compose.production-stack.yml`, behind stock nginx or Caddy, each built from its
directory: `proxy/`, `proxy-h3/`, and `proxy-production/`. The server takes the proxy's
requests on `PROXY_PORT` as well as 8080, and keeps production-stack's cache in
process, in lanes of its own. `bench/httparena.sh` copies the entry into an HttpArena
checkout at a pinned commit and runs HttpArena's own `validate.sh` or `benchmark.sh`;
its header lists what it changes in the checkout and its settings.
It follows goose-http's `bench/httparena.sh`, whose
[README](https://github.com/kaitk/goose-http/blob/main/bench/README.md#httparena-under-docker-on-macos)
says how to run the harness from a Mac. The server builds on macOS as well, where it
serves the routes with a dataset that `DATASET` names, but the static files only from
`/data/static`:

```sh
goose build -o build/arena bench/httparena/plod/server.goose
DATASET=path/to/HttpArena/data/dataset.json build/arena
```

## An unattended session

`bench/all.sh` is the nightly session: it measures goose-http's and this repository's
Goose servers, unattended, without the frameworks, whose cells come from earlier runs.
With goose-http's checkout beside this one, it needs no setting:

```sh
bench/all.sh                       # or GOOSE_HTTP=<checkout> bench/all.sh
DRY=1 bench/all.sh                 # the preparation and the steps, without running them
```

It prepares first: the tools, both checkouts fast-forwarded to `origin/main` where they
are clean and behind it (`PULL=0` leaves them), the pinned Goose compiler, and up to
`IDLE_WAIT` minutes (15) for an idle machine, a 1-minute load average of at most
`IDLE_LOAD` (0.5) in two checks 30 s apart, and on WSL a Windows CPU load of at most
`IDLE_CPU` percent (10). Then it runs both repositories' `scripts/test.sh` (`TESTS=0`
skips them), the Goose builds with `ONLY=goose`, `bench/rest.sh check`, goose-http's
`bench/run.sh` and `bench/files.sh`, `bench/rest.sh run`, and, as root, goose-http's
`bench/instructions.sh` and `bench/rest.sh count`. It took about 2 h 40 min on the
desktop (2026-10-19).

It stops only when nothing can be measured: a tool missing, or no compiler. Anything
else is a warning it records and goes on past: a checkout with local changes or off
`origin/main`, goose-http's code apart from the tag `plod.goose` pins, a machine that
won't go idle, failing tests, or no root or `perf` for the counts. A step that fails is
recorded, and the steps after it run unless they need its output. The terminal gets a
line when each step starts, with the last session's time for it, and when it ends, a
line every `HEARTBEAT` seconds (600) while it runs, naming the REST run's cell, and each
warning; the commands' output goes to the session's log.

Tiers A to C run at the fixed rates `RATE_A`, `RATE_B`, and `RATE_C` (100,000, 24,000,
and 1,700, the full run of 2026-10-13's), so that their cells compare with earlier
runs. Under one time stamp, goose-http's own runs go to its `bench/results/`, with the
session's instruction counts, environment, and step times; the REST run and its counts
to this repository's ([Results](#results)); and the session's progress, warnings,
log, and environment to `build/bench-all/<stamp>-<machine>/`. There, `manifest.txt`
says how each step ended, lists the warnings, and names each result's directory, and
`build/bench-all/latest` names the newest session. Nothing is committed: writing the
results up is a separate step, which starts from the manifest.

## Instruction counts on macOS

goose-http's `bench/count.sh` counts a server's user instructions with Linux `perf`, and
that tool isn't available on macOS. `bench/routes.sh` uses its load on macOS instead: the server runs under
`/usr/bin/time -l`, whose "instructions retired" include the kernel's, and the count is
divided by the requests
([goose-http's known issues, macOS](https://github.com/kaitk/goose-http/blob/main/docs/known-issues.md#macos)).
Docker Desktop's VM exposes no hardware counters, so `perf` can't run there either, and
a container gives req/s but no instruction counts. These macOS counts vary by less than
1.5% between rounds.

A full `bench/routes.sh` run takes about 5 minutes. To check a change to Plod's
request path quickly, run only its servers, once, at a tenth of the requests, in about
20 s, and then do a full run for the numbers you record:

```sh
SERVERS="gen60 hand60" RUNS=1 N=200000 bench/routes.sh
```

`bench/stack.sh` counts a JSON body, the middleware stack, and a 404 error the same way, with wrk
pipelined 16 deep, in about 3 minutes (`RUNS=1 D=3` for a quick check). It needs the
datasets goose-http's `bench/rest.sh build` writes, in the goose-http checkout's
`build/rest` unless `REST_DATA` names another folder.

The current server fails to link on macOS because it calls glibc's `mallopt` during
startup. `bench/stack.sh` therefore stops before taking counts
([known issue](../docs/known-issues.md#the-rest-benchmark-on-macos)).

## Results

`bench/rest.sh run` writes `results/<date>-rest-<machine>/`, so runs from several
machines sit side by side; `MACHINE` names the machine, and defaults to the host name.
`env.txt` records the machine in full, and a comparison uses directories from one
machine only. The files in a directory are goose-http's `bench/rest.sh`'s, with tiers F,
R, and M's cells beside them.

`main` tracks only what the docs cite: notes (`*.md`), tables (`*.tsv`), batch scripts,
`env.txt`, `key.txt`, `binaries.txt`, `revs.txt`, `times.txt`, `instructions.txt`, and
`count.txt`, as goose-http's `main` does. `.gitignore` keeps the per-cell output out.
Commit another file a doc cites with `git add -f`. The raw output stays on the machine
that ran the benchmark; the numbers and how they were measured go in
[docs/benchmarks.md](../docs/benchmarks.md).

Runs before 2026-10-15 wrote into goose-http's `bench/results/`, and the
[benchmark summary](../docs/benchmarks.md) links to them there.
