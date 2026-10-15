# 029: A per-worker budget for bodies being gathered

Status: done (asked for 2026-10-15; the answer past the budget decided 2026-10-15; done
2026-10-15)

A worker gathers as many bodies at once as its clients send, each up to its route's
limit, so its spill's high-water mark, which it keeps for its life, has no bound but
the number of connections times the largest limit (task 020's findings). A budget per
worker for bytes being gathered bounds it.

## Decided (2026-10-15)

Past the budget, the route gets 503 at once, with `Retry-After`; the worker doesn't
stop reading the connection. This follows Tina's bounded mailboxes, as goose-http's
does: a size fixed up front, and a full one sheds load rather than holding work in a
wait without a time limit. Held reads would leave clients with stalled uploads, keep
their connections and kernel buffers, and need goose-http to pause and resume reads in
every loop.

- A body with a `Content-Length` reserves its whole size at the head: one that doesn't
  fit is refused before it is sent, and before `100 Continue`. Task 028's run of the
  body's exact size, taken at the first piece, is the reservation.
- A chunked body reserves as it grows, and past the budget gets 503 and the connection
  closes, as a chunked body past its route's limit gets 413.
- A route on `rest::body_in_pieces` doesn't count against it: that's the way to take
  large bodies, and the 503 points a program to it.
- The budget is a setting with a default. The spill's peak then follows the
  configuration, not what clients send.

## Acceptance criteria

- [x] A `Config`-style setting for the budget, with a default recorded with its reason
- [x] Past the budget, a route that gathers gets 503 with `Retry-After`, as decided
      above, and the spill's peak stays within the budget under task 020's upload
      workload with tier D gathering (its server before task 020's fix 2), measured
- [x] Unit tests cover a body with a length refused at its head, a chunked body past
      the budget, a body that fits after another finishes, and a route on
      `rest::body_in_pieces` beside a full budget
- [x] The reference and tutorial page 10, "Three limits", say what the budget bounds
      and what a client sees past it

## How it works

- **The setting.** `rest::Config { gather_budget }`, goose-rest's settings beside
  `http::Config`, is an optional last parameter of `rest::serve` and
  `rest::serve_epoll` after the per-request state, and of both `rest::serve_one`
  forms after `cfg`. goose-http is unchanged. The default is 64 MB per worker: 64
  bodies at goose-http's default `max_body` of 1 MB at once, or four at a 16 MB limit,
  and about what tier D's uploads reach on their own (below), so a program that never
  thinks about the budget is refused only under that load or more.
- **What it bounds: the spill's length, not only the bytes in use.** The first version
  counted the runs in use, as the decision words it. Measured, a 16 MiB budget still
  let the largest worker's spill reach 35-36 MiB, and the 64 MiB default 72-85 MiB:
  the spill places runs first fit, and runs freed between larger ones leave holes that
  a later run doesn't fit. So the budget now bounds the spill's length. The worker's
  `Budget` records the runs in use and the spill's length, and predicts where the spill
  places a run as spec §5.4 says `alloc_slice` and `realloc_slice` do: every byte
  outside the runs in use is free, so a run goes at the first start (0 or a run's end)
  with room, or else after the last run, growing the spill. A run that would take the
  spill past the budget is refused. A body can therefore be refused while less than the
  budget is in use, when the free space is in pieces too small for it; the reference
  says so. The prediction only decides whether a run is taken: `Budget` then records
  the run where the spill placed it and the spill's length after, so if a Goose release
  places runs otherwise, a decision can be off by one run and the next corrects it,
  and the unit tests, which compare the record with the spill after every event, fail.
- **A body with a `Content-Length`.** `rest::body` checks at the head, inside the
  route, so the 503 has the program's error shape and the middleware's fields, and
  goose-http sends no `100 Continue` for a request answered at `REQUEST`. The run of
  task 028 is then taken in the same event, so nothing can take the space between.
  The connection stays open: goose-http drains or closes the unread body as for any
  answer before the body.
- **A chunked body.** Its first 16 KB run is checked at the head as above. When it
  fills, it doubles if the doubled run fits the budget, and otherwise grows by what the
  piece needs; when even that doesn't fit, it gets 503 with `Retry-After` and the
  connection closes, as for 413 past its limit. That answer is serve's own, so it has
  the program's error shape but not the middleware's fields, as the 413 doesn't.
- **`Retry-After: 1`**, a constant: the space frees as soon as a body being gathered
  is answered, so the fewest seconds the field can say.
- **The middleware's kept runs** (task 025) share the spill. They are recorded so the
  prediction stays exact, but placed without a check: about 100 bytes each, held only
  while a route waits.
- **`rest::body_in_pieces`** takes no spill and doesn't count.

`test/test_gather.goose` covers a body with a length refused at its head (through
`serve_one`, which runs the route once), one that fits a budget of exactly its run, a
chunked body that doubles, then grows by its pieces, then gets 503 and the connection
closes, a body refused beside another and taken once the other has finished, a route on
`rest::body_in_pieces` beside the full budget, and a body refused for a hole too small
although the bytes in use leave room. After every event it checks that the budget's
idea of the spill's length is the spill's, and within the budget.

## How this was measured

As in task 028:

- Machine: Apple M1 Pro, 10 cores, 32 GB, macOS 26.3.1 (Darwin 25.3.0), goose-http's
  epoll loop on kqueue (`LOOP=epoll`), not Linux. Pinned Goose `v2026.1`,
  `goose build --standalone`, Apple clang 21.0.0.
- Server: goose-rest's tier server as it was before task 020's fix 2
  (`bench/rest/goose-rest/main.goose` at `94ed2a4`), whose imports and attachments
  gather with `rest::body` up to 16 MB, not committed. Built with task 028's runtime
  (no budget) and with this change, where its tier C and D workers pass a
  `rest::Config` whose `gather_budget` comes from a `GATHER_BUDGET` variable, unset for
  the 64 MiB default and 16 MiB for the low budget. In each build `runtime.goose` prints
  the spill's length each time it grows (not committed); the largest is the largest
  worker's spill.
- Each cell: a fresh server, `TIER=d`, `WORKERS=4`, `LOOP=epoll`, under
  `/usr/bin/time -l`, whose "maximum resident set size" is the peak. Idle RSS is
  `ps -o rss` 3 s after the server listens. wrk 4.2.0, `-t 1 -c 32`, goose-http's
  `tier-d.lua uploads` (attachments of 100 KB to 1 MB with a `Content-Length`, two in
  three; chunked CSV imports of 2-8 MB, one in three), 5 s warm-up then 15 s.
- 3 rounds, the three servers interleaved, with no test run or other server on the
  machine. Medians, with the rounds' range in brackets.

## Results

| Server | budget | largest worker's spill | peak RSS | 503s in 15 s | requests/s | p50 | p99 |
|---|---:|---:|---:|---:|---:|---:|---:|
| no budget | none | 62.0 [61.0-66.8] MiB | 294.6 [277.6-310.0] MiB | 0 | 919 [900-935] | 23.6 ms | 126.9 ms [113.0-132.1] |
| default | 64 MiB | 63.9 [58.8-64.0] MiB | 281.8 [272.1-294.9] MiB | 1 [0-1] | 901 [891-915] | 23.5 ms | 136.2 ms [116.8-138.4] |
| low | 16 MiB | 16.0 [16.0-16.0] MiB | 121.1 [121.1-122.7] MiB | 1,327 [1,218-1,345] | 800 [791-802] | 26.3 ms | 127.2 ms [122.1-131.1] |

Idle RSS was 51.7-53.5 MiB on every server. The largest spill under the 16 MiB budget
was 16,777,216 bytes in every round, exactly the budget, and under the default at most
67,104,032 bytes, 4,832 below it.

- The spill's peak stays within the budget, and RSS follows it: 52 MiB idle plus about
  four workers at 16 MiB and tier C's records, 121 MiB, where the same load without a
  budget reaches 278-310 MiB.
- The 16 MiB budget refuses about 11% of the uploads with 503 (wrk's "non-2xx"), and
  closes 1-5 chunked connections a round mid-body (wrk's read errors). The rate falls
  13%, which these runs don't explain; the closed connections wrk opens again are one
  candidate. That is the trade the budget makes: memory
  bounded by the configuration, and load past it shed.
- The default budget is about this load's own peak: it refused 1 upload in two of three
  rounds and bounded the spill there.
- Near the budget, a chunked run that can't double grows by its piece, so the spill
  grows in more, smaller steps: 623-915 growths at 16 MiB against 138-149 without a
  budget. Each step that moves the run copies it.

The 503s and the 16 MiB peak against an unbounded one are both this workload's, chosen
to push past the budget; a program sets the budget above its usual load.

## Alternatives not taken

- **Counting only the bytes in use**, as decided at first: simplest, but measured above
  it doesn't bound the spill, which is what the budget is for.
- **A field in `http::Config`**: goose-http isn't changed for goose-rest.
- **A bare `i64` parameter for the budget** on `rest::serve`: one less type, but a
  number with no name at the call, and no room for goose-rest's next setting.
- **A `Retry-After` in `rest::Config`**: no program has asked for another value.
- **Doubling a chunked run past what fits, up to the budget's end**: fewer growth
  steps near the budget, but it would take room another body could use; growing by the
  piece takes only what the body has sent.
