# 042: ntex on the benchmark desktop

Status: todo

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

## Acceptance criteria

- [ ] `bench/rest.sh build` builds `rest-ntex` on the desktop, and the server starts on
      io_uring under WSL2: `neon-uring` stops it at startup with "Cannot construct
      io-uring reactor" otherwise.
- [ ] `bench/rest.sh check` passes ntex on tiers A to D, both JSON ways, and F, R, and M.
- [ ] `SERVERS="axum actix-web ntex" EXTRA="axum actix-web ntex" bench/rest.sh run` at
      the pins' fixed rates (`RATE_A=100000 RATE_B=24000 RATE_C=1700`), with the run's
      machine, kernel, command, worker and connection counts, and run count recorded
      here.
- [ ] Settle whether `enable_affinity()`, taken from TechEmpower's entry, belongs beside
      servers that don't pin their workers: run tier A once more with `AFFINITY=0`
      and record both.
- [ ] Settle what tier D's `extract::Drain` costs: the forms role with and without it,
      if the checks allow running without it.
- [ ] ntex in `docs/benchmarks.md`'s tables and its competitor and "How these are
      measured" lines, in `README.md`'s benchmark table if it belongs there, and in
      `AGENTS.md`'s list of rivals under "Benchmarks", with its losses recorded as
      plainly as its wins.
