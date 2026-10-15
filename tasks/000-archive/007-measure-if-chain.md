# 007: Measure the if chain at 60 routes

Status: done (2026-10-13: task 008 goes ahead)

Decides whether task 008 is worth doing. A hand-written if chain with prefix scopes, at
60 routes shaped like a real API, against the same server with one route.

## Acceptance criteria

- [x] Instructions per request for the first route, the last, a 404, and a 405, with
      `bench/count.sh`'s load (macOS can't run `count.sh` itself: below)
- [x] The numbers recorded here with how they were measured, and a decision on task 008

## The servers

`bench/routes/routes60.goose` has 60 routes over `http::router` and `http::on`: `GET
/health`, then eight scopes under `/v1` (`auth`, `users`, `orgs`, `projects`, `tasks`,
`files`, `webhooks`, `reports`) of 4 to 10 routes each, with path parameters and up to
five methods per path. A scope is an `if` on the path's prefix around its own chain,
which ends in `http::otherwise`. Every route answers 200 with `ok`.

Each case compares the 60-route server with a one-route server that gets the same
request and sends the same bytes back:

| Case | Request | 60 routes | One route |
|---|---|---|---|
| First route | `GET /health` | 200 | `routes1`: `GET /health` |
| Last route | `GET /v1/reports/exports/42/download` | 200 | `routes1_last`: that route |
| 404 in a scope | `GET /v1/reports/exports/42/nope` | 404 | `routes1_last` |
| 404 outside the scopes | `GET /v2/nothing` | 404 | `routes1` |
| 405 | `GET /v1/reports/exports/42/cancel` | 405, `Allow: POST` | `routes1_post`: `POST` of that path |

The last route, the 404 in a scope, and the 405 each run `http::on` for `/health` and
all nine routes of the last scope, after eight prefix checks.

## Results (2026-10-13)

MacBook Pro, Apple M1 Pro, macOS 26.3.1 (Darwin 25.3.0), on battery, load average
6.6-6.8 from other work. Goose `a6249a4`, goose-http `cfb9c02`, the servers at `7131d0c`,
built with `goose build --standalone` (Apple clang 21, `-O2`), serving with
`http::serve_epoll` over kqueue, one worker. `bench/routes.sh`: h2load 1.70.0 `--h1 -n
2000000 -c 256 -m 16 -t 8` with `count.sh`'s headers, on the same machine, nothing
pinned; the server's instructions retired and cycles elapsed from `/usr/bin/time -l`,
kernel included, divided by the requests. 3 rounds, interleaving the servers. Ranges
over the rounds:

| Case | 60 routes, insns/req | One route | Difference | 60 routes, cycles/req | One route |
|---|---:|---:|---:|---:|---:|
| First route | 18,281.6-18,299.8 | 18,244.9-18,254.0 | +28 to +55 | 4,517.0-4,588.4 | 4,512.7-4,540.0 |
| Last route | 25,856.2-25,859.2 | 19,805.5-19,848.0 | +6,008 to +6,053 | 6,057.9-6,122.0 | 4,826.9-4,906.6 |
| 404 in a scope | 25,436.2-25,439.3 | 19,459.0-19,475.4 | +5,964 to +5,979 | 5,955.7-6,012.9 | 4,735.4-4,760.8 |
| 404 outside | 18,293.6-18,298.2 | 18,148.8-18,159.7 | +138 to +149 | 4,525.9-4,626.8 | 4,515.1-4,541.3 |
| 405 | 25,787.6-25,789.9 | 19,756.6-19,764.7 | +6,024 to +6,031 | 6,059.0-6,082.8 | 4,774.5-4,802.8 |

At the last route the one worker served 493,399-499,162 requests a second against
569,436-572,317 with one route, 12-14% fewer (one round of the one-route server, at
472,621, left out).

The same run at the earlier pin, goose-http `04791ac` (servers at `bf5c9c5`, load
average 8.1-12.0), gave the same differences to within 45 instructions: +6,010 to
+6,016 at the last route, +5,978 to +5,988 for the 404 in a scope, +146 to +159
outside, and +6,023 to +6,041 for the 405.

The difference is the router's alone: both servers do the same kernel work for the same
request, and the differences repeat to within 45 instructions. The scopes do their job
for paths outside them (about 150 instructions for eight prefix checks), and at the first
route the chain costs at most 55. Inside the last scope, each `http::on` costs
about 600 instructions, so ten of them add a third to everything the server process ran
per request, kernel included.

Where the 600 go, from one more build at `04791ac` (2 rounds, same load, last route
only, not committed): a copy of `on` whose segment compare uses `==` when the path's segment has no
`%`, skipping goose-http's byte-at-a-time escape decoding, ran 24,781.0-24,781.1
instructions per request against 25,916.0-25,918.3, saving 1,135 of the 6,010. The rest
is the chain's shape: each `on` walks its pattern against the path from the first `/`, so
every route in a scope scans the scope's prefix again. Only matching the path once,
segment by segment, removes that.

### Not measured

- `count.sh` itself: macOS has no `perf`, and Docker Desktop's VM exposes no counters.
  Since goose-http `bab61c6` (2026-10-13), `count.sh` takes the path as `TARGET` and the
  expected status class as `STATUS`, so a Linux run of these cases copies the servers
  into goose-http's `build/bench/` under names starting `goose` and runs, for example,
  `TARGET=/v1/reports/exports/42/nope STATUS=4 bench/count.sh goose-routes60 goose-routes1_last`.
- User instructions alone. On the benchmark desktop, a whole plaintext request costs
  goose-http about 1,825 user instructions (`count.sh`, goose-http's task 027): a
  different machine and instruction set, so it compares with the 6,000 here only in
  order of magnitude.

## Decision on task 008

Decided (2026-10-13): do task 008. At 60 routes, the last route of a
scope, a 404 inside a scope, and a 405 each cost about 6,000 instructions and 1,200
cycles a request more than one route, on the order of the whole HTTP layer's own work. A
faster segment compare in goose-http would recover a fifth of it. The rest comes from
re-scanning the path once per route, which a generated `dispatch`, matching the path
once by length and segment, doesn't do. The if chain stays the API for a program
without a schema; a program with many routes behind one prefix can split it into more
scopes.

Task 008 must keep the if chain's answers, as its criteria say: `http::on` matches an
escaped unreserved byte as the byte itself (`/v1/%72eports` is `/v1/reports`), and the
prefix checks here compare raw bytes, so this server answers such a path 404 where a
flat chain would match it.

## goose-http's task 027

Task 027 may still change `http::router` and `http::on`, as its API isn't settled. None
of its proposals touch them so far: `router.goose` at `cfb9c02` differs from `04791ac`
only in a comment, and the differences held across that move. They depend only on
`router.goose`, so they need rerunning only if 027 changes it. The absolute counts move
with any change to the loops, so rerun `bench/routes.sh` when the pin moves, to keep the
table at one pin; it takes about 5 minutes.
