# 021: Cut the latency of reads beside uploads

Status: done (asked for 2026-10-15; cause found and fixed on macOS 2026-10-15, checked
on Linux 2026-10-20). Shared its cause with task 020, so it blocked v0.1.0 with it
(2026-10-15).

With uploads running, tier C's reads at a fixed 1,700 a second reach a p99 of 20.4-28.1
ms on goose-rest's io_uring loop against 4.8-7.5 ms on goose-http alone, and 13.8-16.1 ms
on epoll against 0.40-1.35 ms. Alone, the reads' p99 is 0.14-0.96 ms on all four, and
goose-rest serves 11-12% fewer uploads a second
([benchmarks](../docs/benchmarks.md#uploads-and-memory)).

## Acceptance criteria

- [x] The cause is found and measured on Linux: the fix removed the gap there ("On
      Linux" below)
- [x] Fixed in the package, or recorded with the reason it stays: tier D reads its
      bodies with `rest::body_in_pieces` (`9009486`)
- [x] Reads beside uploads and uploads alone rerun against goose-http alone, recorded in
      `docs/benchmarks.md`

## On Linux (2026-10-20)

The nightly session `2026-10-20T0854-Tiamat` (`bench/all.sh`; Ryzen 7 5800X3D, WSL2
kernel `6.18.54.1-microsoft-standard-WSL2`, goose-rest `62c340d`, goose-http `0a016bb0`,
Goose `f114b5a`, 4 workers; `docs/benchmarks.md` has the method), goose-http alone
against goose-rest:

- Reads' p99 beside uploads: 4.66-8.20 against 6.33-8.67 ms on io_uring, and 0.34-1.34
  against 0.40-1.28 ms on epoll, where it was 20.4-28.1 and 13.8-16.1 ms on goose-rest
  before the fix (above).
- Uploads alone: 1,146 against 1,124 a second on io_uring, and 1,162 against 1,141 on
  epoll, where goose-rest served 11-12% fewer before.

## Findings (2026-10-15)

The reads wait behind uploads parsed whole. goose-rest's tier D gathers each CSV and
multipart body (`rest::body(cx, IMPORT_LIMIT)`, 16 MB) and parses it in one handler call
at `END`, which holds the worker for 7.9 ms on average and up to 32 ms. goose-http's
tier D parses the same bodies at each `BODY` event, 8 KB at a time on the epoll loop,
so a read waits at most for one piece. This is the gathering that makes task 020's
upload memory; the fix is the same, tier D on `rest::receive` (task 020, fix 2).

### How this was measured

The machine, builds, and servers of task 020's findings: Apple M1 Pro, macOS 26.3.1,
goose-http's epoll loop on kqueue, 4 workers, `TIER=d`. The reads are tier C's version
poll, 55% of its mix, with `rate.py`'s request head: oha 1.16.0,
`-q 1700 --latency-correction -c 64 -z 15s`. Beside them, wrk 4.2.0 runs `tier-d.lua
uploads`, `-t 1`, from 5 s before the reads to their end. 3 rounds, interleaved, a fresh
server each. One more run, with `runtime.goose` instrumented (not committed), timed the
handler's call in `on_whole` for each gathered body.

### Results

Reads' p99, and uploads a second:

| Load | goose-http | goose-rest |
|---|---:|---:|
| Reads alone | 0.63-0.86 ms | 0.61-6.10 ms |
| Beside 32 upload connections | 15.9-21.8 ms, 913-923 uploads/s | 21.6-23.7 ms, 885-906 uploads/s |
| Beside 4 upload connections | 1.8-7.7 ms, 425-506 uploads/s | 11.7-12.1 ms, 381-414 uploads/s |

- With 32 upload connections, both servers' workers are close to busy on this machine,
  so both servers' reads queue; the macOS figures don't separate the two here as
  Linux's do.
- With 4 upload connections the workers have room. goose-http's reads keep a p99 of
  1.8-2.2 ms in two rounds of three (7.7 in the first), and goose-rest's sit at
  11.7-12.1 ms in every round.
- The instrumented run: with 32 connections, 6,585 bodies gathered whole, 4.3 MiB on
  average, the handler 7.7 ms on average and 31.9 ms at most; with 4 connections, 2,864
  bodies, 4.6 MiB, 7.9 ms and 15.9 ms. goose-rest's p99 with room matches that time.
- goose-rest serves fewer uploads: 2-3% fewer beside the reads with 32 connections,
  5-18% with 4, and 3-16% in task 020's uploads-alone runs. Beside the parse,
  gathering copies each body into the spill, and `realloc_slice` copies most of it once
  more as the run doubles (task 020's simulation: 79-111% of the bytes).

Ruled out as the stall's cause: the handler running twice (the second call is the one
that parses; the first stops at `rest::body` after routing and the bearer check), and
the growth copies, which move at most 4 MB at a time (a body of 2-8 MB doubling to
8 MB), well under the 8-32 ms parse.

### Fix

Tier D on `rest::receive` (task 023, step 9; task 020's fix 2), parsing each piece as it
comes as goose-http's server does. Gathering the body in one exact-size run (task 020's
fix 4) cuts the copies and some of the lost uploads, but not the stall: a route that
parses a whole body in one call holds its worker for the whole parse. That is a mistake a
program can make with `rest::body`, listed with its gotcha note in task 020's findings
("Uploads gathered whole with a raised limit").

On Linux, check that the stall matches the epoll loop's 13.8-16.1 ms p99, and whether
io_uring's larger body pieces change it.

## The fix (2026-10-15)

Tier D's import and attachment routes now read their bodies piece by piece, with
`rest::body_in_pieces` (task 020, "Fix 2"). On macOS, the polls' p99 beside uploads
went from 24.4 to 21.0 ms, against goose-http's 21.7, and the upload rate from 892 to
962 a second, goose-http's. The Linux rerun, the first and third criteria, says whether
the stall is gone there.
