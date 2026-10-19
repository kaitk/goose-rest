# rest-aegon

Aegon serving goose-http's REST tiers A to D and goose-rest's tiers F, R, and M
(`bench/rest/tiers`), for goose-rest's REST benchmark
([docs/benchmarks.md](../../../docs/benchmarks.md), [bench/README.md](../../README.md)).
Each route is registered on Aegon's `Router` or a route group, reads its input through
Aegon's `Request`, and answers through its `Response`; the checks that the Rust servers
make with extractors and middleware are Aegon middleware on the groups and the router.
The records, both JSON ways, and tier D's readers are a port of `bench/rest/rust-app`
to C++ with glaze, Aegon's JSON library.

```sh
REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> \
    [ROUTES=bench/rest/tiers/github.txt] rest-aegon|rest-aegon-small <port>
```

## Build

`bench/rest.sh build` builds both servers on Linux. By hand:

```sh
CXX=g++-16 cmake -S bench/rest/aegon -B "$CACHE/aegon-build" -G Ninja \
    -DFETCHCONTENT_BASE_DIR="$CACHE/aegon-deps" -DCMAKE_PREFIX_PATH="$CACHE/aegon-prefix"
cmake --build "$CACHE/aegon-build"
```

The CMake project fetches Aegon at `8500057` (its `main` on 2026-10-19) and glaze
`v9.0.0`, the version Arch Linux packages, which HttpArena's entry builds with. It
builds only the Aegon libraries the servers link, and installs nothing.

Aegon's HTTP library links its HTTP/2 and HTTP/3 code, though the servers serve HTTP/1.1
alone, so its build needs:

- GCC 16: Aegon calls `unordered_map::erase` with a `string_view`, a C++23 overload that
  GCC 15's libstdc++ lacks. Ubuntu 26.04's `g++-16` is a snapshot of GCC 16
  (16-20260322). `AEGON_CXX` names another compiler.
- ngtcp2 1.25.0, which `bench/rest.sh build` builds into `CACHE/aegon-prefix`, as a
  static library: Aegon calls `ngtcp2_conn_get_tls_alert2` and other functions newer
  than Ubuntu's ngtcp2 1.16.
- liburing, OpenSSL, nghttp2, nghttp3, libdeflate, and jemalloc from the distribution
  ([development.md](../../../docs/development.md#benchmarks) has the packages).

## Configuration

The configuration follows HttpArena's Aegon entry (MDA2AV/HttpArena `d6659a8`, read on
2026-10-19: `frameworks/aegon/main.cpp`, `CMakeLists.txt`, and `Dockerfile`), which builds
Aegon `e649022`. Taken from the entry:

- C++26, `-O3 -march=native`, a Release build.
- `Server::run(threads)`: a thread per worker, each with its own io_uring event loop and
  its own `SO_REUSEPORT` listener, pinned by Aegon to one of the CPUs the process may run
  on. Aegon has no setting that leaves the threads unpinned, so `AFFINITY=0` doesn't
  apply. The entry counts the CPUs from the cgroup quota and the affinity mask; this
  server takes `WORKERS`.
- `rest-aegon`: the entry's settings for an unlimited memlock limit, 8,192 ring entries
  and 16,384 provided buffers of 4 KB per thread. Aegon maps the buffers with
  `MAP_POPULATE`, from 2 MB huge pages when the pool has them, so each thread holds 64 MB
  from the start. `bench/rest.sh` raises the memlock limit to unlimited, as HttpArena's
  container has it, so that Aegon can register the buffers with io_uring; `env.txt`
  records the limit and `vm.nr_hugepages`, since pages from the huge-page pool aren't
  in VmRSS.
- `rest-aegon-small`: the entry's settings for a memlock limit under 64 MB, 512 ring
  entries and 256 buffers per thread, to show what the larger buffers buy in rate.
- jemalloc, which the entry preloads with `LD_PRELOAD`; here it's linked.

Not taken: the entry's TLS, HTTP/2, and HTTP/3 listeners, and its `Compress`
middleware, which only its JSON route uses.

Aegon is at its `main` of 2026-10-19 rather than the entry's `e649022`, 33 commits
older, as the Rust servers take their current releases. The request body limit is
Aegon's default, 16 MB, set explicitly.

## Routes

Each tier's file registers its routes in `routes()`, and `main.cpp` registers the
tier's: tier D serves tier C's beside its own, and tier M tier A's behind its
middleware.

- **Paths no route takes**, and methods a route lacks, answer through the router's
  not-found and method-not-allowed handlers, with the 404 of the tier whose prefix the
  path has: snowtime's under `/api/v1`, the clinic's under `/api/v2` and `/api/v3`,
  and an empty 404 elsewhere.
- **Tier F**: `GET /`, `GET /id/:id` with the `name` query value decoded by
  `Request::url_decode`, and `POST /json`, which reads the body into a `glz::generic`,
  whose objects keep their members in order, and writes it back.
- **Tier R**: each line of `github.txt` on the router, as it is written: Aegon's
  patterns use `:param` too. Each handler holds its route's number and parameter names,
  and reads the values with `Request::param`.
- **Tier M**: the router's global middleware, which Aegon runs for every request, the
  ones no route takes included, outermost first: a timing middleware that sets
  `Server-Timing`, Aegon's `cors` for `https://app.example` with methods `GET, POST`
  and headers `Authorization, Content-Type`, and a bearer check answering 401.

- **Tier B**: a group at `/api/v1` whose middleware answers 403 to a write from
  another origin. The sign-in, by the session cookie through `Request::cookie`, and the
  organization's membership are checked by wrappers around the handlers, since
  `GET /session` answers null to no one. Only `from`, `to`, and `userId` are
  percent-decoded, as goose-http's entry decodes them. Bodies are read into a
  `glz::generic`.
- **Tier C**: a group at `/api/v2` whose middleware checks the bearer token, so that a
  path or method no route takes is a 404 first, through the fallback.
- **Tier D**: a group at `/api/v3` behind the same check. Each route checks its media
  type, then its limit on the declared length and on the body. The CSV reader, a port
  of Goose's, takes the body in one piece, and the multipart body goes through Aegon's
  `MultipartParser`, after a check for its close delimiter, which the parser doesn't
  require. Aegon reads every body whole before a route runs, up to the server's 16 MB.

## Tier D isn't measured

The run leaves Aegon out of tier D, as goose-http's `bench/rest.sh` says in `no_d`, and
`bench/rest.sh check` skips it. Aegon reads a body whole before a route runs, and its
only early refusal is the server's 16 MB limit. A batch that declares more than its
route's 1 MB and never sends the body gets no answer, where `check.py` wants a 413 at
once. Aegon has no hook before the body is read.

The rest of `check.py`'s tier D passes. Aegon is also slow on large chunked bodies: its
HTTP/1 parser decodes the whole buffered body again on every receive, so an 8 MB
chunked import took 2.57 s, against 0.04 s with `Content-Length`.

## Differences from what the checkers and the other servers expect

goose-http's `check.py` passes on tiers A to C, and goose-rest's
`bench/rest/tiers/check.py` on F, R, and M. None of their requests reaches the
differences below.

| Request | Expected | rest-aegon | Why |
|---|---|---|---|
| `HEAD` on a `GET` route | goose-http's entry takes `HEAD` as `GET` on tiers B and C | The tier's 404 | Aegon routes `HEAD` only where a route registers it. |
| A method a path's route lacks | The tier's 404 | The tier's 404, with an `Allow` field | Aegon sets `Allow` before it calls the method-not-allowed handler. |
| A path with a trailing slash, such as `/api/me/` | 404 | The route's answer | Aegon's router drops one trailing slash before it matches. |
| A repeated query key | goose-http's entry takes the first; ntex's `Query` refuses it | The first | `Request::query_param` returns the first. |
| An escaped `includeArchived`, such as `%74rue` | goose-http's entry reads it raw; ntex's `Query` decodes it | Read raw, so 400 | Tier B decodes only what goose-http's entry decodes. |
| Tier C: a query value with a bad escape, such as `%zz`, or a `+` | 400 for a bad escape | The escape kept as written, and `+` as a space | `Request::url_decode` is lenient. |
| A session cookie in a second `Cookie` field | goose-http's entry reads up to 8 fields | Not found, so 401 | `Request::cookie` reads the first `Cookie` field. |
| A JSON body that repeats a member | serde refuses it | The last value | glaze keeps one value per key. |
| A 413 | The connection closed | `Connection: close` sent, and the connection kept | Aegon closes only for a request's `Connection: close` or HTTP/1.0, not a handler's field. |
| Tier D: a multipart part without a `name` | 400 | The part left out | Aegon's `MultipartParser` skips it. |
| Tier M: a path no route has, without a token | 404 | 401 | The bearer check is global, so it runs before the not-found handler. |
| Tier F: `POST /json` with a body that isn't JSON | Not in the spec | 400, empty | |

## Verification

On the benchmark desktop (AMD Ryzen 7 5800X3D, WSL2 Ubuntu 26.04.1, kernel
6.18.54.1-microsoft-standard-WSL2), with GCC 16-20260322 and the build of 2026-10-19,
`WORKERS=4`, and memlock unlimited. `bench/rest.sh check` passed `rest-aegon` and
`rest-aegon-small` on tiers A to C, both JSON ways, and on F, R (all 203 routes), and M.

3 s wrk smoke runs at `-t2 -c16` on tiers B and C counted no socket error and no status
but 2xx. Tier D's forms role counted about one 422 in seven, as `tier-d.lua` expects; its
uploads role, beside it at `-t1 -c4`, managed 10 requests a second with 2 timeouts, from
the chunked bodies above. These were smoke tests, not measurements.
