# 047: HttpArena

Status: todo. The plan for entering HttpArena (2026-10-19); the entry comes after task
046's rename.

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
| api-4, api-16; async-db (reference) | `/async-db`: a Postgres range query, through an async driver with a pool of `DATABASE_MAX_CONN` (256) connections. The async-db profile itself is published but not scored | goose-postgres tasks 001 (the protocol, done) and 005 (the pool) |
| gateway-64, gateway-h3, production-stack | `/async-db` again, behind a standard proxy that terminates TLS, h2, and h3. The rules forbid a custom proxy, so the server speaks plaintext HTTP/1.1. In production-stack the shared `authsvc` verifies the JWT at the edge, and the cache can be in-process | goose-postgres task 001; a compose file and an nginx config here |
| echo-ws, echo-ws-pipeline, echo-ws-limited | WebSocket: the handshake, framing, and masking over `rest::upgrade` | goose-http task 054 |
| baseline-h2c, json-h2c | h2 with prior knowledge on port 8082, without TLS | goose-http task 014, phase 4 |
| baseline-h2, static-h2 | h2 over TLS with ALPN on port 8443 | goose-http task 014, phase 5 |
| unary-grpc and three more | gRPC over h2, and protobuf | After h2 |
| baseline-h3, static-h3 | QUIC | Last |

## The entry's tier

`meta.json`'s `type` places a framework in one of three tiers, which grade only how
proven it is in production (`site/content/docs/add-framework/implementation-rules/frameworks/`,
checked 2026-10-19): flagship (real applications built and run on it at scale, actively
maintained), emerging (a genuine, working server, not yet production-proven), and
experimental (very new work, hidden on the leaderboard unless a reader opts in). The
entry picks its tier, and HttpArena's maintainers may change it on review. Aegon entered
as experimental.

The entry asks for emerging (2026-10-19). What makes that case, before the entry goes in:

1. Releases to rely on: tagged versions with a changelog, under the new name (task 046),
   and goose-http's API settled (its task 027).
2. Correctness beyond HttpArena's validation: h2spec passing, the HTTP/1.1 parser and
   HPACK fuzzed, the limits and timeouts documented, and no known crash open.
3. Documentation for writing an application: the tutorial and best-practices guides.

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
   task 001, then api-4, api-16, the two gateway profiles, and production-stack.
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
- [ ] The case for emerging made, as "The entry's tier" lists, and `meta.json` says
      `emerging`
- [ ] The entry runs the six HTTP/1.1 profiles; `validate.sh` passes and the results are
      saved
- [ ] json-tls and 8gbit in the entry, passing HttpArena's TLS checks
- [ ] api-4 and api-16 in the entry
- [ ] gateway-64, gateway-h3, and production-stack in the entry
- [ ] The three WebSocket profiles in the entry
- [ ] The four h2 profiles in the entry
