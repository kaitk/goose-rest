# 028: Gather a body of known length in one run of its exact size

Status: done (asked for 2026-10-15, done 2026-10-15)

`rest::body` gathers a long body into the worker's spill, growing the run by doubling
from 16 KB as pieces come (`gather_piece` in `runtime.goose`). A body with a
`Content-Length` is copied once per doubling, and its run ends up to twice its size,
which the spill keeps as its high-water mark for the worker's life (task 020's
findings). A body whose length is known can take one run of that size at its first
piece: no growth copies and no slack. A chunked body still grows as now.

## Acceptance criteria

- [x] A body with a `Content-Length` is gathered into one run of its head and body's
      exact size, allocated at the first piece, with no copy as it grows; a chunked
      body grows as before
- [x] Unit tests cover a body with a length, a chunked one, and one over its limit
- [x] The spill's peak for task 020's upload workload is measured before and after, with
      how it was measured

## What changed

`gather_head` takes the run when the route leaves to gather its body, with the rebuilt
head as the run's first piece. For a `Content-Length` the run is the head plus the
body's length, so `gather_piece` only copies each piece in: goose-http never sends more
than the length, and a body over the route's limit was refused at its head. A chunked
body's run starts at 16 KB and doubles as before.

`test/test_gather.goose` drives `rest::deliver` event by event and checks the run's
capacity after the head and each piece: one run of the exact size that never moves for a
body with a length, 16 KB doubling for a chunked one, 413 at the head for a length over
the limit with nothing allocated, and 413 and a closed connection for a chunked body
past it.

## How this was measured

- Machine: Apple M1 Pro, 10 cores, 32 GB, macOS 26.3.1 (Darwin 25.3.0), goose-http's
  epoll loop on kqueue (`LOOP=epoll`), not Linux. Pinned Goose `v2026.1`,
  `goose build --standalone`, Apple clang 21.0.0.
- Server: goose-rest's tier server as it was before task 020's fix 2
  (`bench/rest/goose-rest/main.goose` at `94ed2a4`), whose imports and attachments
  gather with `rest::body` up to 16 MB. Not committed. Built against the package at
  `159b84a` (before) and with this change (after). In both builds `runtime.goose` prints
  the spill's length to stderr each time it grows (not committed), which gives the
  spill's high-water mark directly.
- Each cell: a fresh server, `TIER=d`, `WORKERS=4`, `LOOP=epoll`, under
  `/usr/bin/time -l`, whose "maximum resident set size" is the peak. Idle RSS is
  `ps -o rss` 3 s after the server listens. wrk 4.2.0, `-t 1 -c 32`, goose-http's
  `tier-d.lua uploads` (attachments of 100 KB to 1 MB with a `Content-Length` two times
  in three, chunked CSV imports of 2-8 MB the third), 5 s warm-up then 15 s. Datasets
  from goose-http's `bench/rest/gen.goose`.
- 3 rounds, before and after interleaved. Medians, with the rounds' range in brackets.
  The first rounds overlapped a test run in another worktree; all of them were discarded
  and the 3 rounds rerun with the machine otherwise idle.

## Results

| Runtime | idle RSS | peak RSS | largest worker's spill | spill growths | requests/s | p99 |
|---|---:|---:|---:|---:|---:|---:|
| before | 51.7 MiB | 286.3 [278.4-308.1] MiB | 69.1 [65.2-69.6] MiB | 200 [188-209] | 904 [901-945] | 137.2 ms [125.2-138.6] |
| after | 53.2 MiB | 271.3 [267.9-303.3] MiB | 62.9 [57.9-72.2] MiB | 133 [126-142] | 934 [910-944] | 119.4 ms [111.4-135.3] |

Spill growths are the times any worker's spill grew, all 4 workers together.

The spill grows a third less often, and the medians of the peak and of the largest
spill fall by 15 MiB and 6 MiB, but the rounds' ranges overlap: this workload's spill
is mostly its chunked imports, which still double, to runs of up to 8 MiB. The attachments
with a length, at most 1 MB, now take their exact size, where they took up to twice it,
and are never copied as they grow.
