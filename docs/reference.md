# Reference

goose-rest's middleware, extractors, errors, and test helper: what each call does, what
it gives, and what it answers when it fails. The [tutorial](tutorial/README.md) introduces them
in order, and the [generator reference](generator.md) covers what `goose-rest gen` writes.

## 1. Context and routes

`rest::serve(cfg, app) { cx => handle(cx) };` serves requests with the worker state
by reference in `cx.app`. `rest::serve(cfg, app, fresh)` also starts each request's
`cx.state` from `fresh`. A program with no state can call `rest::serve(cfg)`.
With request state alone, bind `var app = rest::NoState { .. };` and pass it beside
`fresh`. `rest::serve(cfg, app, fresh, limits)` also takes goose-rest's own settings,
a `rest::Config`: its `gather_budget` bounds the bodies a worker gathers at once
([Extractors](#3-extractors)), and the lanes' replies in pieces it collects
([Lanes](#41-lanes)). `rest::serve_epoll` has the same forms.

The context is `rest::Cx<S, A, R>`: the request state, the worker state, and the
router type. Its `req`, `body`, `out`, and `scratch` carry the request and response.
It has `rest::NoRouter` outside a `rest::routes` block, including when a waiting route
resumes. The block receives a context with an `http::Router`:

```rust
rest::routes(cx) { cx =>
    if rest::on(cx, "GET", "/projects/:id") {
        rest::route(cx) { show(cx, rest::param_int(cx, "id")); };
    } else {
        rest::otherwise(cx);
    }
};
```

`routes` builds the router and passes its context by reference; it doesn't open a
`rest::route`. `on`, `scope`, `param`, `param_int`, and `otherwise` require that
router's context, so calls outside the block fail to compile. A typed route helper
can name `type Cx = rest::Cx<St, App, http::Router>;` and take `cx: Cx&`.
The generated `api::dispatch(cx)` works with either context and reads the preceding
routes' `Allow` inside the block. Generated handlers receive path parameters as
arguments; pass those to helpers rather than read the last hand-written match.

`cx.kind` identifies the event the handler is called for: `http::REQUEST` for a request,
and the corresponding event for each later call ([Later calls](#4-later-calls)). `rest::resumed(cx)` is
true for every call after a request's first.

`rest::json` and `rest::json_bytes` answer `application/json`; `rest::text` answers
`text/plain; charset=utf-8`. `rest::empty(cx,
status)` answers without a body: 204 and 304 omit `Content-Length`, and other statuses write
`Content-Length: 0`.

### 1.1 JSON from a struct's fields

`rest::format_fields(out, v)` writes the struct `v` as a JSON object: every field, in
declaration order, keyed by its name as declared. A program's `format` overload calls
it, which `rest::json` then finds:

```rust
fn format(out: u8[>..]&, p: const Project&) { rest::format_fields(out, p); }
```

| Field type | Written as |
|---|---|
| An integer type | a number |
| `f64`, `f32` | a number, by `json::format_number` |
| `bool` | `true` or `false` |
| A `u8` array or slice of any kind (`u8[..64]`, `u8[]`, `u8[16]`, `const u8[:]`) | a string, by `http::json_string` |
| Another array or slice | an array, each element by these rules |
| A struct or enum | by the program's `format` overload for it |
| An optional | `null`, or its value by Goose's `format` |

A struct or enum without its own `format` gets Goose's default format, which isn't
JSON, and an optional string's value isn't quoted: give either type a `format`, or
write the outer struct's by hand. `format_fields` doesn't rename a key, leave out a
field, or read JSON: a writer that needs those stays hand-written, and the generator
writes both from a schema. It builds on Goose's `const for` over `fields<T>` (spec
§6), whose first version names each field and reaches it but doesn't give its type.

## 2. Middleware

Middleware is a block around the routes it applies to, inlined into the handler: a scope
can have its own, and a public route none.

| Call | Does |
|---|---|
| `rest::timed(cx) { ... }` | Adds `Server-Timing: app;dur=<ms>` with a 12-byte duration field padded with trailing spaces, and writes an access log line to standard error: method, target, status, bytes, milliseconds. `rest::timed(cx, false)` skips the log. |
| `rest::cors(cx, rest::Cors { origins: "...", .. }) { ... }` | Adds the CORS fields to every answer inside, errors included, for an origin in `origins` (separated by spaces, or `*`). Answers a preflight with 204 itself, and an origin not listed with 403 `origin_not_allowed`. `methods`, `headers`, `expose`, `max_age`, and `credentials` set the rest. |
| `rest::compressed(cx) { cx => ... }` | Compresses the answers inside, errors included, by the request's `Accept-Encoding`, with goose-http's gzip, deflate, and zstd. An optional module: [Compression](#21-compression). |
| `rest::bearer(cx) { token => ... }` | Fails 401 `unauthenticated` with `WWW-Authenticate: Bearer` without a bearer token; `rest::invalid_token(cx)` refuses one. `rest::bearer_token(cx)` returns it, for a generated router's security check. |
| `rest::scope(cx, "/v1")` | Whether the path starts with the prefix at a segment boundary; `rest::on` calls inside match the rest. `rest::otherwise(cx)` answers 404, 405, and OPTIONS across scopes. |

`timed` and `cors` go outside `rest::route`, so that the errors it answers get their
fields; `bearer` and anything else that fails go inside it. A request has one route:
routes nested in routes don't inline ([architecture](architecture.md#middleware-and-inlining)).
A program's own `inline fn` can nest several middleware and pass its block on, so a scope
has one level: [A stack of your own](tutorial/07-middleware.md#a-stack-of-your-own).

Which answers get the fields:

| Answer | CORS fields | `Server-Timing` and log line |
|---|---|---|
| Written in the route, at the request | yes | yes, the route's time |
| A response begun in the route (`rest::begin`, `rest::file`, `rest::upgrade`) | in its head | in its head |
| Written at a later call ([Later calls](#4-later-calls)) of a route that called `rest::ask` or `rest::body_in_pieces` at the request: at `WAKE`, at a body's `BODY` or `END`, a response begun then, a 504 `timeout`, or a 413 past the limit | yes | yes, timed from the request to the answer's head |
| Written once a body left to gather (`rest::body`) is whole, when the route runs again | yes | yes, timed from that run |
| goose-rest's 413 or 503 while a body is gathered, for a chunked body past its limit or the gather budget | no | no |

When a route leaves its request unanswered for a later call, each middleware keeps what it
decided with the exchange: the fields its answers get, and `timed`'s start and log
setting. goose-rest adds them to the answer that call writes, after goose-http's current
`Server` and `Date`, and drops them once the answer's head is written or the exchange
ends. A route that uses neither middleware keeps nothing. At a later call, `cors` and
`timed` run their block as it is, so a handler can also wrap its later calls in them.

`timed` reserves its duration field in `cx.out.common` before the block and fills it
after the response is written, so the body doesn't move. Both `timed` and `cors` take
the context by reference. CORS looks for a preflight's request-method field only on
OPTIONS. `bearer_token` uses `http::bearer` and requires a token68 bearer token.

### 2.1 Compression

`rest::compressed` is in the module `rest.compression`, which `rest` doesn't import, so
a program without it builds without goose-compress. To use it, declare goose-compress in
the root file at the tag goose-http's `compression.goose` names, and import the
module:

```rust
import http from "github.com/kaitk/goose-http@v0.4.1";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import rest from "github.com/kaitk/goose-rest@<tag>";
import rest.compression;

fn handle(cx) {
    rest::timed(cx) {
        rest::compressed(cx) { cx =>
            rest::routes(cx) { cx => ... };
        };
    };
}
```

The block gets its own context, as the block passed to `rest::routes` does. Its answer goes
to a separate buffer, and `compressed` then copies it to the response, compressing it as
goose-http's `http::respond_compressed` would: using the coding with the highest
`Accept-Encoding` weight, zstd before gzip before deflate at equal weights, with
`Content-Encoding`, the compressed `Content-Length`, and `Vary: Accept-Encoding`.

A second argument, goose-http's `http::Compression`, sets the levels and which codings
are offered, as [`examples/compress`](../examples/compress/main.goose)'s `/archive` does:

```rust
// The archive's options: gzip and deflate at level 9, their smallest and
// slowest, no zstd, and bodies from 256 bytes. Only zstd can be turned off:
// gzip and deflate are always offered, and the request's Accept-Encoding
// picks among the codings left.
let ARCHIVE = http::Compression { min_size: 256, level: 9, zstd: false, .. };
```

| Field | Default | Sets |
|---|---|---|
| `level` | 1 | gzip's and deflate's level, 1 to 9 |
| `zstd_level` | 1 | zstd's level, 1 to 22 |
| `zstd` | `true` | whether zstd is offered |
| `min_size` | 1024 | the shortest body compressed, in bytes |

gzip and deflate can't be turned off. The server follows the
request's `Accept-Encoding` weights when choosing the coding, with zstd before gzip before
deflate when the weights are equal.

| Answer | Gets |
|---|---|
| `rest::json`, `json_bytes`, `text`, and errors, of `min_size` bytes or more | Compressed, with `Vary` |
| Shorter, HEAD, 206, or for a request that accepts no coding | `Vary` alone |
| A type `http::compressible` refuses, such as `image/png`; one with a `Content-Encoding` already | As written |
| Without a body (`rest::empty`, 204, 304) | As written |
| Begun with `rest::begin`, for a request that accepts a coding | Compressed as it's sent, chunked, with `Vary` |
| Begun with `rest::begin` for a request that accepts a coding, but HEAD, 206, a status without a body, or HTTP/1.0 | `Vary` alone, without the length `begin` was given |
| Begun with `rest::begin`, for a request that accepts no coding | `Vary` alone, with the length `begin` was given |
| Begun with `rest::begin`, of a type `http::compressible` refuses, or with no type | As written |
| `rest::file`, `rest::relay`'s reply in pieces, `http::begin` | As written |

Put `compressed` outside `rest::route`, so that the route's errors are compressed, and
inside `timed`, which then logs the compressed size. CORS and other fields added inside
it are kept. An answer written after the block returns, when a waiting route resumes,
is compressed only if the resumed handler runs inside `compressed` too. Each answer
inside is copied once, compressed or not: the response buffer can't shrink while a
handler holds the request. Request bodies sent with a `Content-Encoding` aren't
decoded.

A response begun with `rest::begin` inside `compressed` is compressed as goose-http's
`http::begin_compressed` compresses one: each `rest::send` is compressed and flushed as a
chunk of its own, so the client can decode all it has, and `rest::end` sends the coding's
trailer. Its later calls (`MORE`) needn't run inside `compressed`: the response keeps
the coding it began with, as [`examples/compress`](../examples/compress/main.goose)'s
`/v1/export` shows. Each response being compressed holds an encoder from goose-http's
pool until `rest::end`, or until `CLOSED` when it ends otherwise: about 460 KB for gzip
and deflate, and 1 MB for zstd. A worker builds one per response being compressed at the same time and
reuses it afterward. A program that doesn't compress keeps no bytes for it.

`rest::file` sends a file as it is, inside `compressed` too. Compressed on the fly, the
file would lose its `Content-Length`, its ranges, and the epoll loop's `sendfile`, and
goose-http's `http::serve_file` doesn't compress one either. goose-http serves a copy
stored compressed instead, `path.br`, `path.zst`, or `path.gz`, with
`http::open_precompressed`; `rest::file` opens `path` alone.

Declare your own middleware that takes a block as `inline fn`, as goose-rest's own are:

```rust
inline fn resolve_tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Goose's `-O2` inlines a function called once only up to a size threshold, and a handler's
routes exceed that threshold as soon as they're passed as the block. A plain `fn` then stays a C function that reaches
the handler's locals through pointers, and every middleware around it stays out of line
too. `inline fn` folds it into the handler ([findings](goose-findings.md#a-function-called-once-isnt-inlined-past-a-size),
aardappel/goose#33).

## 3. Extractors

Each extractor reads one part of the request, and fails the route with 400 when that
part is malformed ([Errors](#5-errors)), so it runs inside `rest::route`. A value that
has escapes to decode is decoded into `cx.scratch`, which lasts until the handler
returns. Otherwise the extractor returns the request's own bytes.

| Call | Gives | Fails with `detail` |
|---|---|---|
| `rest::param(cx, "name")` | the path parameter, decoded | |
| `rest::param_int(cx, "id")` | the path parameter as an `i64` | `id: integer` |
| `rest::query(cx, "q")` | the query parameter, decoded with `+` as a space, and whether it's there | |
| `rest::query_int(cx, "page")`, `rest::query_bool(cx, "all")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `page: integer`, `all: boolean` |
| `rest::form(cx, "name")` | the field of an `application/x-www-form-urlencoded` body, decoded with `+` as a space, and whether it's there | `name: encoding`; 415 `unsupported_media_type` for another media type |
| `rest::form_int(cx, "n")`, `rest::form_bool(cx, "on")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `n: integer`, `on: boolean` |
| `rest::part(cx, "name")` | the text of a part of a `multipart/form-data` body, as sent, and whether it's there | 415 `unsupported_media_type` for another media type or a missing or unusable boundary; `body: multipart` for a body that isn't multipart |
| `rest::part_int(cx, "n")`, `rest::part_bool(cx, "on")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `n: integer`, `on: boolean`, and `part`'s |
| `rest::file_part(cx, "pic")` | a part's bytes, its filename (`""` without one), its content type (`application/octet-stream` without one), and whether it's there | `part`'s |
| `rest::header(cx, "X-Request-Id")`, `rest::cookie(cx, "sid")` | the value, and whether it's there | |
| `rest::int_of(cx, v, "name")`, `rest::bool_of(cx, v, "name")` | `v` as an `i64` or a `bool` | `name: integer`, `name: boolean` |
| `rest::require(cx, "q", found)` | | `q: required` |
| `rest::take<T>(cx)` | a `T`, by `T`'s `from_request` overload | its own |
| `rest::body(cx, limit)` | the body, whole, of at most `limit` bytes (1 MB by default); a larger one in pieces with `rest::body_in_pieces` ([later calls](#4-later-calls)) | 413 `payload_too_large`; 503 `unavailable` past the worker's gather budget |

A query parameter, form field, or cookie that repeats gives its first value, and its
name is compared as sent, without decoding it.

The form extractors read the body with `rest::body`, which gathers it as described below.
They accept a Content-Type with parameters, such as
`application/x-www-form-urlencoded; charset=utf-8`. A route that accepts a form over
1 MB calls `rest::body(cx, limit)` before the first form extractor.

The multipart extractors read the whole body the same way and take the first part
with the name asked for through goose-http's `http::find_part`, whose rules decide
what is malformed. What they return are slices of the body, never copies. An upload
read as it arrives goes through goose-http's `http::each_part`
([goose-http's API](https://github.com/kaitk/goose-http/blob/main/docs/api.md)), a
piece at a time with `rest::body_in_pieces` ([tutorial](tutorial/14-bodies-in-pieces.md#a-multipart-form)).

A program that builds its own `http::Router` can still pass it explicitly to
`rest::param(cx, r, name)`, `rest::param_int(cx, r, name)`, and `rest::otherwise(cx, r)`.

`rest::take<T>` reads any type with an overload declared in the `rest` namespace, as
`fn rest::from_request(cx, v: const app::Session?) -> app::Session`. `v` is always null,
and its type picks the overload. The generator writes one for each schema object, which
reads the JSON body: 415 unless the request says `application/json`, and 400
`invalid_body` for a body the reader refuses.

goose-http hands a body to the handler with its head when both fit its read buffer,
8 KB by default
([goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)).
`rest::body` reads a longer one too: at its first call, the route leaves
without an answer, `rest::serve` gathers the body up to the limit, and then calls the
handler again with the body whole. The code before a route's first `rest::body`,
`rest::take` of a JSON type, or form extractor therefore runs twice for such a body and
must not change state; an answer there, such as a 401, ends the request without gathering
the body. A `Content-Length` over the limit is refused with 413 before
the body is sent, and a chunked body once it passes the limit. The first call's limit
holds for the request, so a route that takes a JSON body over 1 MB calls `rest::body`
with its limit first; a generated route does so for its `x-body-limit`
([generator](generator.md)). `http::Config`'s `max_body`, 1 MB by default, caps
every route, so a program with a larger limit raises it too: to `api::MAX_BODY` with a
schema.

Each worker gathers bodies into memory it keeps for its life, at the most it has held
at once. A body with a `Content-Length` takes its head and its length, and a chunked
one 16 KB, doubling as it fills. `rest::Config`'s `gather_budget`, 64 MB by default,
bounds that memory, so that it follows the configuration rather than what clients
send:

```rust
rest::serve(cfg, app, St { .. }, rest::Config { gather_budget: 16 * 1024 * 1024 }) { cx => handle(cx) };
```

A body with a `Content-Length` that the worker can't place within the budget gets 503
`unavailable` with `Retry-After: 1` at its head, in the program's error shape, before
the body is sent and before `100 Continue`; the connection stays open. A chunked body
gets the same 503 once it can't grow within the budget, and the connection closes, as
one past its limit gets 413. A body is placed in the first free space that holds it, so
one can be refused while less than the budget is in use, when the free space is in
pieces too small for it. Bodies read with `rest::body_in_pieces` don't count against the
budget: a route that takes large bodies, or many at once, reads them in pieces.

```rust
rest::route(cx) {
    let body = rest::take<api::ProjectCreate>(cx);
    let page, has_page = rest::query_int(cx, "page");
    rest::json(cx, 201, create_project(cx, body, if has_page { page } else { 1 }));
};
```

`rest::once(cx.state.profile) { load_profile(...) }` computes a value on its first call
in a request and returns it from then on. The slot is a `rest::Once<T>` field of the
request state, so each request starts with a fresh slot.

## 4. Later calls

A route that waits on another thread, reads its body in pieces, sends its response in
pieces, or takes an upgraded connection says what it waits on in `cx.state.use`, a
field of the program's `Use` enum, `None` for a route that waits on nothing: `rest::ask` puts the
lane's mark there ([Lanes](#41-lanes)), and the other calls the variant they're given.
`rest::serve` then calls the handler again for each event of that exchange, and the
handler sends each later call to a `resume` case function per variant, inside
`rest::on_reply`:

```rust
rest::serve(cfg, app, St { .. }) { cx =>
    if rest::resumed(cx) { rest::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
};
```

`rest::on_reply(cx) { ... }` is `rest::route` for a later call. It fails the route
with a lane's refusal before its block runs, and leaves `cx.state.use` as the route set
it, so a `CLOSED` after an early answer reaches the variant that holds what to release.
goose-http starts the request state afresh for each request. `cx.kind` says which
event it is, and `cx.req` is empty. A variant carries the request data its route needs,
and the request state holds the route's progress.

| The route called | The case function gets `cx.kind` | goose-rest handles |
|---|---|---|
| `rest::ask` | `http::WAKE`, at the lane's mark, with the job and its answer in `cx.reply`; on an upgraded connection, also `http::BODY` per arrival during the wait, and `http::TIMEOUT` | a refusal; a value's pieces, collected for one `WAKE`; `TIMEOUT`: 504 `timeout`, except on an upgraded connection |
| `rest::body_in_pieces` | `http::BODY` per piece, in `cx.body`; then `http::END`; or `http::CLOSED` | the limit: 413 |
| `rest::begin` | `http::MORE`; `http::CLOSED` | a `HEAD` request: no calls |
| `rest::pause`, after `rest::begin` | `http::TIMEOUT`, the response still open; `http::CLOSED` if the client goes first | goose-http's `TIMEOUT` at once, with no timer free: the response ends, then `CLOSED` |
| `rest::file` | `http::MORE`; `http::CLOSED`, both for `rest::send_file` | a range, as 206; 304, 416, and `HEAD`: no calls |
| `rest::upgrade` | `http::BODY` per arrival; `http::CLOSED` | |
| `rest::relay`, at a reply's first piece | none | the reply's later pieces |

`http::CLOSED` means that the exchange ended before the route finished, and that the
case function releases what the state holds, such as a file. It comes once, to a route
that called `body_in_pieces`, `begin`, `file`, or `upgrade`, when the client goes, when a body
passes its limit, when the route answers or fails before a body's `END`, when it
fails with its response begun, or when goose-rest ends a paused response. Anything the case function writes is discarded. A route that answers at the
`END`, or calls `rest::end`, gets none, nor does one that only asked.

A failure after a response has begun can't be answered: its head has already been sent. `rest::route`
leaves the response unended, goose-http closes the connection, and the client sees the
response cut short.

| Call | Does | Fails with |
|---|---|---|
| `rest::body_in_pieces(cx, limit, u)` | With `u`, a variant of `Use`, in `cx.state.use`: the body in pieces as they arrive, up to `limit` bytes. A body that came whole with its head comes as one `BODY` and the `END`, and an empty one as the `END` alone. The code around it runs once. | 413 `payload_too_large` for a `Content-Length` over `limit`, before the body is sent; a chunked body past it gets 413 and the connection closes. 500 `body_already_read` after `rest::body`, and `rest::body` after it. 500 `not_served` outside `rest::serve` and `serve_one`. |
| `rest::begin(cx, status, content_type, length, u)` | With `u` in `cx.state.use`, begins a response sent in pieces: `Content-Type` unless `content_type` is empty, and a `Content-Length` of `length`, or chunked for -1. `MORE` comes each time the client has taken what was sent; one that neither sends nor ends closes the connection. If the response begins while a body is being read, the body's pieces still arrive, followed by `MORE`. Inside `rest::compressed`, a response of a type worth compressing is compressed ([Compression](#21-compression)). | |
| `rest::pause(cx, ms)` | Pauses the response `rest::begin` began, for events sent over time such as Server-Sent Events: `TIMEOUT` comes after `ms` milliseconds, and the case function sends the next piece and pauses again, or ends. What was sent still goes out meanwhile, and no `MORE` comes until the pause ends; a `TIMEOUT` call that neither pauses nor ends gets `MORE` next. Call it in the route, or at `MORE` or `TIMEOUT`. Needs `Config.mail_slots` and `max_waiting`: past `max_waiting`, goose-http has no timer and gives `TIMEOUT` at once, which goose-rest tells from the pause's own by the clock, halfway to `ms`, and answers by ending the response. | 500 `not_sending` without a response begun and open; 500 `not_served` outside `rest::serve` and `serve_one` |
| `rest::send(cx, data)` | `http::send`: the next piece, or raw bytes after an upgrade. | |
| `rest::end(cx, trailers)` | `http::end`: ends the response, with trailers when chunked, or closes an upgraded connection. The route gets no more calls. | |
| `rest::file(cx, path, body, u, content_type)` | With `u` in `cx.state.use`, `http::serve_file`'s answer, with `ETag`, `Last-Modified`, and `Accept-Ranges`, and a type by `path`'s extension when `content_type` is empty. `body`, an `http::FileBody` in the request state, holds what's left to send. | 404 `file_not_found`, 403 `forbidden`, 500 `file_unreadable` |
| `rest::send_file(cx, body)` | For the case function: at `MORE`, the next piece of up to 64 KB, and the end after the last; at `CLOSED`, closes the file. | |
| `rest::upgrade(cx, protocol, u)` | With `u` in `cx.state.use`, `http::upgrade`'s 101. The client's bytes then come as `BODY`, with no `END` and no limit, and `rest::send` writes bytes as they are. `http::upgrade_of(cx.req)` is what the request asks to switch to. | |

`http::Config`'s `max_body` caps `rest::body_in_pieces`'s limit as it caps `rest::body`'s. A
piece of about 16 KB at each `MORE` keeps within `Config.max_queued`
([goose-http's long responses](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#long-responses)).
A route that upgraded can ask a lane (`rest::ask`), at the request or at a `BODY`.
Every later call goes to the `resume` of the variant in `cx.state.use`, and
`rest::ask` puts the lane's mark there, so while the route waits, the mark's `resume`
gets the client's bytes as `BODY`, and `rest::send` can answer them. It then gets the
reply as `WAKE`, or `TIMEOUT` when the time limit passes, in place of a 504, which
can't follow the 101. Only the `WAKE` carries a job, so this `resume` tells the events
apart by `cx.kind` before it calls `rest::job`, which fails with 500 `not_a_reply` at
any other. A `resume` that does nothing at `TIMEOUT` leaves the connection open, no
longer waiting. To get the bytes where they went before the wait, the program sets
`cx.state.use` back to the upgrade's variant at the `WAKE` and the `TIMEOUT`; nothing
restores it otherwise. `rest::end` during the wait ends it and closes the connection. A
`rest::ask` while the route waits already, as at a `BODY` during a wait, fails with 500
`already_waiting`, which closes the connection: an exchange has one wait, whose reply a
second job would share. A client can send at any time, so a route that asks at a `BODY`
checks `rest::is_waiting(cx)` first.

```rust
fn resume(u: Use.Asked, cx) {
    if cx.kind == http::WAKE {
        resume(rest::job<Asks>(cx), cx);   // the reply, with its job
    } else if cx.kind == http::BODY {
        rest::send(cx, cx.body);           // bytes during the wait
    } else if cx.kind == http::TIMEOUT {
        rest::send(cx, "timeout");
        cx.state.use = Use.Echo;           // the bytes after go to the upgrade's again
    }
}

fn resume(u: Asks.Lookup, cx) {
    rest::send(cx, rest::answer<Found>(cx).text);
    cx.state.use = Use.Echo;
}
```

A WebSocket's framing isn't provided: a package on top of
`rest::upgrade` can add it. The tutorial builds an upload with `body_in_pieces`
([page 14](tutorial/14-bodies-in-pieces.md)), and an export and downloads with `begin`
and `file` ([page 15](tutorial/15-long-responses.md));
[`examples/upgrade`](../examples/upgrade/main.goose) echoes an upgraded connection.

### 4.1 Lanes

A lane is the threads that do one kind of slow work, each with a box of its own, built
on goose-http's `http::Lane`
([goose-http's lanes](https://github.com/kaitk/goose-http/blob/main/docs/api.md#lanes)).
Each lane takes a fixed-mode enum of its jobs, a variant per use case, and has a
*mark*, a variant of the program's `Use`, that a route waiting on it holds in
`cx.state.use`. The program writes a `run` case function for each job, which the lane's
thread calls, and a `resume` for each job, which the worker calls with the reply. The
reply carries the job back, so the mark's `resume` dispatches on it again:

```rust
enum Reports { Totals { project: i64 } }
enum Use { None, Report }
struct St { use: Use = Use.None }
struct App { reports: rest::Lane<Reports, Use> }

thread_fn reader(box: http::Box, jobs: rest::Jobs<Reports>) {
    var r = Reader { .. };
    rest::lane(box, jobs) { u, a => run(u, r, a); };
}

fn run(u: Reports.Totals, r: Reader&, a) {
    let t = totals(r, u.project);
    if t.entries == 0 { rest::fail(a, 404, "no_such_project"); }   // fails the route
    rest::reply_value(a, t);
}

fn resume(u: Use.Report, cx) { resume(rest::job<Reports>(cx), cx); }
fn resume(u: Reports.Totals, cx) { rest::json(cx, 200, rest::answer<Totals>(cx)); }

let reports = rest::lane_open<Reports>(http::LaneConfig { threads: 2, .. }, Use.Report, reader);
http::run(cfg, App { reports: reports }, worker);
rest::lane_stop(reports);
```

| Call | Does | Fails with |
|---|---|---|
| `http::LaneConfig { threads, slots, size }` | A lane's threads (1; at least 1, at most 64), and each box's `slots`, a power of two of at least 2 (64), of `size` bytes (256). | |
| `rest::lane_open<U>(cfg, mark, W)` | Opens a `rest::Lane<U, M>` of jobs of the enum `U`, with `mark`, through `http::lane_open`: spawns its threads, each the `thread_fn W(box: http::Box, jobs: rest::Jobs<U>)` with a box of its own. `rest::lane_open<U>(cfg, mark, a, W)` passes each `a` too: `thread_fn W(box: http::Box, jobs: rest::Jobs<U>, a: A)`. A `W` whose `jobs` names another enum than `U` doesn't compile. The `Lane` is flat, so it crosses `http::run` in worker state. | A box that fails to open ends the program. |
| `rest::lane(box, jobs) { u, a => ... }` | A lane thread's loop: the block gets each job, a `U` of `jobs`, a `rest::Jobs<U>`, and `a`, where its reply goes, in the order they came, until the lane is stopped and its box empty; then closes the box. A job the block neither replies to nor fails refuses with 500 `no_reply`. | |
| `rest::lane_job(jobs, bytes) { u, a => ... }` | One job of `rest::lane`, from a message's bytes: for a thread that writes its own loop, as one doing timed work between jobs does, and for a test that reads the job a route sent, with a `rest::Jobs<U> { .. }` of its own. `rest::lane_of<U>(box, mark)`, a lane of a box with no thread, and a `rest::Jobs<U>` literal passed here are for tests and hand-written loops: nothing checks their `U` against the lane's enum, as `rest::lane_open` checks a thread's. | |
| `rest::lane_stop(lane)` | `http::lane_stop`: stops every box of `lane` and waits for its threads, each of which takes what its box holds first. A full box can't refuse the stop. | |
| `rest::ask(cx, lane, job, ms)` | Sends `job`, a variant of the lane's enum, to the least busy thread of `lane`, the one whose box holds the fewest, or to the others in turn while each is full, and waits for the reply with the lane's mark in `cx.state.use` ([Later calls](#4-later-calls)). A variant of another lane's enum doesn't compile. | 503 `unavailable` when every box is full, the lane is stopped, or the job is longer than a slot; 500 `job_too_large`, before the job is sent, when the job and its 4-byte length don't fit one message of the reply; 500 `already_waiting` |
| `rest::reply_value(a, v)` | On the lane: replies `v`, a flat value, after the job, in pieces of the worker's message size, each marked as a value's, which the worker collects whole before the `resume` runs. Returns false once the route has gone. | The route: 502 `reply_too_large` past the worker's gather budget |
| `rest::reply(a, data)` | On the lane: replies `data` after the job, in pieces of the worker's message size, for `rest::relay`. Returns false once the route has gone. | |
| `rest::fail(a, status, code)` | On the lane: refuses the job, which fails the route with `status` and `code` before its `resume` runs. A domain's `check(e, x)` that calls `rest::fail(x, ...)` serves a route's `cx` and a lane's `a` alike. | |
| `rest::still_wanted(a)` | On the lane: whether the route still waits, for work worth skipping. A snapshot: the route can still go before the reply. | |
| `rest::job<U>(cx)` | In the mark's `resume`: the job the reply carries back. | 500 `not_a_reply` at another event than `WAKE`; 502 `bad_reply` |
| `rest::answer<T>(cx)` | In a job's `resume`: the value `rest::reply_value` replied, whole however many pieces it came in. | 502 `bad_reply` for a reply that isn't a `T`, as one `rest::reply` sent in pieces |
| `rest::relay(cx, status, content_type)` | In a job's `resume`: answers with the bytes `rest::reply` replied after the job, whole, or chunked as the pieces come. | 502 `bad_reply` |

`ms` defaults to 5000, as for every `rest::ask`. A reply longer than one message of
the worker's box, `http::Config.mail_size` bytes, 256 by default, comes in pieces. The
pieces of a `rest::reply_value` carry a tag bit of their own, `rest::REPLY_VALUE`, and
the worker collects them in its spill, the memory it gathers bodies in, counted against
`rest::Config`'s `gather_budget` ([Extractors](#3-extractors)). The `resume` runs once,
at the last piece, with the whole reply, so `rest::job` and `rest::answer` read it as
they read one message. The wait's time limit restarts at each piece. A reply the spill
can't hold within the budget fails the route with 502 `reply_too_large`, or cuts short
a response already begun, and leaves the mark in `cx.state.use`, as a timeout does. A
client that goes, or a time limit that passes, before the last piece frees what was
collected. `rest::reply`'s pieces aren't collected: `rest::relay` sends each on as it
comes, so the worker holds one piece at a time. Raising `mail_size` to the largest job
and answer avoids pieces altogether, at the cost of every slot of every worker's box.
The request state keeps only the mark: what a `resume` needs from the request goes in
the job, which comes back with the reply.

The reply's first message holds the job, behind its length in 4 bytes, so a job must
fit one message with them: `rest::ask` fails the route with 500 `job_too_large` before
it sends a job that doesn't. A lane's enum is fixed-mode, so every job of the lane is
the size of its largest variant, and adding a larger variant enlarges every job of the
lane. The job echoed in a reply passes through the reply mail slots, which live in the
process's memory and aren't erased after they're read, so don't put a secret in a job
unless the program needs it back: hash a password on the lane, for example, and keep
only what the `resume` needs.

Each `run` and `resume` takes one variant. An overload that takes a whole enum, untyped
(`fn run(u, r: Reader&, a)`) or typed (`fn resume(u: Reports, cx)`), is an exact match,
so it takes every call, and the variants' own cases never run, without a compiler
warning ([findings](goose-findings.md#an-overload-that-takes-the-whole-enum-hides-its-case-functions-without-a-word)).
`rest::lane` answers 500 `no_reply` for a catch-all `run` that doesn't reply; nothing
catches one that does, or a catch-all `resume`. Don't write either.

The best practices give each kind of slow work a lane, and grow one by threads
([Lanes of several threads](best-practices/lanes.md#66-lanes-of-several-threads)).

## 5. Errors

By default, every error goose-rest answers is a JSON object whose member `error` is a
code in snake_case, with `detail` and `at` where the table names them; a program can write
another shape, as the end of this section shows:

```json
{"error":"project_not_found"}
```

| Status | Code | From |
|---|---|---|
| any | the code given | `rest::fail(cx, status, code)` in a route, or `rest::fail(a, status, code)` on a lane |
| 400 | `invalid_body`, with `detail` and `at` | `rest::fail_body(cx, r)`, for a body a JSON reader refused |
| 400 | `invalid_parameter`, with `detail` | the [extractors](#3-extractors), `rest::fail_param`, and the generated router: a parameter missing, malformed, or outside its schema, as `id: integer`, `q: required`, or `page: minimum` |
| 400 | `bad_path` | `rest::otherwise`: a path with a dot-segment or an escaped control byte |
| 401 | `unauthenticated`, with `WWW-Authenticate: Bearer` | `rest::bearer`: no bearer token |
| 401 | `invalid_token`, with `WWW-Authenticate: Bearer error="invalid_token"` | `rest::invalid_token(cx)` |
| 403 | `origin_not_allowed` | `rest::cors`: an `Origin` it doesn't list |
| 404 | `not_found` | `rest::otherwise`: no route's path matched |
| 405 | `method_not_allowed`, with an `Allow` field | `rest::otherwise`: a route's path matched with another method |
| 403 | `forbidden` | `rest::file`: a file the program may not read |
| 404 | `file_not_found` | `rest::file`: no file, or a directory, at the path |
| 413 | `payload_too_large` | `rest::body`, `rest::body_in_pieces`, `rest::take` of a schema type, and the form extractors: a body over the limit |
| 415 | `unsupported_media_type` | `rest::take` of a schema type: a JSON body sent as another media type; the form extractors: a body that isn't `application/x-www-form-urlencoded`; the multipart extractors: a body that isn't `multipart/form-data` with a usable boundary |
| 500 | `already_waiting` | `rest::ask` while the route waits already, as at an upgraded connection's `BODY` during a wait |
| 500 | `body_already_read` | `rest::body_in_pieces` after `rest::body`, or `rest::body` after `rest::body_in_pieces` |
| 500 | `file_unreadable` | `rest::file`: a file that couldn't be opened for another reason |
| 500 | `job_too_large` | `rest::ask`: a job that, with its length, doesn't fit one message of the reply ([Lanes](#41-lanes)) |
| 500 | `no_reply` | `rest::lane`: a job whose `run` neither replied nor failed |
| 500 | `not_a_reply` | `rest::job` at another event than `WAKE`, as an upgraded connection's `BODY` during a wait |
| 500 | `not_sending` | `rest::pause` without a response begun with `rest::begin` and still open |
| 500 | `not_served` | `rest::body_in_pieces` or `rest::pause` with a context that `rest::serve` or `serve_one` didn't make |
| 501 | `not_implemented` | `rest::otherwise`: a method HTTP doesn't define |
| 502 | `bad_reply` | `rest::job`, `rest::answer`, and `rest::relay`: a reply that doesn't hold its job, or a value of the type read |
| 502 | `reply_too_large` | `rest::ask`: a reply of `rest::reply_value`, in pieces, past the worker's gather budget ([Lanes](#41-lanes)) |
| 503 | `unavailable` | `rest::ask`: every box of the lane is full, or the lane is stopped ([Lanes](#41-lanes)) |
| 503 | `unavailable`, with `Retry-After: 1` | `rest::body`, `rest::take` of a schema type, and the form extractors: a body past the worker's gather budget ([Extractors](#3-extractors)) |

The generated router answers 404, 405, 501, and `bad_path` as `rest::otherwise` does,
through `rest::no_route`, `rest::no_method`, and `rest::not_found`.

When a generated reader refuses a body, the error names the field and the check that
failed, and gives the position in the body where the reader stopped, counted in bytes:

```json
{"error":"invalid_body","detail":"name: maxLength","at":31}
```

`detail` is one of the reader's messages: `<field>: required`, `<field>: <keyword>` for a
schema keyword such as `minLength`, `maximum`, or `enum`, `<field>: not UTF-8`, `unknown
member`, or a syntax error from `json`, such as `expected a string`.

The first answer wins: a route that answers and then fails keeps its answer.

A program that needs another shape, such as an API whose errors also carry the status,
writes every error's body itself with an overload for its request state's type. It
gets the status, the code, and the detail and `at` the table names (empty and -1 where
there are none); the status line and the fields stay goose-rest's:

```rust
fn rest::error_body(body: u8[>..]&, st: const app::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":");
    http::json_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    body.push('}');
}
```

## 6. Testing

| Call | Answers |
|---|---|
| `rest::serve_one(text) { cx => ... }` | The response's bytes to `text`, one request's bytes, answered through the block inside `rest::route`, as `rest::serve` answers it |
| `rest::serve_one(text, app) { cx => ... }` | The same, with the worker state by reference in `cx.app` |
| `rest::serve_one(text, app, fresh, cfg, limits) { cx => ... }` | The same, with `fresh` as the request state, `cfg`'s limits, and `limits`, a `rest::Config`, for the gather budget; `cfg` and `limits` are optional |
| `rest::serve_one(text, app, fresh, wakes, cfg, limits) { cx => ... }` | The same, with `wakes`, a `rest::Wake` for each wait of a route that calls `rest::ask`, in order |
| `rest::Wake { data, tag, timeout, early, sent }` | What a wait gets in place of the thread it asked: a reply of `data` with `tag`, as `rest::wake` gives them, or with `timeout: true`, the end of the wait, which is a `rest::pause`'s time come; with `early: true` as well, goose-http's `TIMEOUT` at once, for want of a timer; on an upgraded connection, `sent` comes first, as one `http::BODY` during the wait |
| `rest::play(lane, job) { u, a => ... }` | Runs `job`, a variant of `lane`'s enum, through the block, as `rest::lane` runs it, with no thread or mail, and returns its reply, a `rest::Played`: an answer, a refusal for a `rest::fail`, its code whole, or 500 `no_reply` for neither. `rest::still_wanted` is true. The block is the lane's own, `run(u, state, a)`, to test a use case, or a stand-in that replies what a test needs. |
| `rest::wake(p)` | The `Wake` that gives a route what `p`, a `rest::Played`, replied |
| `rest::refusal(p)` | The status and code of the refusal `p` replied, or 0 and `""` for an answer |

A body that doesn't fit in `cfg.max_head` with its head comes in pieces of
`cfg.max_head` bytes: gathered as the server gathers it, within `limits`' gather budget,
so the block runs again once it's whole, or passed to a route that called `rest::body_in_pieces`. A body shorter than its
`Content-Length` is a client that hung up midway: its pieces come, then `http::CLOSED`
in place of `http::END`. A response begun with `rest::begin` or `rest::file` is taken to
its end, `http::MORE` at a time, as by a client that keeps up. On a connection the route
upgraded, the bytes of `text` after the request's head are the client's: they come as
one `http::BODY` once the route doesn't wait, and then the client closes. A request goose-http refuses gets its
refusal, and a block that writes no answer gets 500. An HTTP/1.1 request without `Host`
is given `Host: localhost`. A chunked body isn't decoded: give a test request a
`Content-Length`. The response has no `Date` or `Server` field
([tutorial](tutorial/09-testing.md)).

A route that calls `rest::ask` sends its job, or gets 503 for a full box, or 500
`job_too_large` for a job that doesn't fit a message of `cfg.mail_size` bytes. `serve_one`
then calls the handler again with the wait's `Wake`, as `rest::serve` calls it when the
reply comes: as `http::WAKE`, in pieces of `cfg.mail_size` bytes with the tags
`rest::reply` and `rest::reply_value` give them, a value's collected whole within
`limits`' gather budget, a refusal, its code cut to one message as a lane cuts it, as
the route's failure, or as the timeout's 504, which an upgraded connection gets
as `http::TIMEOUT`. On an upgraded connection, the `Wake`'s `sent` comes first, as one
`http::BODY` during the wait. A piece that comes once the route
no longer waits is dropped. A wait with no `Wake` left ends the exchange: the answer is
what the route wrote, or 500 for nothing, and a route paused with its response open
gets `http::CLOSED`, as for a client that goes. A paused route gets each `Wake` with
`timeout: true` as its `http::TIMEOUT`. No thread runs and no time passes, so a reply
that comes late, or a client that goes while its job waits, is tested over HTTP
([tutorial](tutorial/16-testing.md)).
