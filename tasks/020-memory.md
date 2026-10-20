# 020: Find where goose-rest's memory goes

Status: done (asked for 2026-10-15; diagnosed on macOS 2026-10-15, fixes 1 to 3
done 2026-10-15, rerun on Linux 2026-10-20). Blocked v0.1.0 (2026-10-15).

At saturation on io_uring, goose-rest holds 2.0-6.7 times goose-http's peak RSS: 33 MB
against 12 on tier A, 96 against 30 on B, 140 against 71 on C, and 387 against 58 on C
with templates. Uploads alone: 385-422 MB against 69-70
([benchmarks](../docs/benchmarks.md#uploads-and-memory)). Candidates to check: bodies
gathered whole up to a route's limit, per-request state and scratch kept per
connection, and the tier server's own records.

## Acceptance criteria

- [x] Each tier's extra memory is attributed to its source, measured on Linux: on
      Linux none is left to attribute ("On Linux" below)
- [x] What belongs to the framework is cut or recorded with the reason it stays
- [x] Peak RSS rerun on Linux against goose-http alone, recorded in
      `docs/benchmarks.md`

## On Linux (2026-10-20)

The nightly session `2026-10-20T0854-Tiamat` (`bench/all.sh`; Ryzen 7 5800X3D, WSL2
kernel `6.18.54.1-microsoft-standard-WSL2`, goose-rest `62c340d`, goose-http `0a016bb0`,
Goose `f114b5a`, 4 workers; `docs/benchmarks.md` has the method) measured peak RSS at
saturation, goose-http alone against goose-rest. On io_uring: tier A 13 against 13 MB,
B 30 against 31, C 71 against 71, C templated 58 against 58, and uploads alone 71
against 71. On epoll: A 8 against 8, C 69 against 69, and uploads alone 69 against 70.
The framework's share stays under 1 MB, as fixes 1 to 3 left it, so there is no
extra memory to attribute. Uploads beside forms on epoll is the exception, 149 MB
against 132; `docs/benchmarks.md` records that workload's loss, and this task didn't
cover it.

## Findings (2026-10-15)

On tiers A to C, all of goose-rest's extra memory is the tier server's data, not the
framework: goose-rest's tier server is a port of goose-http's at `e27ab21`, from before
goose-http's task 025 cut that server's memory, and it still loads, copies, and lays out
its records the old way. The framework adds under 1 MB at saturation there. On uploads,
about 70 MB is the same data and about 240 MB is the framework's body gathering: each
worker's spill grows to the sum of the bodies it gathers at once and keeps that size.
The same gathering causes task 021's slow reads.

### How this was measured

- Machine: Apple M1 Pro, 10 cores, 32 GB, macOS 26.3.1 (Darwin 25.3.0). This is
  goose-http's epoll loop on kqueue (`LOOP=epoll`), not io_uring or Linux epoll.
- Servers: goose-rest's `bench/rest/goose-rest/main.goose` at `f549591`, and goose-http's
  `bench/rest/goose/rest.goose` at `v0.3.2` with its `mallopt` call removed, which is
  glibc's and doesn't link on macOS. Both built with the pinned Goose `v2026.1`,
  `goose build --standalone`, Apple clang 21.0.0. Datasets from goose-http's
  `bench/rest/gen.goose`.
- Each cell: a fresh server, `WORKERS=4`, under `/usr/bin/time -l`, whose "maximum
  resident set size" is the peak. Idle RSS is `ps -o rss` 3 s after the server listens,
  and end RSS the same just before it stops.
- Tiers A to C: wrk 4.2.0, `-t 4 -c 256`, goose-http's `tier-*.lua`, 5 s warm-up then
  15 s. Uploads: `-t 1 -c 32`, `tier-d.lua uploads`, `TIER=d`, the same times. 3 rounds,
  interleaved; tables show medians and the rounds' range. Without CPU pinning, every
  tier ran at about 34,000 req/s on A and B and 14,500 on C, on both servers: the
  client's limit here, not saturation.
- Per-worker costs: idle RSS with 1, 2, and 4 workers, one run each; a worker's cost is
  half the difference between 4 and 2 workers.

### Peak RSS per workload

MiB, medians of 3 rounds (range in brackets where it exceeds 1 MiB):

| Workload | goose-http idle | peak | goose-rest idle | peak | Extra peak | Extra at idle |
|---|---:|---:|---:|---:|---:|---:|
| Tier A | 6.9 | 8.1 [6.8-8.2] | 25.7 | 26.1 | 18.0 | 18.8 |
| Tier A, templates | 4.3 | 7.4 | 42.1 | 42.5 | 35.1 | 37.8 |
| Tier B | 23.6 | 30.3 | 86.1 | 86.8 | 56.5 | 62.5 |
| Tier B, templates | 42.1 | 49.7 | 212.3 | 213.0 | 163.3 | 170.2 |
| Tier C | 53.5 | 71.6 | 122.5 | 139.2 | 67.6 | 69.0 |
| Tier C, templates | 29.1 | 57.1 | 370.0 | 387.3 | 330.2 | 340.9 |
| Uploads alone | 53.2 | 71.3 [69.8-71.5] | 122.5 | 364.2 [362.3-373.5] | 292.9 | 69.3 |

These are close to the published Linux io_uring figures (goose-rest 33, 96, 140, 387,
and 385-422 MB), so the causes below are unlikely to be macOS's.

- goose-http's peak sits 1-28 MiB above its idle RSS, partly set at startup while its
  distributor thread hands each worker its records. goose-rest's peak equals its RSS at
  the end of the load.
- Under load, RSS grows by the same amount on both servers on tiers A to C: 0.3-0.7 MiB
  on A and B, and 17-19 MiB on C (response buffers). On uploads, goose-http grows by
  1.6 MiB and goose-rest by 240-251 MiB.

### Tiers A to C: the tier server's data

Idle, before any request, goose-rest already holds the whole difference. Each worker
costs, in MiB:

| Tier | goose-http per worker | goose-rest per worker | goose-http's server at `e27ab21`, Linux (its task 025) |
|---|---:|---:|---:|
| A | 0.45 | 4.48 | 4.3 |
| A, templates | 0.23 | 7.76 | 7.7 |
| B | 4.1 | 14.6 | |
| B, templates | 5.0 | 39.8 | |
| C | 10.0 | 21.8 | 21 |
| C, templates | 2.9 | 71.2 | 71 |

goose-rest's per-worker costs and 4-worker idle RSS (25.7, 42.1, 86.1, 212.3, 122.5,
370.0) match goose-http's server before its task 025 (26.9, 43.8, 88.5, 217.7, 125.9,
379.0 MB idle on Linux). goose-rest's server came from `e27ab21` ("the same routes,
records, and JSON as goose-http's bench/rest/goose at e27ab21", its header) and didn't
take goose-http's later commits `c9d9d9f` to `9b7786a`. goose-http's task 025 measured
each of those steps on Linux; together they account for the whole gap:

1. Records loaded in `main` and copied into each worker by `thread_spawn`. A worker
   keeps two copies, the spawn packet and its data stacks, and `main` keeps its own and
   the spawn image (goose-http's
   [finding](https://github.com/kaitk/goose-http/blob/main/docs/goose-findings.md#a-worker-holds-its-globals-twice-and-its-spawner-keeps-a-third-copy)).
   goose-http loads on a thread that exits and hands each worker one set over queues.
2. Strings in fixed-capacity fields (`name: u8[..48]`, `tags: u8[..24][..4]`), each the
   full capacity. goose-http keeps them in one pool, as ranges.
3. Templates (prebuilt JSON) per worker, and tier C's note text in both the visits' and
   the notes' JSON. goose-http keeps the templates once per process in `http::store`.

Ruled out for tiers A to C, as the framework's share at saturation is under 1 MiB:

- The worker's spill: no route on A to C gathers a body; every body fits the head's read.
- `Slot<S>` per connection: `Heavy` and `Snow` are one `bool`, and `Gather` is 48 bytes,
  about 14 KB for 256 connections.
- The per-event `Cx` (native stack), the per-event `scratch`, and the answer buffers
  built then copied into `out`: goose-http's server builds each answer in a local buffer
  the same way, and both servers grow by the same 17-19 MiB on tier C.

### Uploads: the spill

Every upload goose-rest's tier D takes is gathered whole: `import_csv` and `attach` call
`rest::body(cx, IMPORT_LIMIT)`, 16 MB, and parse the body at `END`. goose-http's server
parses the same CSV and multipart bodies piece by piece at each `BODY` event, 8 KB at a
time on the epoll loop, and holds no body.

The gathered bodies live in each worker's `spill`, a `reusable[]` array. The pinned
release's spec (§5.4) and two checks under `build/` (not committed) show how it grows:

- A `reusable[]` pool only grows. A freed run goes to its freelist and is reused first
  fit, so the pool doesn't leak, but its length is its high-water mark.
- A data stack keeps its pages for its thread's life (§1.2, and goose-http's finding
  above). On `v2026.1`, 200 MB grown in a scope that ended was still resident 2 s
  later. So the spill's high-water mark stays in RSS.
- `gather_piece` doubles a run from 16 KB through `realloc_slice`. With several bodies
  growing at once, a run rarely ends the array, so most growths copy the run elsewhere.
  A simulation of `gather_piece` over tier D's upload sizes, 8 KB pieces taken round
  robin, gave a spill high-water mark of 39 MiB for 4 bodies at once, 68 MiB for 8,
  and 108 MiB for 16: the runs' capacities at once plus about 13%. It copied 79-111%
  of the bodies' bytes a second time.

With `runtime.goose` instrumented to print the spill's length at each growth (not
committed), the last growth reached 58 MiB under the 32 upload connections, about 8 a
worker, near the simulation's 68 MiB for 8 bodies at once. Four workers at about that size account for the
240-251 MiB the uploads add. The remaining 69 MiB of the
uploads' extra is tier C's records, as on tier C (`TIER=d` loads them).

### Recommended fixes, by what v0.1.0 needs

Must land before v0.1.0, because the published table charges the framework for its
benchmark program:

1. **Port goose-http's task 025 to goose-rest's tier server**: the loader thread and
   queue hand-off, the string pool, notes held once, and templates in `http::store`.
   Expected: tiers A to C and uploads' idle share at goose-http's figures, 18-341 MiB
   less. Touches only `bench/rest/goose-rest/main.goose`, so it doesn't conflict with
   task 023.
2. **Tier D on `rest::body_in_pieces`** (named `rest::receive` when this was written),
   step 9 of task 023, made required rather than
   optional: parse the CSV and the multipart body piece by piece, as goose-http's
   server does. Expected: the 240-251 MiB of spill gone, and task 021's stall with it.
   Touches `bench/` after task 023 lands.
3. **Gotcha notes** for each mistake below, and the rerun on Linux into
   `docs/benchmarks.md` (the third criterion).

Can be recorded and left after v0.1.0:

4. **Gather a body with a `Content-Length` in one run of its exact size**, at the first
   piece, rather than doubling from 16 KB: no growth copies, and no power-of-two slack.
   Chunked bodies still double. Touches `gather_head` and `gather_piece` in
   `runtime.goose`, which task 023 is rewriting: do it after task 023. Task 028.
5. **A per-worker budget for gathered bytes**, beyond which a route gets 503 or the
   worker stops reading the connection, so the spill's high-water mark has a bound
   whatever the clients send. Touches `on_event` in `runtime.goose`, after task 023;
   stopping a connection's reads may need goose-http. Task 029.
6. **A goose-rest way to share read-only data across workers**, over goose-http's
   `http::store`, for programs that keep a cache built at startup. Task 027.

The framework's own cost on tiers A to C, under 1 MiB, stays: it is the per-connection
`Gather` and the per-event context.

### Mistakes in the program, and how goose-rest can prevent them

Each is in `bench/rest/goose-rest/main.goose`, and a user's program can make it the
same way. Options in order of preference: (1) the framework fixes it, (2) the API makes
the right way the easy one, (3) a gotcha note where a reader would make it.

**Records loaded in `main` into globals that every worker uses.** `main` loads every
record into globals and then spawns the workers. Goose shares only static data between
threads (spec §11.2), so `thread_spawn` copies each global a worker names; the worker
keeps the spawn packet and its own copy, `main` keeps the original and the spawn image,
and no data stack returns its pages. With 4 workers that is about 10 copies; tier C
templated pays 71 MiB a worker. A user's program does the same with any cache or lookup
table loaded at startup: tutorial page 1 ("Workers and `main`") spawns the workers from
`main`, and page 8 ("Per worker") keeps data in the worker. Prevention: (1) isn't
possible in goose-rest, as the copies are Goose's (`thread_spawn`); (2) a goose-rest
helper over `http::store` for read-only data built at startup, one copy per process
(fix 6); (3) a note in tutorial page 8, "Per worker", and page 1, "Workers and `main`":
data loaded before the spawn is copied into every worker and kept twice; load it on a
thread that hands it over, or put read-only data in `http::store`.

**Strings in fixed-capacity fields in records kept in memory.** The records hold
`u8[..48]` and similar fields, and a limited array always takes its full capacity, so a
record with a 6-byte name holds 48 bytes for it. A user's program does it by hand, or
by caching generated types: the generator writes `maxLength: n` as `u8[..4n]`
([generator](../docs/generator.md), its types table), so a field of `maxLength: 200`
takes 800 bytes in every cached record. Prevention: (1) and (2) don't fit, since a
limited array is the right type for a request's body; (3) a note beside the
`maxLength` row in `docs/generator.md` and in tutorial page 8, "Per worker": to keep many
records, store strings as ranges into one byte array.

**Prebuilt JSON per worker.** Template mode builds each record's JSON once per worker,
the same mistake as the records, and on tier C it holds each note's text twice.
Prevention as for the records: (2) fix 6, and (3) the same note in page 8.

**Uploads gathered whole with a raised limit.** `import_csv` and `attach` call
`rest::body(cx, 16 MB)` and parse the body when it's whole. The spill of each worker
grows to the bodies it gathers at once, and keeps that size for the worker's life; the
route then parses up to 16 MB in one call, and the worker answers nothing else
meanwhile (task 021). The tier server's own comment says these bodies "are read in
pieces as they arrive", which they aren't. A user's upload route does the same by
following tutorial page 10, "Gathered whole, up to a limit". Prevention: (1) fixes 4
and 5 cut the copies and bound the memory, but the stall stays while the body is parsed
in one call; (2) `rest::receive` (task 023), named in `rest::body`'s row of the
reference ("Extractors") as the way to read a body larger than about 1 MB; (3) tutorial
page 10, "Three limits", already says the limit is memory per connection: add that the
worker keeps that memory after the request, and that it answers no other request while
the route reads the whole body.

### Not measured here, for the Linux rerun

- Linux, both loops: the published numbers are from io_uring and epoll on the Linux
  desktop. Docker on this machine would need a Goose built from a commit for arm64
  Linux, which has no release archive, and runs io_uring only emulated, so it was left
  for the benchmark desktop. Rerun `bench/rest.sh run` steps 1 and 2 there, and for the
  split, `idle` RSS with 1, 2, and 4 workers as above.
- On io_uring, check that body pieces are larger than the epoll loop's 8 KB (provided
  buffers): fewer, larger pieces change the doubling's copies but not the high-water mark.
- After fixes 1 and 2, goose-rest's peak on every workload should sit within a few MiB
  of goose-http's; anything left is the framework's, to cut or record.

## Fix 1 (2026-10-15)

goose-rest's tier server, `bench/rest/goose-rest/main.goose`, now loads and holds its
data as goose-http's server at `v0.3.2` does, after goose-http's task 025. Its routes,
extractors, middleware, and answers are unchanged. On tiers A to C, its idle and peak
RSS now match goose-http's within 2 MiB. Before the change, the peak was 19-331 MiB
over.

### What changed

The changes are goose-http's commits `c9d9d9f` to `9b7786a`, applied to goose-rest's
copy of the same code:

- A `loader` thread reads the files, builds the records, and returns, which unmaps its
  stacks. A `distributor` thread hands each worker one set of the records over the
  typed queues, and each worker takes it into its globals (`take_set`). `main`'s record
  globals stay empty, so `thread_spawn` copies none of them. Tiers F and R hand over
  the empty set.
- Strings live in one pool, `text`, as `Str` ranges, and a value many records share
  is a `u8` index into `words`, instead of fixed-capacity fields.
- Tier C's visit templates take their notes' text from the notes' JSON, so each note's
  text is held once.
- The prebuilt JSON goes in goose-http's shared store (`import http.store`), one copy
  per process, and template routes copy from it with `http::store_append`. In
  template mode, tiers A and C drop the records and strings that only the JSON needed.

goose-http's server also has `json_string`, which scans a string for bytes to escape 16
at a time (its task 033). It came with the port and changes no answer. It isn't a
memory change. On these runs it shows no rate change, because the client limits the
rate here.

Not ported: goose-http's `main` calls glibc's `mallopt` to fix the mmap threshold,
which keeps glibc from holding one extra set of records in an arena after the hand-off
on Linux. macOS has no `mallopt`, so the call wouldn't link, and Goose can't build a
call for one platform only. goose-http's server didn't link on macOS either. The Linux
rerun shows what this costs. goose-http measured about one set of a worker's records
(task 025, before the shared store: 17 MB on tier C templated). The templates no
longer travel on the queues, so the cost is now the records alone.

The server's comment on tier D said its CSV and multipart bodies "are read in pieces
as they arrive". The comment now says what the server does: `rest::body` gathers every
body whole, and the piece readers get it as one piece. Reading in pieces is fix 2.

### Answers

- goose-http's `bench/rest/check.py` passes tiers A to C, both JSON ways, and tier D,
  and `bench/rest/tiers/check.py` passes tiers F, R, and M. Each ran on a fresh
  server, `LOOP=epoll`, 4 workers.
- Byte for byte, against the server before the change (a script, not committed, with
  `servedAt` masked): every item and user and their 404s on tier A (11,005 requests);
  each of the 200 users' session, timer, entries, projects, and a PATCH on tier B
  (1,401); every week's and the month's bookings and shifts, every encounter, every
  client and its history, and their 404s on tier C (4,548). Both JSON ways, no
  difference.

### How this was measured

As in [How this was measured](#how-this-was-measured) above: Apple M1 Pro, 10 cores,
32 GB, macOS 26.3.1 (Darwin 25.3.0), goose-http's epoll loop on kqueue
(`LOOP=epoll`), not Linux. Pinned Goose `v2026.1`, `goose build --standalone`, Apple
clang 21.0.0. Datasets from goose-http's `bench/rest/gen.goose`.

- Servers: goose-rest's server before (`f549591`) and after this change, and
  goose-http's `bench/rest/goose/rest.goose` at `v0.3.2` with its `mallopt` call
  removed.
- Each cell: a fresh server, `WORKERS=4`, under `/usr/bin/time -l`, whose "maximum
  resident set size" is the peak. Idle RSS is `ps -o rss` 3 s after the server listens.
- wrk 4.2.0, `-t 4 -c 256`, goose-http's `tier-a.lua`, `tier-b.lua`, and `tier-c.lua`,
  5 s warm-up then 15 s. 3 rounds, interleaved by round, then workload, then server.
  The tables show medians, with the rounds' range in brackets where it exceeds 1 MiB.
- The machine wasn't kept idle: other work ran beside it, with a 1-minute load average
  near 5 at the start. Requests/s here are the client's limit on this machine, not
  saturation, as in the findings. They show only that the change costs no rate.

### Results

RSS in MiB:

| Workload | goose-http idle | peak | goose-rest before, idle | peak | after, idle | peak |
|---|---:|---:|---:|---:|---:|---:|
| Tier A | 5.7 | 6.8 | 25.6 | 26.0 | 6.6 | 7.6 |
| Tier A, templates | 4.3 | 7.3 | 42.1 | 42.5 | 4.4 | 7.3 |
| Tier B | 23.6 | 30.3 | 86.1 | 86.8 | 23.0 | 29.6 |
| Tier B, templates | 41.3 | 49.5 | 212.3 [206.4-212.3] | 212.9 | 42.0 | 49.6 |
| Tier C | 51.8 [51.7-53.5] | 69.8 [69.8-71.6] | 122.4 | 140.1 | 53.4 | 71.4 |
| Tier C, templates | 28.9 [28.5-30.5] | 57.1 | 370.0 | 388.0 [387.6-389.2] | 30.9 [29.7-31.0] | 57.1 |

Requests/s, medians and the rounds' range:

| Workload | goose-http | goose-rest before | after |
|---|---:|---:|---:|
| Tier A | 33.8K (33.5-34.5K) | 33.9K (33.8-34.3K) | 34.5K (33.9-34.7K) |
| Tier A, templates | 33.6K (33.0-34.5K) | 34.3K (34.1-34.5K) | 34.2K (32.4-34.6K) |
| Tier B | 33.1K (32.5-34.0K) | 33.7K (32.3-33.8K) | 33.8K (33.4-33.9K) |
| Tier B, templates | 33.6K (33.3-33.8K) | 33.8K (32.4-33.9K) | 33.5K (33.5-34.1K) |
| Tier C | 14.6K (14.4-14.7K) | 14.3K (14.1-14.5K) | 14.6K (14.3-14.7K) |
| Tier C, templates | 14.6K (14.2-14.7K) | 14.6K (13.9-14.7K) | 14.4K (14.3-14.7K) |

Every range after the change overlaps the range before it.

### What's left of the gap

On tiers A to C, goose-rest's server now sits within 2 MiB of goose-http's, idle and
at peak: -0.6 to +2.0 MiB idle, and -0.7 to +1.6 MiB at peak. That matches what the
findings put down to the framework, under 1 MiB at saturation: each connection's
`Gather` and slot, the per-event context, and goose-rest's larger binary. Tier C shows
the largest differences, 1.6 MiB serialized and 2.0 MiB templated at idle. The rounds'
spread there is up to 2 MiB, so this run can't separate them from noise. The Linux
rerun settles it, with 1, 2, and 4 workers.

Not done here: uploads (tier D), whose roughly 240 MiB of spill is fix 2, and the Linux
rerun.

## Fix 2 (2026-10-15)

Tier D's import and attachment routes in `bench/rest/goose-rest/main.goose` now read
their bodies with `rest::body_in_pieces`. Each piece goes to the same CSV and multipart
readers as before, which goose-http's server also uses, and the route answers at the
`END`. A malformed multipart body is answered at its `END`, as goose-http's server
answers it. The batch and the form routes, of at most 1 MB and 64 KB, still gather
their bodies with `rest::body`, as goose-http's server gathers them.

What a body's reading keeps between pieces is a `Spool` in the worker's pool, as in
goose-http's server, and its index in the per-request state (`Heavy.spool`). In the
state itself, the spool's 8 KB of text fields and the `http::Multipart` would make
every connection's slot about 10 KB larger, whatever its route. The spool is released at
the `END`, or at `CLOSED` when the client goes, a chunked body passes its limit, or the
route fails before the `END`.

### Answers

goose-http's `bench/rest/check.py` passes tiers A to D on the new server, `LOOP=epoll`,
4 workers. On tier D, it covers each import and attachment sent whole, in 64 KB chunks,
and in small chunks; malformed CSV and multipart bodies; a missing file; 415; and 413
for a `Content-Length` and for a chunked body past the limit, followed by an import
that still succeeds. `bench/rest/tiers/check.py` passes tier M.

### How this was measured

As in [Fix 1](#fix-1-2026-10-15): Apple M1 Pro, 10 cores, 32 GB, macOS 26.3.1 (Darwin
25.3.0), goose-http's epoll loop on kqueue (`LOOP=epoll`), not Linux. Pinned Goose
`v2026.1`, `goose build --standalone`, Apple clang 21.0.0. Datasets from goose-http's
`bench/rest/gen.goose`.

- Servers: goose-rest's server before (`94ed2a4`, after fix 1) and after this change,
  and goose-http's `bench/rest/goose/rest.goose` at `v0.3.2` with its `mallopt` call
  removed. Each with `TIER=d`, `JSON=serialize`, `WORKERS=4`.
- Uploads: each cell a fresh server under `/usr/bin/time -l`, whose "maximum resident
  set size" is the peak. Idle RSS is `ps -o rss` 3 s after the server listens, and end
  RSS the same just before it stops. wrk 4.2.0, `-t 1 -c 32`, `tier-d.lua uploads`,
  5 s warm-up then 15 s.
- Reads beside uploads, task 021's workload: a fresh server; tier C's
  `/api/v2/schedule/version` poll at 1,700 requests/s with oha 1.16.0 (`-q 1700
  --latency-correction -c 64`, 15 s), alone, or after 5 s of the uploads above and
  beside them.
- 3 rounds, interleaved by round, then server. The tables show medians, with the
  rounds' range in brackets where it matters. The machine wasn't kept idle, and a
  subagent editing docs ran beside the first rounds.

### Results

Uploads, RSS in MiB:

| Server | idle | end | peak |
|---|---:|---:|---:|
| goose-http | 53.2 | 54.8 | 71.3 |
| goose-rest before | 53.4 | 281.4 [274.0-308.8] | 281.4 [274.0-308.8] |
| goose-rest after | 51.9 | 53.5 | 69.9 |

Uploads, rate and latency:

| Server | Requests/s | p50 | p99 |
|---|---:|---:|---:|
| goose-http | 962 (940-963) | 19.8 ms | 110.7 ms |
| goose-rest before | 892 (868-921) | 23.9 ms | 118.3 ms [114.6-157.4] |
| goose-rest after | 962 (946-967) | 19.6 ms | 108.2 ms |

The poll's latency beside the uploads:

| Server | p50 | p99 | p99.9 |
|---|---:|---:|---:|
| goose-http | 8.8 ms | 21.7 ms | 37.6 ms [33.6-41.5] |
| goose-rest before | 8.5 ms | 24.4 ms | 30.4 ms |
| goose-rest after | 8.4 ms | 21.0 ms | 25.7 ms [23.6-27.7] |

Every poll got 200, at the full 1,700/s, on every server and round.

The spill is gone: goose-rest's upload peak falls by 211 MiB, to 1.4 MiB below
goose-http's, and RSS no longer grows under the uploads (end RSS 1.6 MiB above idle,
against goose-http's 1.6). The upload rate is goose-http's, where it was 7% lower, and
the polls' p99 beside the uploads is goose-http's, where it was 2.7 ms higher.

The poll alone varies between rounds on every server, p99 from 0.7 to 6.5 ms, so these
runs don't separate the servers there. Task 021's stall, a p99 of 13.8-28.1 ms
beside uploads against goose-http's 0.40-7.5 ms, was measured on Linux. On macOS, the polls beside the
uploads were within 3 ms of goose-http's before this change. The Linux rerun says
whether the stall is gone.

## Fix 3 (2026-10-15)

Notes where a reader would make each mistake in "Mistakes in the program":

- Records loaded in `main`: tutorial page 1, "Workers and `main`", and page 8, "Per
  worker", say that data loaded before the workers start is copied into every worker,
  and point to goose-http's shared store. Task 027's helper can replace the pointer.
- Strings in fixed-capacity fields: page 8, "Per worker", and `docs/generator.md`, below
  its types table, say a limited array takes its full capacity, and to keep many
  records' strings as ranges into one byte array.
- Uploads gathered whole: page 10, "Three limits", says the worker keeps a gathered
  body's memory after the request and answers nothing else while the route reads it,
  and the reference's `rest::body` row points to `rest::body_in_pieces`.
