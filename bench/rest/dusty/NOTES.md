# dusty-routes

`dusty-routes` serves goose-http's task 021 REST tiers A to D on dusty, with a route per
path on dusty's router, for task 010. It starts from goose-http's `bench/rest/dusty` (the
catch-all `dusty` entry): its records, its handlers, its multipart reader, and its pins,
dusty `ae164fa`, zio 0.19.1, and Zig 0.16.0. The Zig project is `rest_dusty_routes`; the
binary keeps the name `rest-dusty`, so goose-http's `bench/rest.sh` starts either the
same way:

    REST_DATA=<dir> TIER=a|b|c|d JSON=serialize|template WORKERS=<n> rest-dusty <port>

## Build

Zig 0.16 fetches packages into `zig-pkg/` beside `build.zig.zon`, so build from a copy,
as goose-http's `bench/rest.sh` builds its entry, with the caches outside the copy:

    cp -r bench/rest/dusty/. "$CACHE/app-rest-dusty-routes/"
    cd "$CACHE/app-rest-dusty-routes"
    zig build --cache-dir "$CACHE/zig-cache" --global-cache-dir "$CACHE/zig-global" \
        --prefix "$CACHE/rest-dusty-routes-out" --release=fast [-Dtarget=... -Dcpu=...]

On Linux, pass the target and CPU `bench/rest.sh` passes: `x86_64-linux-musl` with
`x86_64_v3+aes+pclmul+adx`, or `aarch64-linux-musl` with `native` (`apple_m1` on Apple
silicon). On macOS, build for the native target. `.gitignore` covers an in-place build.

## How a request goes through dusty

- **Routes.** Each tier's module lists its routes in a `routes` table of method, path,
  and handler, with path parameters in dusty's syntax (`/clients/:id/encounters`).
  `main.zig` mounts the tables of the tier it serves with `router.group(prefix,
  middleware)`: tier A at `/`, tier B at `/api/v1`, tier C at `/api/v2`, and tier D at
  `/api/v2` and `/api/v3`. A server registers only its tier's routes. Another tier is a
  new table and a line in `main.zig`.
- **Handlers.** A handler takes dusty's `Request` and returns the tier's response, which
  `rest.action` writes into dusty's `Response`. The tier logic is goose-http's entry's.
- **Parameters, query, and fields.** Handlers read `req.params`, `req.query` (parsed and
  decoded by dusty's router), `req.headers`, and the session cookie through
  `req.cookies()`.
- **Middleware**, through dusty's `Middleware` and `server.middleware`: `Stamp` adds
  `Server` and `Date` to every response the router reaches, 404s included, as
  router-global middleware. `heavy.Bearer`
  answers 401 without a bearer token, on the `/api/v2` and `/api/v3` groups.
  `snow.SameOrigin` answers 403 to a write from another origin, on `/api/v1`.
- **Not found.** dusty calls the context's `notFound` for a request no route takes,
  after the global middleware. `App.notFound` answers in the shape of the path's tier:
  tier B's `{"error":{"message":"No such call."}}`, tiers C and D's
  `{"error":"not_found","status":404}`, or tier A's empty 404. dusty has no 405: a path
  routed for another method gets the same 404, which is what `check.py` expects.
- **Handler errors**, such as running out of memory, get dusty's default 500. The
  context defines no `uncaughtError`.
- **Bodies.** Tiers A and B read a body whole with `Request.body`, up to the server's
  `max_body_size` of 16 MB, and answer 413 past it. Tier D's CSV and multipart bodies are
  read as they arrive through `Request.reader`, which undoes chunked framing. Its batch
  and form are read whole through the same reader, with `allocRemaining` limited to 1 MB
  and 64 KB. dusty's `formData` and `multiFormData` aren't used: both take a whole body
  into a hash map, which loses the order and repeats the answers list, `formData` takes
  at most 32 fields where the forms have 50 to 100, and `multiFormData` keeps no file
  size or checksum. `Content-Type` is checked against the route's media type by name,
  since dusty's `ContentType` has no `text/csv`.
- **413 from the head.** For a declared `Content-Length` over the route's limit, the
  handler sends 413 itself with `Response.write` and closes. After a handler returns,
  dusty drains an unread body of a known length up to `max_body_size` before it sends
  the response, and a peer may never send a body refused for its length.
- **Early answers.** A tier D answer before the body's end (415, or a multipart 400) is
  sent after the handler reads and drops the rest of the body. `discardRemaining` on
  dusty's body reader doesn't return once the body has ended, as goose-http's task 021
  records.

Responses carry `Content-Type: application/json`, set as a field as goose-http's entry
sets it. dusty's `content_type = .json` would add `; charset=UTF-8`.

## Differences from goose-http's entry and check.py

`check.py` passes on every tier. None of its requests reaches the differences below.
They come from dusty acting before a handler runs, or from dusty's readers, and none can
be matched through a dusty hook without a catch-all route.

| Request | Expected | dusty-routes | Why |
|---|---|---|---|
| A query with a bad percent-escape, such as `staff=1%zz` | Tier B: 400 `{"error":{"message":"Invalid input."}}`; tier C: 400 `{"error":"bad_request","status":400}` | 400 with no body, no `Server` or `Date`, and the connection closed | dusty's router decodes the whole query before route lookup and answers the error itself. `notFound` and `uncaughtError` run later. goose-http's catch-all entry sends the same. |
| A query with more than 32 parameters | The route's answer | The same bare 400 | dusty's `max_query_count` defaults to 32. It's configurable; the entry keeps dusty's default. |
| An escaped or `+` query value, such as `since=%31` or `limit=+5` | goose-http's entry decodes only tier B's `from`, `to`, and `userId` and tier C's `staff`, and never `+` | Every key and value decoded, `+` as a space: `since=%31` is 1, and `limit=+5` is a 400 | dusty's query parser decodes all of it. |
| A repeated query key | goose-http's entry takes the first | The last | dusty's query map overwrites. |
| A path with empty segments, such as `/api/v2//clients//1` | 404 | The route's answer | dusty's router skips empty segments. |
| `HEAD` on a tier A route | 404 in goose-http's entry, which takes `HEAD` as `GET` on tiers B and C only | The `GET` route's head | dusty answers `HEAD` with the `GET` route. |
| A session cookie in a second `Cookie` field, or quoted | goose-http's entry reads up to 8 fields and unquotes | Not found, or the quotes kept | dusty's cookie reader reads the first `Cookie` field. |
| A tier D request without a token, sent chunked | 401, the body read, the connection kept | 401, the connection closed | `Bearer` doesn't read the body. dusty drains one of a known length and closes for a chunked one. `check.py` sends its 401s with a length. |
| A tier A or B body over 16 MB that the route refuses anyway (an unknown item, no sign-in, another origin, or no membership) | 413 in goose-http's entry, which reads the body first | The refusal: 404, 401, or 403 | The handler reads the body after the middleware and its own checks. |

The pair differs in more than routing: tier D's bearer check and tier B's origin check
run as dusty middleware here, and the batch and form are read with `allocRemaining`
rather than a loop over pieces. The JSON and the records are the same.

## Verification (2026-10-13)

On a Mac (Apple M1 Pro, 10 cores, macOS 26.3.1), with Zig 0.16.0 for `aarch64-macos`
from ziglang.org, its SHA-256 matching ziglang.org's `index.json`. Its minisign
signature wasn't checked, for want of `minisign`. dusty and zio 0.19.1 build and run on
macOS's kqueue. The build was native, `--release=fast`, from a copy outside the
repository.

`check.py PORT DATADIR TIER` against servers with `WORKERS=4`, on goose-http `e27ab21`'s
datasets, passed every run:

| Server | JSON=serialize | JSON=template |
|---|---|---|
| `TIER=a`, check a | ok | ok |
| `TIER=b`, check b | ok | ok |
| `TIER=c`, check c | ok | ok |
| `TIER=d`, check d | ok | ok |
| `TIER=d`, check c | ok | not run |

A 3 s wrk 4.2.0 run of each tier's script (`wrk -t2 -c16 -d3 -s tier-X.lua URL -- DATADIR`;
tier D's `uploads` role at `-t1 -c4` beside its `forms` role at `-t2 -c16`) counted no
socket error, and no status but 2xx and tier D's 422s, about the seventh of the forms
role's responses that `tier-d.lua` expects. A copy of `tier-d.lua` with a `response`
hook confirmed no status but 200, 201, and 422. This was a smoke test on a laptop, not a
measurement.
