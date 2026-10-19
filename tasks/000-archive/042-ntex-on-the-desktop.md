# 042: ntex on the benchmark desktop

Status: done

`bench/rest/ntex` (2026-10-16) adds ntex 4.3.0 on its native runtime, held to io_uring on
Linux by the `neon-uring` feature: the first Rust rival on io_uring, beside Axum and
actix-web on epoll. It passes both checkers on macOS and in an arm64 Linux container,
but nothing has measured it, and `docs/benchmarks.md` doesn't list it yet.

On 2026-10-17 the Rust servers moved to one release profile, the strongest of their
TechEmpower entries' (`bench/README.md`, "Servers"): Axum and actix-web gained
`panic = "abort"`, and ntex went from thin to fat LTO. HttpArena's axum, actix, and
ntex entries run default configurations and have nothing faster to take; its dusty
entry is the one `dusty-routes` already follows. The Axum and actix-web numbers in
`docs/benchmarks.md` predate the shared profile, so the same session reruns them.
Pinning every server's workers waits on goose-http's tasks 045 and 046.

## Progress

On 2026-10-18, on the desktop (WSL2, kernel 6.18.54.1-microsoft-standard-WSL2, rustc
1.99.0), with goose-http's checkout at `65288ce1`, whose code is `v0.3.6`'s:

- `OWN=1 bench/rest.sh build` built every server. `rest-ntex` with `WORKERS=4` started
  on tier A with five io_uring descriptors open and answered 200.
- `bench/rest.sh check` passed axum, actix-web, and ntex on tiers A to D, both JSON
  ways, and F, R, and M.
- A build without `Drain` (`.middleware(Drain)` removed from `writes.rs`) passed
  `check.py d` 9 times out of 9, so the forms role can run without it. The build with
  `Drain` passed 9 times out of 9 too. Build the variant into `build/rest/rest-ntex-nodrain`,
  and it runs as the server `ntex-nodrain`.

The runs, on 2026-10-18 and 19, on the desktop (Tiamat: AMD Ryzen 7 5800X3D, WSL2 Ubuntu
26.04.1, kernel 6.18.54.1-microsoft-standard-WSL2, rustc 1.99.0), goose-rest `e478ca2`,
goose-http `edd83c4b` (`v0.3.7`), 4 workers on CPUs 0-3, wrk with 8 threads and 256
connections on CPUs 4-15, 3 runs of 15 s after 5 s of warm-up, each after the machine
was idle (1-minute load at most 0.5, Windows CPU at most 10%):

- The main run, right after `bench/all.sh`'s session `2026-10-18T2118`, with every
  framework: `SERVERS="axum actix-web ntex dusty-routes dusty hyper" EXTRA="axum
  actix-web ntex dusty-routes" RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh
  run`, into `bench/results/2026-10-18T2118-rest-Tiamat-frameworks/`. ntex passed
  every check and reached every fixed rate with zero errors. Medians: A 332 K, B
  173 K, C 33.5 K, C templated 107 K, F `/id` 331 K, F `/json` 263 K, R 306 K, M
  284 K against its tier A's 334 K; uploads alone 1,198/s, beside forms 100-102/s with
  forms at 4.6-4.7 K/s; tier C's reads beside uploads p99 1.83-4.83 ms; peak RSS 42,
  206, 328, 86, and 268 MB on A, C, C templated, uploads, and beside forms. The
  numbers, against every other server, are in `docs/benchmarks.md`.
- Affinity, `AFFINITY=1` then `0`, `TIERS=m STEPS=1`, into `...-affinity1` and
  `...-affinity0`. Pinned against unpinned: A serialized 335.1 K against 333.9 K
  (+0.4%), A templated +1.1%, B serialized -1.1%, B templated -1.4%, C serialized
  -1.2%, C templated -2.0%, and tier M 287.7 K against 283.3 K (+1.6%), with tier A
  beside it level, 334.9 K against 335.0 K. No cell moves by more than 2.0%, and not
  the same way on every tier, so pinning neither helps nor costs ntex here. It keeps
  `enable_affinity()`, as its TechEmpower entry does, and `AFFINITY=0` stays for
  comparing.
- Drain, `SERVERS="ntex ntex-nodrain" EXTRA=ntex TIERS=f STEPS=2`, into `...-drain`.
  Uploads alone 1,218/s with `Drain` and 1,216/s without; beside forms, 102-103
  uploads a second with forms at 4.6-4.7 K/s with it, and 99-100 with forms at 4.6 K/s
  without. `Drain` costs nothing measurable, so it stays.

## Acceptance criteria

- [x] `bench/rest.sh build` builds `rest-ntex` on the desktop, and the server starts on
      io_uring under WSL2: `neon-uring` stops it at startup with "Cannot construct
      io-uring reactor" otherwise.
- [x] `bench/rest.sh check` passes ntex on tiers A to D, both JSON ways, and F, R, and M.
- [x] `SERVERS="axum actix-web ntex" EXTRA="axum actix-web ntex" bench/rest.sh run` at
      the pins' fixed rates (`RATE_A=100000 RATE_B=24000 RATE_C=1700`), with the run's
      machine, kernel, command, worker and connection counts, and run count recorded
      here.
- [x] Settle whether `enable_affinity()`, taken from TechEmpower's entry, belongs beside
      servers that don't pin their workers: run tier A once more with `AFFINITY=0`
      and record both.
- [x] Settle what tier D's `extract::Drain` costs: the forms role with and without it,
      if the checks allow running without it.
- [x] ntex in `docs/benchmarks.md`'s tables and its competitor and "How these are
      measured" lines, in `README.md`'s benchmark table if it belongs there, and in
      `AGENTS.md`'s list of rivals under "Benchmarks", with its losses recorded as
      plainly as its wins.
