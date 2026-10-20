# 054: tier C templated's cost at v0.2.0

Status: done (found and fixed 2026-10-20)

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

## What moved: the bearer check's byte loops

As goose-http's task 033 found for JSON, the layout matters through one kind of code: a
loop that takes a byte at a time. `perf record -e cycles:u` on `/api/v2/clients/7`, the
epoll loop, one worker, 200,000 requests, with each server built through a `gcc`
wrapper that adds `-g` (the `.text` bytes are the default build's, checked), puts the
top of every build in the bearer check: tier C's tokens are 560 bytes, and each
request scans them twice a byte at a time, in goose-http's `is_token68`, inside
`http::bearer`, and in the benchmark server's `is_base64url`, behind `jwt_shaped`
(`bench/rest/goose-rest/main.goose`), with `http::field_at`'s scan of the header lines
beside them. Share of the samples, each address resolved with `addr2line` to its
outermost function (perf resolves none under WSL):

| Build | `is_base64url` | `http::bearer` (`is_token68`) | `http::field_at` |
|---|---:|---:|---:|
| `09a07a0`, `e2eeb2b`'s parent | 21.2% | 19.9% | 8.9% |
| `e2eeb2b` | 27.1% | 20.3% | 12.5% |
| `96c65eb`, `main` at goose-http `v0.4.1` | 29.4% | 16.0% | 13.9% |

`e2eeb2b` changed no line of them; it moved them.

**Fixed (2026-10-20):** `jwt_shaped` checks the token with std's `find_any`, which the
runtime runs 16 bytes at a time: one scan for a byte that is neither base64url nor
`.`, and three for the dots, against a `ByteSet` built once. Counted as above, on the
default builds, two runs each:

| Route | Loop | `96c65eb`: instructions, cycles per request | With the fix |
|---|---|---:|---:|
| `/api/v2/clients/7` | epoll | 23,543; 10,998-11,218 | 17,440 (-25.9%); 8,454-8,476 (-23.8%) |
| `/api/v2/clients/7` | io_uring | 23,571; 9,645-9,807 | 17,468 (-25.9%); 6,783-6,805 (-30.1%) |
| `/api/v2/schedule/version?since=0` | epoll | 22,253; 11,013 | 16,150 (-27.4%); 7,975 (-27.6%) |
| `/api/v2/schedule/version?since=0` | io_uring | 22,197; 9,583 | 16,094 (-27.5%); 6,543 (-31.7%) |

Every request answered 200 with the same bytes, and goose-http's `check.py` passes
tiers C and D. Tier C templated's load at saturation (4 workers on CPUs 0-3, wrk with 8
threads and 256 connections and `tier-c.lua` on CPUs 4-15, three 8 s runs after 3 s, two
rounds interleaved): io_uring 137.0-140.4 K → 141.8-144.9 K req/s (+4.2% at the
medians), epoll 128.0-129.6 K → 134.1-136.8 K (+4.6%). Beside it in the same way,
goose-http alone ran 147.7-149.0 K on io_uring and 136.9-139.5 K on epoll: goose-rest
is 2.1-2.5% behind, against 7.1-8.4% in the nightly of 2026-10-19.

## For goose-http

- `http::bearer`'s `is_token68` takes a token a byte at a time: 16.0-20.3% of a tier C
  request's cycles on goose-rest. A `find_any` over a token68 `ByteSet`, then the
  trailing `=`s, would do it 16 bytes at a time. goose-http alone's REST server doesn't
  call it, which is most of the 2.1-2.5% that remains.
- goose-http's REST server checks the same JWT shape with its own byte loop
  (`bench/rest/goose/rest.goose`, `is_base64url`). Both Goose servers are to do the same
  work outside the framework (`bench/README.md`), so it needs this fix too before the
  next comparison; until then goose-rest's tier C cells gain from it alone.
- The ~330 more instructions per request on epoll at `v0.4.0`: still to trace in
  goose-http's loops.

## Full-session confirmation

Session `2026-10-20T0854-Tiamat`, goose-rest `62c340d`, goose-http `v0.4.3`
(`0a016bb0`), Goose `f114b5a`, on the same desktop and kernel as above, runs
`bench/all.sh`: four workers on CPUs 0-3, wrk with 8 threads and 256 connections
on CPUs 4-15, three interleaved 15 s runs after 5 s warm-up. Tier C templated
reaches 155.3 K/s on io_uring and 144.3 K/s on epoll, against goose-http alone's
156.3 K/s and 148.1 K/s: gaps of 0.6% and 2.6%. Both exceed the 2026-10-18 rates.
The [summary](../bench/results/2026-10-20T0854-rest-Tiamat/summary.md) and
[notes](../bench/results/2026-10-20T0854-rest-Tiamat/notes.md) retain the method.

goose-http's completed task 056 records both byte-scan fixes and traces epoll's
extra work to h2 state captured by `advance`. `v0.4.3` specializes that turn for
HTTP/1.1 and h2c, keeping the captured h2 state off the HTTP/1.1 path.

## Acceptance criteria

- [x] goose-rest's tier C templated back within 5% of goose-http alone, or the gap that
      remains recorded with its cause: 0.6% and 2.6% in the full session
- [x] ~~A Goose finding for code layout recorded, with the aligned and default counts~~
      Set aside (2026-10-20): the layout moved byte loops, which `find_any` replaces;
      goose-http's task 033 decided against building with alignment flags
- [x] The epoll loop's extra instructions at goose-http `v0.4.0` traced to their change
- [x] goose-http's REST server and `is_token68` scan 16 bytes at a time, recorded there
