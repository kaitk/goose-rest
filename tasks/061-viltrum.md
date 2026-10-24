# 061: viltrum, the closest rival on HttpArena

Status: todo. Opened 2026-10-24 from the entry's first HttpArena run.

[viltrum](https://github.com/Tuntii/viltrum) is an HTTP framework in V, an
experimental entry on HttpArena like Plod's. It is the rival closest to Plod on every
profile both run, and the one to beat. This task compares the two, records what
viltrum does that Plod doesn't, and adds viltrum to this repository's benchmark.

## The first run

HttpArena benchmarked the entry on 2026-10-23 in
[MDA2AV/HttpArena#1623](https://github.com/MDA2AV/HttpArena/pull/1623) (`/benchmark
--save`, the results only in the bot's comment): Plod `v0.5.4`, goose-http `v0.5.8`, on
HttpArena's 64-thread machine. viltrum's numbers are HttpArena's `main` at
`site/data/results/viltrum.json`, read 2026-10-24, from its entry at `VILTRUM_REF=v1.3.2`.

| Profile, connections | Plod, req/s | viltrum, req/s | Ratio | Plod, memory | viltrum, memory | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| baseline, 4,096 | 4,043,983 | 4,060,832 | 1.00 | 291 MiB | 212 MiB | 1.37 |
| pipelined, 4,096 | 32,962,665 | 32,068,470 | 1.03 | 292 MiB | 211 MiB | 1.38 |
| limited-conn, 4,096 | 2,680,448 | 2,695,785 | 0.99 | 298 MiB | 532 MiB | 0.56 |
| json-comp, 4,096 | 939,101 | 898,733 | 1.04 | 438 MiB | 361 MiB | 1.21 |
| json-comp, 16,384 | 931,867 | 893,109 | 1.04 | 594 MiB | 989 MiB | 0.60 |
| json-tls, 4,096 | 1,813,747 | 1,612,986 | 1.12 | 328 MiB | 718 MiB | 0.46 |
| 8gbit, 512 (at a fixed rate) | 49,290 | 49,126 | 1.00 | 259 MiB | 145 MiB | 1.79 |
| echo-ws, 512 | 4,087,732 | 4,271,287 | 0.96 | 242 MiB | 56 MiB | 4.32 |
| echo-ws, 4,096 | 4,265,867 | 4,396,595 | 0.97 | 284 MiB | 206 MiB | 1.38 |
| echo-ws, 16,384 | 3,980,551 | 4,095,080 | 0.97 | 424 MiB | 716 MiB | 0.59 |
| echo-ws-pipeline, 512 | 61,177,630 | 62,542,913 | 0.98 | 239 MiB | 58 MiB | 4.12 |
| echo-ws-limited, 512 | 2,198,927 | 2,218,758 | 0.99 | 246 MiB | 115 MiB | 2.14 |
| latency-1m, 1,024 (at a fixed rate) | 997,699 | 997,840 | 1.00 | 247 MiB | 80 MiB | 3.09 |
| latency-10k, 1,024 (at a fixed rate) | 9,982 | 9,982 | 1.00 | 245 MiB | 81 MiB | 3.02 |
| latency-500k-8cpu, 1,024 (at a fixed rate) | 498,792 | 498,731 | 1.00 | 47 MiB | 56 MiB | 0.84 |
| async, 32,000 | 1,952,690 | 2,488,770 | 0.78 | 469 MiB | 1.2 GiB | 0.38 |

At the fixed rates, CPU per request is within 4%: 20.4 against 20.2 µs at latency-1m,
44.3 against 50.1 µs at 8gbit. viltrum doesn't run the h2, static, gateway, or database
profiles.

What the table says:

- Throughput is a tie wherever the kernel's networking sets the pace. An io_uring loop
  per worker gains nothing measurable there over viltrum's level-triggered epoll, and
  loses nothing.
- Memory has a floor that doesn't depend on connections. At 1,024 connections or fewer,
  Plod holds 240 to 300 MiB, about 3.7 MiB a worker, and viltrum 56 to 80 MiB. At
  16,384 connections and more viltrum holds more, because it gives every connection an
  8 KiB read buffer and a 16 KiB write buffer and never shrinks them. Plod's
  per-connection cost is the better design; its per-worker cost isn't.
- async is the one profile Plod loses on rate. It is closed-loop: each of 32,000
  connections waits 10 ms per request, so the rate is 32,000 over the time a request
  takes. Plod averaged 16.4 ms and viltrum 12.8 ms, so the score measures how late
  past 10 ms a server answers, not how much work it does. Plod used 35 of 64 CPUs.

## Where a worker's memory goes

Measured 2026-10-24 on the desktop (Ryzen 7 5800X3D, 16 threads, Ubuntu in WSL2,
kernel 6.18.54.1, `CONFIG_HZ=250`), the entry's `server.goose` built with Goose
`v2026.3` and the imports it names, workers pinned with `taskset`, wrk 4.1.0 on the
other CPUs, `VmRSS` and per-mapping `Rss` from `/proc/PID/smaps`. One run each; the
scripts are in "Method", below.

- **Idle, 1.9 MiB a worker**: 5.1 MiB at 1 worker and 32.4 MiB at 16.
  - **The timer table, about 640 KiB.** The entry sets `max_waiting` to `max_conns`,
    16,384, so `/delay` and `/async-db` can wait on every connection, and
    `timer_table` writes each cell's free-list link at startup. Setting
    `max_waiting` to 1,024 took idle RSS at 8 workers from 18.3 to 13.2 MiB.
  - **Tables sized by `max_conns`, about 120 KiB.** With `max_conns` at 1,024 too,
    13.2 became 12.2 MiB.
  - **The io_uring rings, 260 KiB**: 4,096 submission entries and their completions.
- **Under load, another 1.1 MiB a worker**, at 128, 512, and 1,024 connections alike:
  - **The provided buffers, 1 MiB.** The kernel takes the 256 buffers of 4 KiB in ring
    order, and the loop returns each at the tail, so every buffer is written within
    a few hundred receives, whatever the connection count.
  - glibc's thread arena, 170 to 220 KiB.

At 64 workers, those two sums come to about 190 MiB, most of the 240 MiB HttpArena
reported. The rest is the binary, the libraries, main's copy of the dataset, and the
kernel's socket buffers that the container's memory counts.

All four sizes at once (`max_conns` 1,024, `max_waiting` 1,024, `ring_buffers` 64,
`ring_entries` 1,024) idle at 0.72 MiB a worker (4.0 MiB at 1 worker, 14.9 MiB at 16)
and add 0.35 MiB under load: about 70 MiB at 64 workers, viltrum's range. Pipelined
`/pipeline`, 16 deep, 512 connections, 8 workers, three alternating rounds of 6 s:

| Build | req/s | VmRSS after |
|---|---|---:|
| The entry as submitted | 8.07M, 8.10M, 8.10M | 28.4 MiB |
| All four sizes smaller | 8.05M, 8.07M, 8.10M | 13.1 MiB |

That is one machine and one run per cell, enough to show the direction. It isn't a
result for a doc.

The entry can't take these sizes itself: it runs in HttpArena's standard mode, which
holds an entry to its framework's defaults (task 047's echo-ws row), so the changes are
goose-http's defaults and design. Task 047's reasons for the current sizes still hold:
production-stack sizes its waits and boxes from its admissions, and a wait per
connection is what `/delay` needs at 32,000 connections over 64 workers, 500 a worker,
not 16,384.

## Why async answers late

goose-http's loops read `CLOCK_MONOTONIC_COARSE` (`net_clock_ms`, its `shim/net.c`),
which is the time of the last scheduler tick, 1 to 4 ms old, and wait in whole
milliseconds. A timer due in 10 ms can wait for the 10 ms counted from a stale
start, then find on waking that the stale clock says it isn't due yet. On the desktop,
8 workers, wrk on `/delay/10`:

| Connections | p50 | p90 | p99 | Average |
|---:|---:|---:|---:|---:|
| 64 | 12.19 ms | 12.30 ms | 16.24 ms | 12.07 ms |
| 4,000 | 13.20 ms | 17.94 ms | 20.38 ms | 13.88 ms |

At 64 connections, with the CPUs idle, half the answers are 2.2 ms late. viltrum
v1.5.1 ([MDA2AV/HttpArena#1628](https://github.com/MDA2AV/HttpArena/pull/1628), open)
replaces `epoll_wait` with `epoll_pwait2` for a nanosecond timeout, and reports its
lateness falling from 1.0-1.7 ms to 0.3-0.4 ms (Tuntii/viltrum#89). goose-http's
waits don't round up, so it needs only the precise monotonic clock, read once per
pass: with it, goose-http's own server answered `/delay/10` at 64 connections at a
median of 10.2 ms, from 12.2 (goose-http's task 065).
At 10.5 ms per request, async's 32,000 connections would make
about 3.0M req/s, against 1.95M now and viltrum's 2.49M.

## Both on one machine (2026-10-24)

`bench/httparena.sh run` with `RUNS=1` (one 5 s run per cell) at HttpArena's
`d9438f6`: the server on CPUs 0-3 (4 workers), gcannon and zrk on 4-15 with 4
threads, latency-1m offered 200,000 requests a second. Ryzen 7 5800X3D, Ubuntu in
WSL2 (kernel 6.18.54.1), Docker Desktop 29.8.2. viltrum at `v1.3.2`, as HttpArena's
`main` pins it. "After" is the same entry with its root files declaring goose-http at
`dd23d5b2` (task 065's change), run right after. Rates are requests a second, or
messages for echo-ws; memory is the container's.

| Profile, connections | Plod | Plod, after | viltrum |
|---|---|---|---|
| baseline, 4,096 | 553,568, 50 MiB | 570,810, 47 MiB | 465,397, 165 MiB |
| pipelined, 4,096 | 5,441,174, 54 MiB | 5,613,593, 51 MiB | 4,950,608, 165 MiB |
| limited-conn, 4,096 | 312,930, 56 MiB | 311,383, 51 MiB | 296,068, 251 MiB |
| json-comp, 4,096 | 129,216, 65 MiB | 130,873, 62 MiB | 109,261, 240 MiB |
| json-comp, 16,384 | 86,624, 162 MiB | 80,754, 160 MiB | 79,887, 652 MiB |
| json-tls, 4,096 | 197,623, 77 MiB | 198,471, 74 MiB | 58,763, 631 MiB |
| async, 32,000 | 258,583, 191 MiB | 284,882, 171 MiB | 222,446, 1,015 MiB |
| echo-ws, 512 | 625,781, 21 MiB | 624,223, 18 MiB | 531,070, 23 MiB |
| echo-ws, 4,096 | 581,178, 52 MiB | 578,247, 49 MiB | 498,056, 165 MiB |
| echo-ws, 16,384 | 1,824, 132 MiB | 1,643, 129 MiB | 342,019, 652 MiB |
| echo-ws-pipeline, 16,384 | 26,085, 131 MiB | 29,139, 129 MiB | 5,185,142, 652 MiB |
| latency-1m, 1,024 | 11.5 µs a request, 26 MiB | 11.4 µs, 22 MiB | 11.3 µs, 44 MiB |
| 8gbit, 512 | 37.4 µs a request, 29 MiB | 36.4 µs, 26 MiB | 37.4 µs, 92 MiB |

- At 4 workers Plod leads on rate by 1.06 to 1.19 times on the HTTP/1.1 and WebSocket
  profiles and 3.4 times on json-tls, at 0.1 to 0.3 times viltrum's memory. The floor
  that dominates at 64 workers is small at 4.
- async's median fell from 57.2 to 37.1 ms with task 065's change, and its rate rose
  10% on less CPU. Here the 4 CPUs are the limit, not the timers; viltrum's median was
  57.3 ms.
- Memory fell 2 to 5 MiB on every profile, about 0.8 MiB a worker, as task 065
  measured.
- **echo-ws at 16,384 connections fails at 4 workers.** goose-http's gather budget,
  64 MiB a worker, promises each WebSocket 64 KiB, so a worker admits about 1,021, and
  the rest get 503 and reconnect (task 047's echo-ws row). HttpArena's 64 workers
  admit 65,000, so the leaderboard doesn't show it, but the connections a server
  holds at its defaults depend on its worker count. viltrum holds all 16,384.
- json-comp at 16,384 connections reconnects every 25 requests, and both servers
  stall near 80,000 at 200 to 270% of the CPU: the load generator and connection setup
  set the pace there.
- latency-500k-8cpu isn't meaningful on 4 server CPUs, which can't serve 500,000
  requests a second; both servers' p99 passed 7 s.

## What viltrum does

Read from viltrum's source at `v1.5.1` and its entry on HttpArena's `main` (2026-10-24),
not measured here.

- **The loop**: epoll, level-triggered, a thread per CPU of the affinity mask, a
  `SO_REUSEPORT` listener each. A keep-alive request costs one `recv`, one `send`,
  and a share of an `epoll_wait` of up to 512 events; after a short read it skips the
  `recv` that would return `EAGAIN`. It arms `EPOLLOUT` only when a send would block.
- **Pipelining**: every whole request in the read buffer is answered into one write
  buffer, sent with one `send`, until 1 MiB is pending.
- **Memory**: an 8 KiB read and 16 KiB write buffer per connection, allocated at
  accept, kept on a free list after close, doubled as needed, and shrunk only at close
  past 64 KiB and 256 KiB. The fd table, free list, and timer heap stay at their peak.
  The deflater's 464 KiB of tables per worker are allocated but untouched until used.
  V's Boehm collector; the entry builds with `v -prod` and no other flags.
- **Deferred answers**: a binary min-heap per worker of (due, fd, generation); the
  wait's timeout is the earliest due, capped at 1 s, and every due answer goes out in
  one pass. No timer syscalls.
- **Responses**: a Date field formatted once a second, and the head and body copied
  into the write buffer with one capacity check. No `writev`, zero-copy sends,
  `TCP_QUICKACK`, or busy polling; `TCP_NODELAY` only.
- **Profiles**: the HTTP/1.1 ones, json-tls and 8gbit, and the three WebSocket ones.

## What this says about the engine

What the run shows works, and should stay:

- Memory that grows with connections only as they need it. At 16,384 connections and
  more, Plod holds 0.4 to 0.6 times viltrum's memory.
- Throughput per CPU: a tie on every kernel-bound profile, and ahead on json-comp and
  json-tls, where Plod's own code does the work.

What it shows as limits:

- **Per-worker sizes fixed at startup.** Every per-worker table is sized for the
  worst case one worker could meet, and the defaults (`max_conns` 16,384, 256
  provided buffers) assume a few workers. On 64 workers that is 64 worst cases at
  once. Sizes that grow with use, as viltrum's fd table and Plod's connection slots
  do, remove the floor without a setting.
- **Time.** A coarse clock is fine for idle and request deadlines, which tolerate
  4 ms, but not for timers a response waits on. Profiles that measure latency at a
  fixed rate, such as latency-1m and 8gbit's p99.9, may show the same cause; that is
  still to check.

## Plan

1. goose-http: grow the timer table as waits arrive, up to `max_waiting`, rather than
   writing every cell at startup; likewise any table `max_conns` sizes. This removes
   the per-worker cost of `max_waiting` = `max_conns` without changing either limit.
2. goose-http: provided buffers per worker. Measure 64 and 128 against 256 with
   `bench/count.sh` and goose-http's `bench/run.sh` at the largest pipelined cells,
   as its task 016 asks before changing the default. Then measure the ring's
   submission entries the same way.
3. goose-http: timers on the precise monotonic clock. Waits stay in milliseconds,
   since `later` takes milliseconds; viltrum's `epoll_pwait2` fixed a rounding up of
   its waits that goose-http's loops don't have.
4. viltrum in `bench/httparena.sh run`, beside Plod, so the same profiles run on one
   machine, before and after each of the steps above.
5. viltrum in the REST benchmark, as task 048 added Aegon: `bench/rest/viltrum/`
   serving tiers A to D and Plod's F, R, and M through viltrum's router, built as
   its entry is, with a `NOTES.md`. `agents/benchmarks.md` adds it to the rivals.
6. goose-http: the WebSockets a worker admits. A promise of 64 KiB each from a
   64 MiB budget caps a worker at about 1,021, so echo-ws at 16,384 connections
   fails below 17 workers. Decide whether an upgraded connection's promise can be
   smaller, or taken only while a message is gathered, before changing the budget.
7. The ideas left from viltrum's source, each measured before it is taken: skipping
   the read that would return `EAGAIN` (on epoll), one send per pass of pipelined
   answers, and the Date field once a second (goose-http already caches it per
   second; check the cost of the rest of the head).

Step 4 is done: `bench/httparena.sh run` measures Plod's and viltrum's entries by
default, at HttpArena's `d9438f6` (2026-10-24). Steps 1 to 3 are goose-http's task 065:
1 and 3 are built there, and 2 is measured there before its default changes. This
task tracks the order and the entry's results.

Step 5 is built (2026-10-24): `bench/rest/viltrum/`, at viltrum `v1.5.1`, passes both
checkers on tiers A to C, F, R, and M in an arm64 Linux container. Tier D is left out,
as for Aegon: viltrum reads a body whole before a route runs, so it can't refuse a
batch declared over 1 MB until the body arrives (its `NOTES.md`). goose-http's `no_d`
doesn't name viltrum yet, so goose-http's run still measures it on tier D, and that
cell isn't reported. Left: `bench/rest.sh build` and `check` on the desktop, a run, and
a column in the README's table.

## Method

The server is the entry's `server.goose` and `app.goose`, built in WSL with
`goose build --standalone` into a scratch directory. Variants change only
`config()`'s fields there. `taskset -c 0-(N-1)` sets N workers, through goose-http's
worker count from the affinity mask. Idle RSS is `VmRSS` 2 s after start, with no
dataset or database. Under load, it is read after 6 s of
`wrk -t4 -cC -d6s 'http://127.0.0.1:8080/baseline11?a=1&b=2'` on the other CPUs, and
the growth of each mapping is the difference of two `smaps` reads. Pipelined runs use
a wrk script that sends 16 `GET /pipeline` requests per write.

## Acceptance criteria

- [x] goose-http tasks for steps 1 to 3, each linking here (its task 065, 2026-10-24)
- [x] viltrum runs in `bench/httparena.sh run` beside Plod; one session of both, on
      the profiles both subscribe to, recorded here with how it was measured
      (2026-10-24)
- [ ] The WebSocket admission (step 6) decided in goose-http, and echo-ws at 16,384
      connections served at 4 workers, or the limit documented
- [ ] After steps 1 to 3 reach a goose-http release and Plod's: Plod's memory at 1,024
      connections or fewer within viltrum's at HttpArena's 64 threads, async's
      lateness under 1 ms at 64 connections, and no profile's rate lower, measured on
      the same machine
- [x] `bench/rest/viltrum/` serves every tier, passes both checkers, and has a
      `NOTES.md`; `agents/benchmarks.md` and `bench/README.md` list it. Tier D fails
      the declared-length check, as Aegon's does (2026-10-24)
- [ ] The REST tiers measured on the desktop, in `docs/benchmarks.md` and the README
- [ ] Each idea in step 7 taken or recorded as left, with the measurement
