# dusty-routes

`dusty-routes` serves goose-http's task 021 REST tiers A to D, and goose-rest's tiers F,
R, and M (`bench/rest/tiers/`), on dusty, with a route per path on dusty's router, for
task 010. It starts from goose-http's `bench/rest/dusty` (the catch-all `dusty` entry):
its records, its handlers, its multipart reader, and its pins, dusty `ae164fa`, zio
0.19.1, and Zig 0.16.0. The Zig project is `rest_dusty_routes`; the binary keeps the
name `rest-dusty`, so goose-http's `bench/rest.sh` starts either the same way:

    REST_DATA=<dir> TIER=a|b|c|d|f|r|m JSON=serialize|template WORKERS=<n> rest-dusty <port>

Tiers F and R load no dataset. Tier M loads tier A's.

## Build

Zig 0.16 fetches packages into `zig-pkg/` beside `build.zig.zon`, so build from a copy,
as goose-http's `bench/rest.sh` builds its entry, with the caches outside the copy:

    cp -r bench/rest/dusty/. "$CACHE/app-rest-dusty-routes/"
    cd "$CACHE/app-rest-dusty-routes"
    zig build --cache-dir "$CACHE/zig-cache" --global-cache-dir "$CACHE/zig-global" \
        --prefix "$CACHE/rest-dusty-routes-out" --release=fast \
        -Dgithub="$REPO/bench/rest/tiers/github.txt" [-Dtarget=... -Dcpu=...]

Tier R's routes are compiled in from `github.txt`. `-Dgithub` names it, and defaults to
`../tiers/github.txt` beside `build.zig`, which a copy outside the repository lacks.

On Linux, pass the target and CPU `bench/rest.sh` passes: `x86_64-linux-musl` with
`x86_64_v3+aes+pclmul+adx`, or `aarch64-linux-musl` with `native` (`apple_m1` on Apple
silicon). On macOS, build for the native target. `.gitignore` covers an in-place build.

## How a request goes through dusty

- **Routes.** Each tier's module lists its routes in a table of method, path, and dusty
  handler, with path parameters in dusty's syntax (`/clients/:id/encounters`).
  `main.zig` mounts the tables of the tier it serves with `router.group(prefix,
  middleware)`: tiers A, M, F, and R at `/`, tier B at `/api/v1`, tier C at `/api/v2`, and
  tier D at `/api/v2` and `/api/v3`. A server registers only its tier's routes.
- **Tier R's 203 routes** are made at compile time: the build embeds `github.txt` in a
  generated module, and `micro.zig` parses it at compile time into a table with a
  handler per line. Each handler has its route's number and parameter names built in,
  and reads the values from `req.params`.
- **Handlers.** Tiers A to D's handlers take dusty's `Request` and return the tier's
  response, which `rest.route` wraps into a dusty handler that writes it into dusty's
  `Response`. That tier logic is goose-http's entry's. Tiers F and R write the `Response`
  as dusty's own handlers do, with `content_type = .text` and `Response.json`.
- **Parameters, query, and fields.** Handlers read `req.params`, `req.query` (parsed and
  decoded by dusty's router), `req.headers`, and the session cookie through
  `req.cookies()`.
- **Middleware**, through dusty's `Middleware` and `server.middleware`:
  - `Stamp` adds `Server` and `Date` to every response the router reaches, 404s
    included, as router-global middleware.
  - `heavy.Bearer` answers 401 without a bearer token of three base64url segments, on the
    `/api/v2` and `/api/v3` groups.
  - `snow.SameOrigin` answers 403 to a write from another origin, on `/api/v1`.
  - Tier M's stack is router-global, after `Stamp`, outermost first: `micro.Timing`
    (`Server-Timing: app;dur=<ms>`, the time the rest of the stack and the handler
    took), dusty's own `middleware.Cors` for `https://app.example` (methods `GET, POST`,
    headers `Authorization, Content-Type`), and `micro.Bearer` (401 without
    `Authorization: Bearer <token>`). It's global so that a preflight, which has no route,
    reaches `Cors`, and a 404 gets its `Server-Timing`.
- **Not found.** dusty calls the context's `notFound` for a request no route takes,
  after the global middleware. `App.notFound` answers in the shape of the path's tier:
  tier B's `{"error":{"message":"No such call."}}`, tiers C and D's
  `{"error":"not_found","status":404}`, or an empty 404 for the other tiers. dusty has
  no 405: a path routed for another method gets the same 404, which is what `check.py`
  expects.
- **Handler errors**, such as running out of memory, get dusty's default 500. The
  context defines no `uncaughtError`.
- **Bodies.** Tiers A, B, M, and F's `/json` read a body whole with `Request.body`, up to
  the server's `max_body_size` of 16 MB. A declared length over it is answered 413
  before the read, since `Request.body` would wait for the whole declared length. Tier
  D's CSV and multipart bodies are read as they arrive through `Request.reader`, which
  undoes chunked framing. Its batch and form are read whole through the same reader,
  with `allocRemaining` limited to 1 MB and 64 KB. dusty's `formData` and
  `multiFormData` aren't used: both take a whole body into a hash map, which loses the
  order and repeats the answers list, `formData` takes at most 32 fields where the forms
  have 50 to 100, and `multiFormData` keeps no file size or checksum. `Content-Type` is
  checked against the route's media type by name, since dusty's `ContentType` has no
  `text/csv`.
- **Tier F's `/json`** parses the body with `std.json.parseFromSliceLeaky` into a
  `std.json.Value`, whose objects keep their members' order, and writes it back with
  `Response.json`, which is `std.json.Stringify`. dusty's `Request.jsonValue` does the
  same parse, but answers a body it can't read and one that isn't JSON through the same
  error.
- **413 from the head.** The handler sends a 413 itself with `Response.write` and
  closes. After a handler returns, dusty drains an unread body of a known length up to
  `max_body_size` before it sends the response, and a peer may never send a body refused
  for its length.
- **Early answers.** A tier D answer before the body's end (415, or a multipart 400) is
  sent after the handler reads and drops the rest of the body. `discardRemaining` on
  dusty's body reader doesn't return once the body has ended, as goose-http's task 021
  records.

Tiers A to D's responses carry `Content-Type: application/json`, set as a field as
goose-http's entry sets it. Tiers F and R's carry dusty's `text/plain; charset=UTF-8`
and `application/json; charset=UTF-8`.

## What differs from the catch-all entry besides routing

Task 010 pairs this entry with goose-http's catch-all `dusty` to price dusty's router.
Besides the router, the two differ in:

- **Middleware dispatch.** `Server` and `Date`, tier B's origin check, and tiers C and
  D's bearer check run as dusty middleware here, and inline in the catch-all's handler.
- **Query and cookie parsing.** Handlers here read dusty's parsed and decoded query and
  dusty's cookie reader. The catch-all's router parses the query too, and its handler
  then parses the raw query and the `Cookie` fields again.
- **Tier D's batch and form**, read with `allocRemaining` on dusty's body reader here,
  and by a loop over pieces in the catch-all.
- **Tiers A and B's 413**, answered from a declared length before the read here; the
  catch-all waits for the declared body (see the table).

The JSON writing, the records, and the CSV and multipart readers are the same.

## Differences from what the checkers and the other servers expect

goose-http's `check.py` passes on tiers A to D, and goose-rest's `bench/rest/tiers/check.py`
on F, R, and M. None of their requests reaches the differences below. They come from
dusty acting before a handler runs, from dusty's readers and its `Cors`, or from tier M's
stack being global. None can be matched through a dusty hook without a catch-all route.

| Request | Expected | dusty-routes | Why |
|---|---|---|---|
| A query with a bad percent-escape, such as `staff=1%zz` | Tier B: 400 `{"error":{"message":"Invalid input."}}`; tier C: 400 `{"error":"bad_request","status":400}`; tier M: `Server-Timing` on every answer | 400 with no body, no `Server`, `Date`, `Server-Timing`, or CORS field, and the connection closed | dusty's router decodes the whole query before route lookup and answers the error itself, before any middleware. goose-http's catch-all entry sends the same. |
| A query with more than 32 parameters | The route's answer | The same bare 400 | dusty's `max_query_count` defaults to 32. It's configurable; the entry keeps dusty's default. |
| An escaped or `+` query value, such as `since=%31` or `limit=+5` | goose-http's entry decodes only tier B's `from`, `to`, and `userId` and tier C's `staff`, and never `+` | Every key and value decoded, `+` as a space: `since=%31` is 1, and `limit=+5` is a 400 | dusty's query parser decodes all of it. |
| A repeated query key | goose-http's entry takes the first | The last | dusty's query map overwrites. |
| A path with empty segments, such as `/api/v2//clients//1` | 404 | The route's answer | dusty's router skips empty segments. |
| `HEAD` on a tier A route | 404 in goose-http's entry, which takes `HEAD` as `GET` on tiers B and C only | The `GET` route's head | dusty answers `HEAD` with the `GET` route. |
| A session cookie in a second `Cookie` field, or quoted | goose-http's entry reads up to 8 fields and unquotes | Not found, or the quotes kept | dusty's cookie reader reads the first `Cookie` field. |
| A tier D request without a token, sent chunked | 401, the body read, the connection kept | 401, the connection closed | `Bearer` doesn't read the body. dusty drains one of a known length and closes for a chunked one. `check.py` sends its 401s with a length. |
| A tier A, B, or M body over 16 MB that the route refuses anyway (an unknown item, no sign-in, another origin, or no membership) | 413 in goose-http's entry, which reads the body first | The refusal: 404, 401, or 403 | The handler reads the body after the middleware and its own checks. |
| A tier A or B request declaring more than 16 MB, without sending it | goose-http's entry waits for the declared body | 413 at once, the connection closed | `Request.body` reads up to `max_body_size`, which a peer that sends less never reaches; the entry checks the declared length first. |
| Tier M: a 413 for a declared length over 16 MB | `Server-Timing` on every answer | No `Server-Timing` | The handler sends the 413 before `Timing` adds the field. |
| Tier M: a path no route has, without a token | 404 | 401 | The bearer check is global, so it runs before dusty's not-found. A preflight to such a path is 204. |
| Tier M: any answer, with or without `Origin` | `Access-Control-Allow-Origin` for `https://app.example` when it sent that origin | `Access-Control-Allow-Origin: https://app.example` and `Vary: Origin` on every answer, and a preflight from any origin answered 204 with the configured methods and headers | dusty's `Cors` doesn't compare the request's `Origin` or the requested method and headers. |
| Tier F: `POST /json` with an object that repeats a member | Bun's `JSON.parse` keeps the last value | The last value | Set with `duplicate_field_behavior = .use_last`; `std.json` refuses a repeat by default. |
| Tier F: `POST /json` with a body that isn't JSON | Not in the spec | 400, empty | |
| Tier F: `GET /id/1` without `name` | Not in the spec | `1 ` | A missing `name` is read as empty. |

## Verification

On a Mac (Apple M1 Pro, 10 cores, macOS 26.3.1), with Zig 0.16.0 for `aarch64-macos`
from ziglang.org, its SHA-256 matching ziglang.org's `index.json`. Its minisign
signature wasn't checked, for want of `minisign`. dusty and zio 0.19.1 build and run on
macOS's kqueue. The build was native, `--release=fast`, from a copy outside the
repository. Every run below used `WORKERS=4` and the build of 2026-10-14.

goose-http's `check.py PORT DATADIR TIER`, on goose-http `e27ab21`'s datasets, passed
every run:

| Server | JSON=serialize | JSON=template |
|---|---|---|
| `TIER=a`, check a | ok | ok |
| `TIER=b`, check b | ok | ok |
| `TIER=c`, check c | ok | ok |
| `TIER=d`, check d | ok | ok |
| `TIER=d`, check c | ok | not run |

goose-rest's `bench/rest/tiers/check.py PORT TIER DATADIR` passed for `TIER=f`, `TIER=r`
(all 203 routes and the two 404s), and `TIER=m`.

A 3 s wrk 4.2.0 run of each script counted no socket error, and no status but those
expected:

- Tiers A to C (`wrk -t2 -c16 -d3 -s tier-X.lua URL -- DATADIR`): 2xx only.
- Tier D's `uploads` role at `-t1 -c4` beside its `forms` role at `-t2 -c16`: 2xx and
  tier D's 422s, about the seventh of the forms role's responses that `tier-d.lua`
  expects.
- Tier F's `root`, `id`, and `json` (`-t2 -c16 -d3 -s tier-f.lua URL -- ROUTE`), tier R
  (`-- github.txt`), and tier M: 200 and 204 only.

Each script ran as a copy with a `response` hook that reported any status but 200, 201,
204, and 422 (200 and 204 for F, R, and M). It reported none.

These were smoke tests on a laptop, not measurements.
