# 008: The generated router

Status: done (2026-10-13)

Task 007 showed the if chain's cost matters (decided 2026-10-13). The generator writes
`dispatch` from the document's paths ([reference](../docs/generator.md#paths)).

## Acceptance criteria

- [x] Static paths by length, then bytes; paths with parameters by segment
- [x] A security check only in the operations that name its scheme
- [x] 404, 405, and `Allow` the same as the if chain's, tested on one document both ways
- [x] Instructions per request measured as in task 007

## What was built

`gen/gen.goose` reads `paths` against the subset, and `gen/router.goose` writes
`dispatch`: a `match path.len` over the static paths when the path has no `%`, then a
trie over segments, literals before a parameter, whose branches fall through when they
don't answer. Each operation runs inside `rest::route`: the security check, each path
parameter parsed and bounded, the JSON body read with its generated reader, then the
handler. `runtime.goose` gained what the router calls: `segment`, `segment_is`,
`path_int`, `fail_param`, `no_method`, `no_route`, and `not_found`.

`test/gen/routes.json` holds task 007's 60 routes. `test/test_router.goose` compares
the generated router with a flat `http::on` chain of the same routes byte for byte, for
each of 51 paths with each of 7 methods (but `POST /v1/projects`, whose body only the
generated router reads), plus an unknown method and `OPTIONS *`: all 358 answers are the
same. Then the router's own answers: 401 from the security check, 400 for
a parameter out of bounds or not an integer, 415 and 400 for the body, and the case
where a concrete path wins over a template. `test/test_generator.goose` checks the 23
refusals for paths.

## Results (2026-10-13)

Measured as in task 007, in the same run as its servers: MacBook Pro, Apple M1 Pro,
macOS 26.3.1 (Darwin 25.3.0), on battery, load average 4.9-6.1 from other work. Goose
`a6249a4`, goose-http `cfb9c02`, the servers at `fbecf8c`, built with `goose build
--standalone` (Apple clang 21, `-O2`), serving with `http::serve_epoll` over kqueue, one
worker. `bench/routes.sh`: h2load 1.70.0 `--h1 -n 2000000 -c 256 -m 16 -t 8` with
`count.sh`'s headers, on the same machine, nothing pinned; the server's instructions
retired from `/usr/bin/time -l`, kernel included, divided by the requests. 3 rounds,
interleaving the servers. Instructions per request, ranges over the rounds:

| Case | Generated (`gen60`) | If chain (`routes60`) | One route | Generated over one route | Chain over one route |
|---|---:|---:|---:|---:|---:|
| First route | 18,181.1-18,193.4 | 18,278.7-18,301.3 | 18,253.9-18,257.9 | -61 to -77 | +25 to +47 |
| Last route | 19,819.3-19,834.7 | 25,858.0-25,859.6 | 19,849.0-19,856.4 | -19 to -33 | +6,003 to +6,011 |
| 404 in a scope | 19,642.5-19,660.2 | 25,436.6-25,437.4 | 19,460.9-19,478.1 | +164 to +199 | +5,959 to +5,977 |
| 404 outside | 18,505.8-18,525.8 | 18,290.9-18,298.0 | 18,145.0-18,158.0 | +348 to +379 | +140 to +146 |
| 405 | 19,994.6-20,002.2 | 25,788.3-25,789.4 | 19,750.3-19,765.8 | +229 to +251 | +6,024 to +6,039 |

Each difference pairs a round's two servers.

Cycles per request at the last route: generated 4,828.3-4,837.3, chain 6,031.6-6,060.8,
one route 4,787.6-4,829.8. The one worker served 571,473-573,815 requests a second
through the generated router, 499,118-500,341 through the chain, and 569,016-575,635
with one route.

The generated router costs what one route costs, at the first route and the last,
where the chain costs 6,000 more at the last. It does more than either server besides
routing: it calls the session check and parses and bounds `id`. Its 404 and 405 carry
the JSON error body, 21 to 30 bytes that the others don't send, and cost 160 to 380
instructions more than one route with it. The chain's 404 in a scope and its 405 cost
the same 6,000 as its last route; its 404 outside every scope costs 140.

A first run had `dispatch` end in `rest::no_route`, which checks the method and scans the
path for dot-segments again after `dispatch` already had: 404s cost 580 more than now.
It ends in `rest::not_found`.

## Found on the way

- The checker gave up on a loop calling the operation loader, which rebound an optional
  reference with `.=` inside `json::each` blocks
  (aardappel/goose#32, fixed in `c0e2297`).
  Looking the parameter up by index instead let it settle.
- Storing a `json::Node?` from a parameter's schema in the generator's tables was
  refused for `test_generator.goose`'s instantiation of `generate` ("storing a
  reference rooted at n, which does not outlive the destination") and accepted for
  `gen/main.goose`'s. Not reduced to a minimal program yet; the tables keep the bounds
  as integers instead.
