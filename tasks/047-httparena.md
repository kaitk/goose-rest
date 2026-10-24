# 047: HttpArena

Status: in-progress. The plan for entering HttpArena (2026-10-19). The entry,
`bench/httparena/plod/`, subscribes to 22 profiles, the gateway three among them, and
is HttpArena's pull request [#1623](https://github.com/MDA2AV/HttpArena/pull/1623),
open, as experimental in standard mode. It imports Plod `v0.5.6` and goose-http
`v0.5.9`, and passes HttpArena's `validate.sh` at `d9438f6`, still HttpArena's `main`:
144 checks, none failed (2026-10-24, Docker Desktop on an M1 Pro). Its JSON is
serialized per request with `plod::format_fields`, `/async-db`'s and the cache's rows
decoded into structs, and production-stack's cache admits at most 1,024 asks a worker,
less its pool's hand-overs ("Bounding production-stack's memory", below). What a review
of the pull request found, and what it leaves to do, is under "The pull request",
below.

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
| echo-ws, echo-ws-pipeline, echo-ws-limited | WebSocket: the handshake, framing, and masking over `rest::upgrade` | goose-http task 054. Validated (2026-10-23). At goose-http's default gather budget a worker admits 1,021 WebSockets ([goose-http's decision](https://github.com/kaitk/goose-http/blob/main/docs/decisions.md#the-gather-budget-counts-bytes-promised-and-refuses-at-admission)), and the standard mode requires the defaults, so 16,384 connections need 17 workers: on 4 CPUs (2026-10-23), 4,084 upgraded, the rest got 503 and reconnected, and echo-ws fell to 7.5K messages a second. HttpArena's machine runs 64 |
| baseline-h2c, json-h2c | h2 with prior knowledge on port 8082, without TLS | goose-http task 014, phase 4 |
| baseline-h2, static-h2 | h2 over TLS with ALPN on port 8443 | goose-http task 014, phase 5 |
| unary-grpc, unary-grpc-tls | gRPC over h2, and protobuf | After h2 |
| baseline-h3, static-h3 | Native QUIC on UDP 8443, which goose-http serves only where a program asks: the entry's TLS server turns it on, and `/static/` goes through `plod::files` as for static-h2 | goose-http's task 067 and goose-tls's task 008, and `plod.h3`. Built (2026-10-24): the entry serves both, `meta.json` lists them, and four requests each pass. In the entry from Plod `v0.5.7` (goose-http `v0.5.10`, goose-tls `v0.0.6`), and tuned in Plod `v0.5.8` (goose-http `v0.5.11`): HttpArena's `validate.sh` at `d9438f6` passes, 146 checks, both h3 ones included (2026-10-24). One run each in WSL ("The pull request", below): baseline-h3 1.53 M, static-h3 108 K |

## The pull request

Reviewed 2026-10-24 against HttpArena at `d9438f6`: the pull request's thread, the
owner's comments on the pull requests since 2026-04-19, the rules and scoring docs,
and the published results.

The owner ran `/benchmark --save` on 2026-10-23, at the entry's first commit
(`64062ae`: Plod `v0.5.4`, goose-http `v0.5.8`), and the bot committed the results to the
fork's `plod` (`ee81770`). The update to Plod `v0.5.5` (`e64ab48`) came after, so the
results on the branch aren't the branch's code, and a later `--save` replaces them
("one --save per PR … it clears previous --save commited data",
[#866](https://github.com/MDA2AV/HttpArena/pull/866)). The next `--save` is asked for
once the h3 profiles are in.

The h3 profiles are in (2026-10-24): Plod `v0.5.7` added them to the branch, and
`v0.5.8` brings goose-http `v0.5.11`'s tuned HTTP/3. The entry at `v0.5.8` passes
`validate.sh` at `d9438f6`, 146 checks, from a container in WSL. One run of the harness
there, the server on CPUs 0-3 and the load on 4-15 (Tiamat: Ryzen 7 5800X3D, WSL2
Ubuntu 26.04, Docker Desktop 29.8.2), against `v0.5.7`'s that morning:

| Profile | `v0.5.7` | `v0.5.8` |
|---|---:|---:|
| baseline-h3 | 1.20 M, 241% CPU, 29 MiB | 1.53 M, 235%, 29 MiB |
| static-h3 | 92.9 K, 297% CPU, 190 MiB | 108 K, 225%, 116 MiB |

Beside them on the same setup: zix-http3 1.86 M and 53.9 K, Aegon at its entry's
`e649022` 334 K and 32.6 K, and at its `main` 962 K and 121 K (goose-http's task 067,
"Comparisons"). The comment that asks for the run is `/benchmark -f plod --save`, as
HttpArena's pull request template gives it.

Done after the review (2026-10-24): Plod `v0.5.6` writes `format_fields`' JSON through
Goose's `json` writer and adds `plod::bytes` and `plod::field`, which `/echo` and
production-stack's `X-Cache` now use; gateway-h3's edge is stock nginx with its HTTP/3;
the entry's README and `meta.json` say so, and the pull request's description matches.

Among framework entries, from those results: first on json-tls, json-h2c,
baseline-h2, baseline-h2c, and gateway-64; second on async-db,
echo-ws-limited, and production-stack; third on json-comp, limited-conn, echo-ws,
echo-ws-pipeline, and pipelined; fourth on baseline. Where it scores low:

| Profile | Score of 1,000 | Why |
|---|---:|---|
| static-h2 | about 350 | `plod::files` opens and reads each file per request, at about 160 µs of CPU a request; the leaders get about 1.1 M against 392 K. The rules allow a cache that is the framework's own and follows the disk (`add-framework/implementation-rules/frameworks/standard.md`). Whether one pays is task 062 |
| gateway-h3 | about 490 | Caddy at the edge. The stock `nginx:1.27-alpine` image, which `proxy/` already uses, has `--with-http_v3_module` (checked with `nginx -V`), so the README's reason for Caddy was wrong; anole's stock nginx edge gets 162 K, where aspnet-minimal_caddy's and libuvcpp's Caddy edges get 69 K and 74 K, and the entry's 79 K. Now stock nginx, unmeasured |
| json-comp | about 910 | gzip only, at level 1, 1,438 bytes a response against the leader's 1,225: the score scales by the square of that ratio, ×0.73 |

static-tls, async-db, pipelined, fortunes, and latency-500k-8cpu are reference-only
(`site/leaderboard/data.js`, `scored: false`). The scoring docs still list api-4 and
api-16; `scripts/benchmark.sh` has removed them. baseline-h3, static-h3, unary-grpc,
and unary-grpc-tls are the scored profiles the entry doesn't run.

What the owner asks of framework entries, and where the entry stands:

- JSON through a serialization library, "preferably the standard one for that
  language", or the entry is marked tuned or engine
  ([#1616](https://github.com/MDA2AV/HttpArena/pull/1616),
  [#1568](https://github.com/MDA2AV/HttpArena/pull/1568): "You need to use a proper
  json parser (for example nlohmann/json) … unless you classify as an engine").
  Up to Plod `v0.5.5`, `plod::format_fields` wrote strings with `http::json_string`
  and integers with `format`; from `v0.5.6` every field but a `u64` goes through
  Goose's `json` writer.
- No HTTP details in the entry ([#1542](https://github.com/MDA2AV/HttpArena/pull/1542):
  "no http details like http headers or parsing logic on the entry"). Up to `v0.5.5`,
  `/echo` answered with `http::respond`, and production-stack added `X-Cache` with
  `http::start`, `http::field`, and `http::finish`; from `v0.5.6` they use
  `plod::bytes` and `plod::json`'s block with `plod::field`.
- Established libraries for TLS and the Postgres driver, or tuned
  ([#998](https://github.com/MDA2AV/HttpArena/pull/998),
  [#1219](https://github.com/MDA2AV/HttpArena/pull/1219)); both comments were on
  engines, and viltrum, experimental and standard, was merged with TLS records of its
  own ([#1605](https://github.com/MDA2AV/HttpArena/pull/1605)).
- Experimental for a new entry, and every scored HTTP/1.1 profile for a framework:
  the entry meets both.
- No pushback anywhere on `-march=native`, which actix, userver, and Aegon use.

Smaller points: the benchmark mounts `/certs` for every profile
(`scripts/lib/framework.sh`), so `server-tls` serves them all, as the entry's README
now says; and goose-postgres `v0.0.6` declared goose-http `v0.5.8`, so the image's
build printed that the entry declares `v0.5.9`, until goose-postgres `v0.0.7`
(2026-10-24), which the entry imports.

### Before h3 joins the entry

The rules (`site/content/docs/test-profiles/h3/`), the scripts, and the h3 entries at
`d9438f6`:

- Standard mode: "the framework native QUIC/HTTP3 support with default
  configuration"; tuned "may tune QUIC parameters, congestion control, and UDP buffer
  sizes". `Listener.h3` and `h3` in the ALPN list turn HTTP/3 on as Aegon's
  `enable_http3(true)` and agensio's `protocols` list do. Anything tuned for the load
  has to be goose-http's documented default, chosen for production, not the entry's.
- QUIC of the server's own is accepted: zix-http3's is Zig on `std.crypto`, agensio's
  its own over OpenSSL's QUIC TLS API.
- static-h3's cache must be the framework's own and follow the disk; `plod::files`
  reads the disk each request, and its `.br` and `.gz` copies come through
  `http::open_precompressed`.
- `validate.sh` publishes `8443/udp` for an h3 entry and sends four requests per
  profile with h2load-h3; the benchmark's readiness probe is curl over TCP 8443, which
  the entry's h2 answers. HttpArena's host sets `rmem_max` and `wmem_max` to 7,500,000
  and loopback's MTU to 1,500 (`scripts/lib/system.sh`); an entry sets no sysctl.
- The load is 64 connections of 64 streams. A per-connection stream limit that isn't
  raised as streams close held one entry to 1.3 K requests a second
  ([#772](https://github.com/MDA2AV/HttpArena/pull/772)); goose-http's credit comes
  back as streams are taken. With 64 workers and `SO_REUSEPORT` hashing 64 clients,
  about a third of the workers get no connection; goose-http has no BPF steering yet.
- Nothing in goose-http task 067's "Not built" list is checked by `validate.sh` or
  exercised by h2load-h3: the h3 routes, `/baseline2` and `/static/*name`, don't wait.

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
7. h3 (asked for 2026-10-24), and gRPC.

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
- [ ] baseline-h3 and static-h3 in the entry, measured against Aegon and zix-http3
