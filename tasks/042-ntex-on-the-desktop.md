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

The runs that remain, about 1 h 30 min on an idle machine:

```sh
SERVERS="axum actix-web ntex" EXTRA="axum actix-web ntex" \
    RATE_A=100000 RATE_B=24000 RATE_C=1700 bench/rest.sh run
# Affinity, paired so that both runs share a session.
for a in 1 0; do
    AFFINITY=$a SERVERS=ntex EXTRA=ntex TIERS=m STEPS=1 \
        OUT=bench/results/<stamp>-rest-Tiamat-affinity$a bench/rest.sh run
done
# Drain: the forms role beside uploads, with and without it.
SERVERS="ntex ntex-nodrain" EXTRA=ntex TIERS=f STEPS=2 \
    OUT=bench/results/<stamp>-rest-Tiamat-drain bench/rest.sh run
```

## Acceptance criteria

- [x] `bench/rest.sh build` builds `rest-ntex` on the desktop, and the server starts on
      io_uring under WSL2: `neon-uring` stops it at startup with "Cannot construct
      io-uring reactor" otherwise.
- [x] `bench/rest.sh check` passes ntex on tiers A to D, both JSON ways, and F, R, and M.
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
