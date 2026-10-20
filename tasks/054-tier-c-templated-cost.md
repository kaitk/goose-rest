# 054: tier C templated's cost at v0.2.0

Status: todo (found 2026-10-20)

The nightly sessions measured goose-rest's tier C templated at 148 K req/s on io_uring
and 138 K on epoll on 2026-10-18 (`e478ca2`, goose-http `v0.3.7`, Goose `v2026.2`), and
at 142 K and 132 K on 2026-10-19 (`85f5542`, `v0.2.0`, goose-http `v0.4.0`, Goose master
`f114b5a`), while goose-http alone held 153 K and 144-145 K
([benchmarks](../docs/benchmarks.md#rates)). The compiler isn't the cause: built with
`v2026.2` or `f114b5a`, `e478ca2` ran at 141-146 K in the same short runs (4 workers on
CPUs 0-3, wrk with 8 threads and 256 connections on CPUs 4-15, three 8 s runs after
3 s). Run back to back, three interleaved rounds of 15 s after 5 s, `85f5542` was 2.6%
behind `e478ca2` on io_uring (134.5-136.4 K against 137.5-139.2 K) and 3.2% on epoll
(123.1-128.2 K against 128.3-131.3 K), in every round.

## Where the cycles go

Counted as goose-http's `bench/count.sh` counts: one worker on CPU 0, `TIER=c
JSON=template`, a fixed number of GETs of one route from h2load (8 threads, 256
connections, one request in flight on each) on CPUs 4-15, with tier C's bearer token,
and `perf stat -e instructions:u,cycles:u` on the server's process. Every build used
Goose `f114b5a`. User cycles per request, `e478ca2` → `85f5542`:

| Route | Requests | epoll | io_uring |
|---|---:|---:|---:|
| `/api/v2/schedule/version?since=0` | 400,000 | 9,407 → 10,933 (+16%) | 8,116 → 9,798 (+21%) |
| `/api/v2/clients/7` | 200,000 | 9,720 → 11,398 (+17%) | 8,291 → 9,739 (+17%) |
| `/api/v2/encounters/7` | 200,000 | 16,108 → 17,672 (+10%) | 15,674 → 16,928 (+8%) |
| `/api/v2/clients/7/encounters?limit=20` | 200,000 | 29,345 → 31,490 (+7%) | 30,365 → 31,379 (+3%) |
| `/api/v2/schedule/shifts`, a week of all staff | 40,000 | 15,367 → 17,718 (+15%) | 14,346 → 15,949 (+11%) |
| `/api/v2/schedule/bookings`, a week of all staff | 40,000 | 155,002 → 155,475 (+0.3%) | 154,833 → 156,007 (+0.8%) |

User instructions per request rose by only 349-358 on every route on epoll and by 78-87
on io_uring: about 1,000-2,350 cycles a request more for a few hundred instructions.
A bisect of `main`'s first parents on `/api/v2/clients/7`'s cycles on epoll (bad above
10,550) found two steps:

- **`e2eeb2b`** (collect a `reply_value`'s pieces in the spill): 9,634-9,645 →
  10,857-11,075 cycles, with the instructions unchanged, 23,179.6 → 23,177.6. The
  commit adds functions and code on paths a GET doesn't take. Built with
  `-falign-functions=64 -falign-loops=64` (a `gcc` wrapper given to `goose build
  --cc`), its parent counts 9,946-10,047 and it 9,795-10,162: the gap is where the
  generated C's hot code lands, not work. Goose writes a program as one C file, so code
  added anywhere moves the rest.
- **`7f7dcf3`** (goose-http pin `ff18ecc` → `v0.4.0`): 23,186 → 23,543 instructions and
  10,227 → 11,237 cycles on epoll, 23,485 → 23,571 and 8,838 → 9,748 on io_uring.
  goose-http alone's REST server counts the same instructions more from `v0.3.7` to
  `v0.4.0`, 17,731 → 18,058 on epoll and 18,010 → 18,066 on io_uring, while its cycles
  fell, 7,351 → 7,135 and 6,265 → 5,749. So the instructions are goose-http's loops'
  (goose-http's task 055 covers its `v0.4.0` costs), and the cycles again its layout.

## Ideas

- Make the layout deterministic: align hot code in the C Goose generates, or let a
  build pass C flags, so a change elsewhere doesn't move a request's cost by 15%. Aligned
  builds cost about 3% more cycles here than the luckiest layout, and take away a 13-15%
  lottery. A Goose feature request for `docs/goose-findings.md`, with this measurement.
- Measure the benchmark servers aligned beside the default builds, to see how much of
  the nightly's tier-to-tier movement is layout.
- Find which of goose-http's `v0.4.0` loop changes adds the ~330 instructions per
  request on epoll (TLS in the epoll loop is a candidate), with goose-http's task 055.

## Acceptance criteria

- [ ] goose-rest's tier C templated back within 5% of goose-http alone, or the gap that
      remains recorded with its cause
- [ ] A Goose finding for code layout recorded, with the aligned and default counts
- [ ] The epoll loop's extra instructions at goose-http `v0.4.0` traced to their change
