# 047: HttpArena

Status: in-progress. The plan for entering HttpArena (2026-10-19). The entry,
`bench/httparena/plod/`, subscribes to 22 profiles, the gateway three among them,
and passes HttpArena's `validate.sh` at `3717e25`: 144 checks, none failed, the
static files' optional compression skipped (2026-10-23, Docker Desktop on an M1 Pro).
A review against peer entries (2026-10-23) left it ready to submit: its JSON is
serialized per request with `plod::format_fields`, `/async-db`'s and the cache's rows
decoded into structs; production-stack's cache admits at most 256 asks a worker, with
its boxes sized from that count ("Bounding production-stack's memory", below); it has a
README, a two-line Dockerfile per proxy, `*_CPUSET` variables in its compose files, and
imports Plod at commit `a23bd98` of branch `try-reply` until `v0.5.2` is tagged, its
Dockerfile downloading Goose's release. The submission and the benchmark runs remain.

This task is the master plan: which profiles the entry can run, what each one needs, and
which repository builds it. The protocol and database work happens in those
repositories, each in its own task. This task tracks only the order and the entry.

## How HttpArena scores

Checked against `MDA2AV/HttpArena` at `2d85137` (2026-10-18), in
`site/content/docs/scoring/`:

- Each scored profile is worth up to 1,000 points, relative to the best entry, and a
  board's composite is their sum. A profile the entry doesn't run scores 0, so coverage
  counts as much as speed.
- HTTP/1.1, h2, h3, gateway, gRPC, and WebSocket are separate boards.
- A completeness factor takes 2.5% off for each of routing, middleware, the request,
  and the response that the framework leaves to the program. goose-rest does all four.

## The profiles

| Profiles (scored) | Needs | Built in |
|---|---|---|
| baseline, limited-conn, json-comp, async, latency-1m, latency-10k | Nothing more: goose-http passes them (goose-http's task 018), and `rest::pause(cx, ms, u)` (done, 2026-10-21) pauses a route before its response begins so `/delay/{ms}` answers 200 `text/plain` from the worker's timer table | This task's entry |
| json-tls, 8gbit; static-tls (reference) | TLS 1.3 on port 8081 with the mounted RSA-2048 certificate, ALPN `http/1.1`. 8gbit echoes 10 KB at a pinned 50K requests per second and is scored on CPU per request | goose-tls task 001; goose-http task 014 |
| async-db (reference) | `/async-db`: a Postgres range query, through an async driver with a pool of `DATABASE_MAX_CONN` (256) connections. Published but not scored. HttpArena at `3717e25` has no api-4 or api-16 any more: upstream removed them (the comment in `scripts/benchmark.sh`) | goose-postgres tasks 001 (the protocol, done) and 005 (the pool) |
| fortunes (reference) | Not in the entry | Not planned |
| gateway-64, gateway-h3, production-stack | `/async-db` again, behind a standard proxy that terminates TLS, h2, and h3. The rules forbid a custom proxy, so the server speaks plaintext HTTP/1.1. In production-stack the shared `authsvc` verifies the JWT at the edge, and the cache can be in-process | Done (2026-10-23): a compose file each, stock nginx for gateway-64 and production-stack and stock Caddy for gateway-h3 (stock nginx has no QUIC), and production-stack's routes in `app.goose`, its cache in lanes that each own the ids they're given and a blocking Postgres connection. The lanes start only where the compose file sets `API_CACHE`, one per worker, their connections within half of `DATABASE_MAX_CONN`, with boxes sized from the asks each worker admits (2026-10-23, below). validate.sh checks h3 only through h2; one h2load-h3 run got 2xx over h3 on Docker Desktop. Measuring remains |
| echo-ws, echo-ws-pipeline, echo-ws-limited | WebSocket: the handshake, framing, and masking over `rest::upgrade` | goose-http task 054 |
| baseline-h2c, json-h2c | h2 with prior knowledge on port 8082, without TLS | goose-http task 014, phase 4 |
| baseline-h2, static-h2 | h2 over TLS with ALPN on port 8443 | goose-http task 014, phase 5 |
| unary-grpc, unary-grpc-tls | gRPC over h2, and protobuf | After h2 |
| baseline-h3, static-h3 | QUIC | Last |

## Bounding production-stack's memory

Done (2026-10-23), after a review
(`build/reviews/resource-bounding-review-2026-10-23.md`, of which the issues were taken
and the cures only in part). Sizing the boxes for every wait goose-http allows,
`max_waiting` = `max_conns`, had committed 51, 306, and 816 MiB at 4, 24, and 64
workers. The cache now follows Plod's production guidance
([sizing a lane's admissions and boxes](../docs/best-practices/lanes.md#67-sizing-a-lanes-admissions-and-boxes),
and the decision of the same date):

- A worker admits at most 1,024 cache asks at once, less its pool's hand-overs (1,015
  at 24 workers), and answers one past them with
  503 `busy` at once. HttpArena's `scripts/lib/tools/h2load.sh` runs the reads at 1,024
  connections of `-m 16` streams, about 16,000 in flight, and the writes at 128 of
  `-m 8`; 60% of the reads go to `/api/`, so up to about 10,000 cache asks, some 400 a
  worker at 24 workers. How many the edge and authsvc let through at once is
  unmeasured. 64 refused 15% of a healthy load at 3 workers under 256 connections, and
  256 sat below that arithmetic (2026-10-23). A full lane box is 503 `unavailable`
  (`plod::try_ask`'s `http::FULL`); `http::TOO_LONG` is 500 `job_too_long`. Nothing
  retries.
- The route owns its waits (`plod::own_waits`), so the reply, the lane's refusal, the
  `TIMEOUT` (504, never asked again), and the `CLOSED` each reach it, and the admission
  is given back there. A plain paused route gets no `CLOSED` (its timer is cancelled),
  which would have lost the admission. Checked natively against a Postgres address
  that never answers, rounds of 600 parallel requests at 8 workers: every request was
  admitted and timed out, again after clients that left at 1 s; a hot id filled its
  lane's box and the rest got 503 at once; and 300 refusals from a closed port left the
  admissions whole.
- Each lane's box holds its share of the admissions, 1,024 at a lane per worker: 3 and
  10 lanes at their share refused nothing under healthy load (at 256 admissions, three
  runs each; at 1,024 under 1,024 connections, one run each). Each worker's box holds
  1,024 replies, the admission and the pool's hand-overs, and `max_waiting` is the
  admission. Admitting 1,024 and rounding the box up to 2,048 had put 80% of the boxes'
  memory in the workers' boxes, half of it never used (2026-10-23).
- The lanes reply with `plod::try_reply` and refuse with `plod::try_refuse` (Plod
  branch `try-reply`, for `v0.5.2`), which drop a reply that finds the worker's box
  full; a reply past one 512-byte message is 500 `reply_too_long`. Each lane checks
  `plod::still_wanted` before a job.
- `plod::try_ask`'s contract holds (its test, and the code): a refusal sends nothing,
  leaves no gather promise and no wait armed, and leaves `cx.state.use` as it was.

Boxes take 3.2, 19.1, and 51.0 MiB at 4, 24, and 64 workers, and the timer tables
180 KiB, 1.1 MiB, and 3 MiB, where `max_conns` made them 51, 306, and 816 MiB, and 3,
18, and 48 MiB. Measured before the workers' boxes shrank to 1,024 slots, on Docker
Desktop on an M1 Pro (2026-10-23, one run each), the
server on its own Postgres under wrk at 256 connections, 15 s on `/api/items/:id` and
10 s on `/api/me`: peak RSS (`VmHWM`) 52 MiB at 3 workers against 95a8822's 86 MiB, and
90 MiB at 10 workers against 209 MiB; every request answered 200 by both;
`/api/items/:id` at 315,000 and 390,000 requests a second against 303,000 and 378,000.
At 3 workers under 1,024 connections, 256 admissions had answered 67% with 200 and the
rest with 503; 1,024 answered every request with 200. validate.sh passes, 144 checks,
none failed, with the Plod commit seeded into the build's Goose cache, since the branch
isn't on GitHub yet. The dictionaries don't evict: the dataset bounds them.

Run D, 2026-10-23: production-stack under HttpArena's own h2load load (`-m 16` reads
plus the writes) through its edge, Ryzen 7 5800X3D, Ubuntu 26.04 in WSL2 (kernel
6.18.54.1), Docker Desktop 29.8.2, the harness in a container on the VM's host network.
`PROFILES=production-stack RUNS=1 bench/httparena.sh run`, the server on CPUs 0-3 (4
workers), the edge on 4-7, authsvc on 8-9, the cache on 10-10, and the load on 11-15;
HttpArena's network sysctls on, but for `netdev_max_backlog`, which Docker Desktop's
VM doesn't expose. `VmHWM` read from `/proc` once a second during the run.

| Build | Connections | Requests a second | 2xx | 503 | Other | Server `VmHWM` |
|---|---:|---:|---:|---:|---:|---:|
| 935abdf | 256 | 38,143 | 192,627 | 0 | 0 | 34.4 MiB |
| 935abdf | 1,024 | 32,352 | 165,323 | 0 | 0 | 38.7 MiB |
| 95a8822 | 256 | 37,200 | 188,609 | 0 | 0 | 84.8 MiB |
| 95a8822 | 1,024 | 30,141 | 154,025 | 0 | 0 | 88.9 MiB |

Neither build refused a request at 4 workers. The edge used all of its 4 CPUs (about
400%) while the server used under 190% of its 4, so the edge, not the server, set the
rate. The new build peaks at under half the memory, at the same rate or better.

## The entry's tier

`meta.json`'s `type` places a framework in one of three tiers, which grade only how
proven it is in production (`site/content/docs/add-framework/implementation-rules/frameworks/`,
checked 2026-10-19): flagship (real applications built and run on it at scale, actively
maintained), emerging (a genuine, working server, not yet production-proven), and
experimental (very new work, hidden on the leaderboard unless a reader opts in). The
entry picks its tier, and HttpArena's maintainers may change it on review. Aegon entered
as experimental.

The entry enters as experimental, as Aegon did, and asks for emerging later
(2026-10-23, replacing the plan of 2026-10-19 to enter as emerging). A tier changes by
a pull request that edits `meta.json`'s `type`, which the maintainers accept or not;
they also move entries themselves (viltrum went from emerging to experimental with its
1.1.0 update, 2026-10-21). The request for emerging goes with a substantive update, such
as the Postgres profiles. Until then, the leaderboard hides the entry unless a reader
opts in.

HttpArena's only requirement of a framework entry is that it implements HTTP itself and
passes `validate.sh` on its own (2026-10-23, replacing a list of conditions for
emerging set on 2026-10-19). What follows is this project's own bar, held so that a
crash doesn't surface on a public leaderboard, and the case the request for emerging
makes:

1. Releases to rely on: tagged versions with a changelog, under the new name (task 046),
   and goose-http's API settled (its task 027).
2. Correctness beyond HttpArena's validation: h2spec passing (goose-http's tasks 014.01
   and 061, over h2c and TLS on each loop), the parsers of what a client sends fuzzed
   (goose-http's `fuzz/`: the request head and chunked body, HPACK, h2 frames, and
   multipart, an hour each with no finding, 2026-10-23, its `docs/development.md`), the
   limits and timeouts documented, and no known crash open. A security audit after
   Cloudflare's security-audit skill (2026-10-23) found one issue, `plod::cors`
   echoing any origin with credentials under `*`, fixed the same day.
3. Documentation for writing an application: the tutorial and best-practices guides.

goose-http's own benchmark entry (its `bench/httparena/`, of type `engine`) isn't
submitted for now (2026-10-23); Plod's is the only one.

Flagship needs applications in production that others built and run. snowtime-native
in production is a start on that, not enough on its own.

## Beyond HttpArena: one binary

The same packages serve a second target: a server that is its own reverse proxy, as
snowtime-native's edge is today (`crates/host/src/edge/`, over rustls and
rustls-acme). It gets certificates from Let's Encrypt through TLS-ALPN-01, chooses h2 or
HTTP/1.1 by ALPN, redirects plaintext HTTP, and runs on SQLite. A goose-rest program
should do all of that in one process, and still run behind Caddy or nginx. That adds
SNI, swapping certificates while running (goose-tls tasks 001 and 003), and ACME, a
package of its own (task 049), to what HttpArena needs.

SQLite scores nothing on HttpArena. goose-sqlite comes before goose-postgres because it
needs no network code, and because goose-rest needs a database for its own examples
(task 035's data access) and for the one-binary target.

goose-tls, goose-sqlite, goose-hash, and goose-postgres follow goose-compress's layout.
The first three are on GitHub at `v0.0.1` (2026-10-19); goose-postgres stays local
until it has working code.

## Order

1. Task 046's rename and task 050's use-case enum, then the entry with the six HTTP/1.1
   profiles goose-rest already serves.
2. TLS: goose-tls task 001, then HTTP/1.1 over TLS in goose-http (task 014, phase 2),
   then json-tls and 8gbit in the entry. kTLS (task 014, phase 3) matters for 8gbit's
   CPU score.
3. goose-sqlite task 001, beside TLS.
4. Postgres: outbound TCP connections in goose-http (task 053), then goose-postgres
   task 001, then async-db, the two gateway profiles, and production-stack.
5. WebSocket in goose-http (task 054), then the three echo profiles.
6. h2c, then h2 over TLS (goose-http task 014, phases 4 and 5), then the four h2
   profiles.
7. gRPC, then h3.

## Hashes

SCRAM-SHA-256 for Postgres, WebSocket's handshake, and a JWT verifier need SHA-1,
SHA-256, HMAC, and PBKDF2. Goose's stdlib has none of them (checked 2026-10-19), so
they go in goose-hash, a package of its own in Goose (its `docs/decisions.md` has the
reasons). Its task 001, done in `v0.0.1`, came before goose-http's WebSocket and
goose-postgres; its task 002 closes the speed gap to OpenSSL and the Rust and Zig
implementations.

## Acceptance criteria

- [x] goose-http has tasks for outbound connections (053) and WebSocket (054), and its
      task 014 records this order (2026-10-19, on goose-http's `main`)
- [ ] The entry submitted as experimental
- [ ] The project's own bar met, as "The entry's tier" lists, and a pull request
      setting `meta.json`'s `type` to `emerging` accepted
- [ ] The entry runs the six HTTP/1.1 profiles; `validate.sh` passes and the results are
      saved
- [ ] json-tls and 8gbit in the entry, passing HttpArena's TLS checks
- [x] gateway-64, gateway-h3, and production-stack in the entry (2026-10-23)
- [ ] The three WebSocket profiles in the entry
- [ ] The four h2 profiles in the entry
