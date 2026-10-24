# rest-viltrum

viltrum (V) serving goose-http's REST tiers A to D and Plod's tiers F, R, and M
(`bench/rest/tiers`), for Plod's REST benchmark
([docs/benchmarks.md](../../../docs/benchmarks.md), [bench/README.md](../../README.md)).
Each route is registered on viltrum's `App` or a group, reads its input through
viltrum's `Ctx`, and answers through it; the checks that the Rust servers make with
extractors and middleware are viltrum middleware on the groups and the `App`. The
records and both JSON ways are a port of `bench/rest/rust-app`, by way of the Aegon
server's C++.

```sh
REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> \
    [ROUTES=bench/rest/tiers/github.txt] rest-viltrum <port>
```

## Build

`bench/rest.sh build` builds it on Linux: it downloads V's 0.5.2 release and clones
viltrum at `v1.5.1` into its cache, and needs `curl`, `unzip`, `git`, and GCC. By hand,
with viltrum cloned into `$VMODULES/viltrum`:

```sh
VMODULES=<dir> v -prod -cflags -march=native -o rest-viltrum bench/rest/viltrum
```

viltrum serves on Linux only: its engine is epoll, and off Linux `listen` returns an
error. On a Mac, build and check it in an arm64 Linux container with V's
`v_linux_arm64.zip`.

## Configuration

The configuration follows HttpArena's viltrum entry (MDA2AV/HttpArena `d9438f6`, read
on 2026-10-24: `frameworks/viltrum/main.v` and `Dockerfile`), which builds viltrum
`v1.3.2` with V 0.5.2. Taken from the entry:

- `v -prod`, which compiles V's C output with `-O3` and `-flto`, and V's default Boehm
  GC.
- viltrum's default engine: one `SO_REUSEPORT` epoll worker per CPU, each with its own
  listener; `WORKERS` sets `Options.workers`, and without it viltrum counts the CPUs in
  the affinity mask. viltrum doesn't pin its workers.
- Records captured by the handlers' closures behind a pointer, with only scalars local
  to a handler, as the entry keeps its dataset: under `-prod`, V pins each local struct
  or array of pointers around each call, and past 32 pointers takes the GC's global
  lock (viltrum's `docs/request-response.md`, "Handlers and -prod").

Departures from the entry:

- viltrum at `v1.5.1`, its latest release, as the Rust servers take their current
  releases; V stays at 0.5.2, the release viltrum's CI pins.
- `-cflags -march=native`, the CPU target the other servers take.
- `Options.limits.max_body_bytes` at 16 MB, as the Aegon server sets, for tier D's
  uploads; viltrum's default is 1 MB.

### JSON

viltrum's own encoder, `Ctx.json`, writes each struct field under its V name. V field
names can't hold capitals, and the encoder has no option type, so it can't write
`servedAt` or a `null`, which every tier's answers have. The answers are written by
V's `x.json2` instead, whose `json` attribute names a key and `json_null` writes a
`none` as `null`, and sent with `Ctx.bytes`. Bodies and the datasets are read with
`json2.decode`. JSON=template splices the per-request values into each record's JSON,
written once by `x.json2` at startup.

## Routes

Each tier's file registers its routes, and `main.v` the tier's: tier D serves tier C's
beside its own, and tier M tier A's behind its middleware.

- **Paths no route takes**, and methods a route lacks, on tiers A to D: viltrum's `App`
  has no not-found handler to set, so `main.v` registers, after the tier's routes, a
  wildcard route under each tier's prefix for every method, answering the tier's 404:
  snowtime's under `/api/v1`, the clinic's under `/api/v2` and `/api/v3`, and an empty
  404 elsewhere. viltrum's router tries the routes with parameters in the order they're
  registered, so the wildcards come last. Tiers F and R take viltrum's own 404 and 405.
- **Tier B**: a group at `/api/v1` whose middleware answers 403 to a write from
  another origin. The sign-in, by the session cookie, and the organization's membership
  are checked by wrappers around the handlers, since `GET /session` answers null to no
  one. viltrum's `Ctx` has no cookie reader, so the session cookie is found in each
  `Cookie` field through `Ctx.header_values`. The query is read raw from `Ctx.query`,
  and only `from`, `to`, and `userId` are percent-decoded, as goose-http's entry decodes
  them. Bodies are read into an `x.json2` `Any`.
- **Tier C**: a group at `/api/v2` whose middleware checks the bearer token, so that a
  path or method no route takes is a 404 first, through the fallback.
- **Tier D**: a group at `/api/v3` behind the same check. Each route checks its media
  type, then its limit on the declared length and on the body. The CSV reader, a port
  of Goose's, takes the body in one piece, the multipart body goes through
  `Ctx.form_parts`, and the batch through an `x.json2` `Any`. As in the Rust servers, a
  part without a name is a 400, a file needs a filename, and a part without a media
  type is `application/octet-stream`.
- **Tier F**: `GET /`, `GET /id/:id` with the `name` query value from
  `Ctx.query_param`, which decodes it, and `POST /json`, which reads the body into an
  `x.json2` `Any`, whose objects keep their members in order, and writes it back.
- **Tier R**: each line of `github.txt` on the `App`, as it is written: viltrum's
  patterns use `:param` too. Each handler holds its route's number and parameter names,
  and reads the values with `Ctx.param`.
- **Tier M**: the `App`'s global middleware, which viltrum runs for every request, the
  ones no route takes included, outermost first: a timing middleware that sets
  `Server-Timing`, viltrum's `cors` for `https://app.example`, and a bearer check
  answering 401. viltrum writes a response as soon as a handler calls it, so the timing
  middleware sets `Ctx.capture` around `c.next()` and sends the captured response with
  its field, as viltrum's `gzip` middleware does.

## Tier D isn't measured

`bench/rest.sh check` skips viltrum on tier D, as it skips Aegon, and for the same
reason. viltrum reads a body whole before a route runs: its framing applies
`Options.limits`, the server's 16 MB, while it reads the request, and no hook runs
between the head and the body. A batch that declares more than its route's 1 MB and
never sends the body gets no answer, where `check.py` wants a 413 at once. With
`Expect: 100-continue`, viltrum sends `100 Continue` before routing, for the same
reason.

The rest of `check.py`'s tier D passes, the 413s on bodies sent and the closed
connections after them included. Large bodies are quick: an 8 MB import took 0.031 s
with `Content-Length`, 0.035 s in 64 KB chunks, and 0.077 s in 1,500-byte chunks.

## Differences from what the checkers and the other servers expect

goose-http's `check.py` passes on tiers A to C, and Plod's
`bench/rest/tiers/check.py` on F, R, and M. None of their requests reaches the
differences below.

| Request | Expected | rest-viltrum | Why |
|---|---|---|---|
| A path with a trailing slash, or repeated slashes, such as `/api/items/1/` | 404 | The route's answer | viltrum's router drops trailing slashes and skips empty segments before it matches. |
| A repeated query key | goose-http's entry takes the first; ntex's `Query` refuses it | The first | Tier B scans the raw query for the first; `Ctx.query_param` also returns the first. |
| Tier B: an escaped `includeArchived`, such as `%74rue` | goose-http's entry reads it raw; ntex's `Query` decodes it | Read raw, so 400 | Tier B decodes only what goose-http's entry decodes. |
| A JSON body that repeats a member | serde refuses it | The last value | `x.json2`'s `Any` keeps one value per key. |
| A JSON string with invalid UTF-8, such as `"\xff"` | serde refuses it, 400 | Accepted, and written back as sent | `x.json2` doesn't check UTF-8. |
| JSON nested deeper than 128 | 400, serde's recursion limit | Accepted to about 5,000; at 10,000 on tier D's batch, or 20,000 on tier A's write, the process dies of a stack overflow | `x.json2`'s decoder recurses without a limit. |
| Tier D: a number out of range, such as `1e400` | 400 | A 422 field error | `x.json2` reads it as infinity. |
| Tier D: a multipart part whose `Content-Disposition` isn't `form-data`, or is missing | 400 | The part left out | `Ctx.form_parts` skips it. |
| A body over the server's 16 MB | An empty 413 | 413, `text/plain`, "payload too large" | viltrum refuses it before routing. |
| Tier R: a method a path's route lacks | 405 with `Allow` | 405 without `Allow` | viltrum's 405 is a plain-text answer with no `Allow` field. |
| Tier M: a preflight | `Access-Control-Allow-Methods: GET, POST`, `Allow-Headers: Authorization, Content-Type` | `GET, POST, PUT, PATCH, DELETE, OPTIONS` and `Content-Type, Authorization`, for any `OPTIONS` request | viltrum's `cors` takes only the origin. |
| Tier M: any answer | `Access-Control-Allow-Origin` for a request with that `Origin` | `Access-Control-Allow-Origin` on every answer | viltrum's `cors` sets it without reading `Origin`. |
| Tier M: a path no route has, without a token | 404 | 401 | The bearer check is global, so it runs before the not-found answer. |
| Tier F: `POST /json` with an integer past 2^63 | The integer as sent | A float, such as `1.2345678901234567e+19` | `x.json2` reads such a number as an `f64`. |
| Tier F: `POST /json` with a body that isn't JSON | Not in the spec | 400, empty | |

## Verification

In an `ubuntu:26.04` arm64 container on Docker Desktop (Apple M1 Pro), with V 0.5.2
and viltrum `v1.5.1`, `WORKERS=2`, on 2026-10-24: goose-http's `check.py` passed tiers
A to C, both JSON ways, and tier D but for the declared batch above; Plod's
`bench/rest/tiers/check.py` passed F, R (all 203 routes), and M.
