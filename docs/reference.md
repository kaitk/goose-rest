# Reference

goose-rest's middleware, extractors, errors, and test helper: what each call does, what
it gives, and what it answers when it fails. The [tutorial](tutorial/README.md) introduces them
in order, and the [generator reference](generator.md) covers what `goose-rest gen` writes.

## Context and routes

`rest::serve(cfg, app) { cx => handle(cx) };` serves requests with the worker's state
by reference in `cx.app`. `rest::serve(cfg, app, fresh)` also starts each request's
`cx.state` from `fresh`. A program with no state can call `rest::serve(cfg)`.
With request state alone, bind `var app = rest::NoState { .. };` and pass it beside
`fresh`. `rest::serve_epoll` has the same forms.

The context is `rest::Cx<S, A, R>`: the request's state, the worker's state, and the
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

`rest::json` and `rest::json_bytes` answer `application/json`; `rest::text` answers
`text/plain; charset=utf-8`. `rest::empty(cx,
status)` answers none: 204 and 304 omit `Content-Length`, and other statuses write
`Content-Length: 0`.

## Middleware

Middleware is a block around the routes it applies to, inlined into the handler: a scope
can have its own, and a public route none.

| Call | Does |
|---|---|
| `rest::timed(cx) { ... }` | Adds `Server-Timing: app;dur=<ms>` with a 12-byte duration field padded with trailing spaces, and writes an access log line to standard error: method, target, status, bytes, milliseconds. `rest::timed(cx, false)` skips the log. |
| `rest::cors(cx, rest::Cors { origins: "...", .. }) { ... }` | Adds the CORS fields to every answer inside, errors included, for an origin in `origins` (separated by spaces, or `*`). Answers a preflight with 204 itself, and an origin not listed with 403 `origin_not_allowed`. `methods`, `headers`, `expose`, `max_age`, and `credentials` set the rest. |
| `rest::compressed(cx) { cx => ... }` | Compresses the answers inside, errors included, by the request's `Accept-Encoding`, with goose-http's gzip, deflate, and zstd. An optional module: [Compression](#compression). |
| `rest::bearer(cx) { token => ... }` | Fails 401 `unauthenticated` with `WWW-Authenticate: Bearer` without a bearer token; `rest::invalid_token(cx)` refuses one. `rest::bearer_token(cx)` returns it, for a generated router's security check. |
| `rest::scope(cx, "/v1")` | Whether the path starts with the prefix at a segment boundary; `rest::on` calls inside match the rest. `rest::otherwise(cx)` answers 404, 405, and OPTIONS across scopes. |

`timed` and `cors` go outside `rest::route`, so that the errors it answers get their
fields; `bearer` and anything else that fails goes inside it. A request has one route:
routes nested in routes don't inline ([architecture](architecture/README.md#inlining)).
An answer written later, when a waiting route resumes, gets neither middleware's fields.

`timed` reserves its duration field in `cx.out.common` before the block and fills it
after the response is written, so the body doesn't move. Both `timed` and `cors` take
the context by reference. CORS looks for a preflight's request-method field only on
OPTIONS. `bearer_token` uses `http::bearer` and requires a token68 bearer token.

### Compression

`rest::compressed` is in the module `rest.compression`, which `rest` doesn't import, so
a program without it builds without goose-compress. To use it, declare goose-compress in
the root file at the commit goose-http's `compression.goose` names, and import the
module:

```rust
import http from "github.com/kaitk/goose-http@v0.3.1";
import compress from "github.com/kaitk/goose-compress@2c7df270b88ed8a00e2d73b6f84d50908cf5a558";
import rest from "github.com/kaitk/goose-rest@<commit>";
import rest.compression;

fn handle(cx) {
    rest::timed(cx) {
        rest::compressed(cx) { cx =>
            rest::routes(cx) { cx => ... };
        };
    };
}
```

The block gets its own context, as `rest::routes`'s does. Its answer goes to a buffer of
its own, and `compressed` then copies it to the response, compressed as goose-http's
`http::respond_compressed` would compress it: in the coding `Accept-Encoding` weighs
highest, zstd before gzip before deflate at equal weights, with `Content-Encoding`, the
compressed `Content-Length`, and `Vary: Accept-Encoding`. `rest::compressed(cx,
http::Compression { level: 6, .. })` sets goose-http's options: `min_size` (1024 bytes),
`level` and `zstd_level` (1), and `zstd` (offered).

| Answer | Gets |
|---|---|
| `rest::json`, `json_bytes`, `text`, and errors, of `min_size` bytes or more | Compressed, with `Vary` |
| Shorter, HEAD, 206, or to a request that takes no coding | `Vary` alone |
| A type `http::compressible` refuses, such as `image/png`; one with a `Content-Encoding` already | As written |
| Without a body (`rest::empty`, 204, 304) | As written |
| Begun with `http::begin` and sent in pieces, such as `rest::relay`'s reply in pieces | As written, uncompressed |

Put `compressed` outside `rest::route`, so that the route's errors are compressed, and
inside `timed`, which then logs the compressed size. CORS and other fields added inside
it are kept. An answer written after the block returns, when a waiting route resumes,
is compressed only if the resumed handler runs inside `compressed` too. Each answer
inside is copied once, compressed or not: the response buffer can't shrink while a
handler holds the request. Request bodies sent with a `Content-Encoding` aren't
decoded.

Declare your own middleware that takes a block as `inline fn`, as goose-rest's own are:

```rust
inline fn tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Goose's `-O2` inlines a function called once only up to a size, and a handler's routes
pass it as soon as they're the block. A plain `fn` then stays a C function that reaches
the handler's locals through pointers, and every middleware around it stays out of line
too. `inline fn` folds it into the handler ([findings](goose-findings.md#a-function-called-once-isnt-inlined-past-a-size),
aardappel/goose#33).

## Extractors

Each extractor reads one part of the request, and fails the route with 400 when that
part is malformed ([Errors](#errors)), so it runs inside `rest::route`. A value that
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
| `rest::header(cx, "X-Request-Id")`, `rest::cookie(cx, "sid")` | the value, and whether it's there | |
| `rest::int_of(cx, v, "name")`, `rest::bool_of(cx, v, "name")` | `v` as an `i64` or a `bool` | `name: integer`, `name: boolean` |
| `rest::require(cx, "q", found)` | | `q: required` |
| `rest::take<T>(cx)` | a `T`, by `T`'s `from_request` overload | its own |
| `rest::body(cx, limit)` | the body, whole, of at most `limit` bytes (1 MB by default) | 413 `payload_too_large` |

A query parameter, form field, or cookie that repeats gives its first value, and its
name is compared as sent, without decoding it.

The form extractors read the body with `rest::body`, so the body is gathered as below,
and accept a Content-Type with parameters, such as
`application/x-www-form-urlencoded; charset=utf-8`. A route that takes a form over
1 MB calls `rest::body(cx, limit)` before the first form extractor. Multipart forms
have no extractor; goose-http's `http::each_part` reads them
([goose-http's API](https://github.com/kaitk/goose-http/blob/main/docs/api.md)).

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
`rest::take` of a JSON type, or form extractor therefore runs twice for such a body, and must not change
state before it; an answer there, such as a 401, ends the request ungathered. A `Content-Length` over the limit is refused with 413 before
the body is sent, and a chunked body once it passes the limit. The first call's limit
holds for the request, so a route that takes a JSON body over 1 MB calls `rest::body`
with its limit first; a generated route does so for its `x-body-limit`
([generator](generator.md)). `http::Config`'s `max_body`, 1 MB by default, caps
every route, so a program with a larger limit raises it too: to `api::MAX_BODY` with a
schema.

```rust
rest::route(cx) {
    let body = rest::take<api::ProjectCreate>(cx);
    let page, has_page = rest::query_int(cx, "page");
    rest::json(cx, 201, create_project(cx, body, if has_page { page } else { 1 }));
};
```

`rest::once(cx.state.profile) { load_profile(...) }` computes a value on its first call
in a request and returns it from then on. The slot is a `rest::Once<T>` field of the
per-request state, so each request starts it anew.

## Errors

Every error goose-rest answers is JSON with one member, `error`, a code in snake_case:

```json
{"error":"project_not_found"}
```

| Status | Code | From |
|---|---|---|
| any | the code given | `rest::fail(cx, status, code)` |
| 400 | `invalid_body`, with `detail` and `at` | `rest::fail_body(cx, r)`, for a body a JSON reader refused |
| 400 | `invalid_parameter`, with `detail` | the [extractors](#extractors), `rest::fail_param`, and the generated router: a parameter missing, malformed, or outside its schema, as `id: integer`, `q: required`, or `page: minimum` |
| 400 | `bad_path` | `rest::otherwise`: a path with a dot-segment or an escaped control byte |
| 401 | `unauthenticated`, with `WWW-Authenticate: Bearer` | `rest::bearer`: no bearer token |
| 401 | `invalid_token`, with `WWW-Authenticate: Bearer error="invalid_token"` | `rest::invalid_token(cx)` |
| 403 | `origin_not_allowed` | `rest::cors`: an `Origin` it doesn't list |
| 404 | `not_found` | `rest::otherwise`: no route's path matched |
| 405 | `method_not_allowed`, with an `Allow` field | `rest::otherwise`: a route's path matched with another method |
| 413 | `payload_too_large` | `rest::body`, `rest::take` of a schema type, and the form extractors: a body over the limit |
| 415 | `unsupported_media_type` | `rest::take` of a schema type: a JSON body sent as another media type; the form extractors: a body that isn't `application/x-www-form-urlencoded` |
| 501 | `not_implemented` | `rest::otherwise`: a method HTTP doesn't define |

The generated router answers 404, 405, 501, and `bad_path` as `rest::otherwise` does,
through `rest::no_route`, `rest::no_method`, and `rest::not_found`.

A body a generated reader refuses names the field and the check that failed, and where
in the body the reader stopped, counted in bytes:

```json
{"error":"invalid_body","detail":"name: maxLength","at":31}
```

`detail` is one of the reader's messages: `<field>: required`, `<field>: <keyword>` for a
schema keyword such as `minLength`, `maximum`, or `enum`, `<field>: not UTF-8`, `unknown
member`, or a syntax error from `json`, such as `expected a string`.

The first answer wins: a route that answers and then fails keeps its answer.

A program that needs another shape, such as an API whose errors also carry the status,
writes every error's body itself with an overload for its per-request state's type. It
gets the status, the code, and the detail and `at` the table names (empty and -1 where
there are none); the status line and the fields stay goose-rest's:

```rust
fn rest::error_body(body: u8[>..]&, st: const app::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":");
    json::format_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    body.push('}');
}
```

## Testing

| Call | Answers |
|---|---|
| `rest::serve_one(text) { cx => ... }` | The response's bytes to `text`, one request's bytes, answered through the block inside `rest::route`, as `rest::serve` answers it |
| `rest::serve_one(text, app) { cx => ... }` | The same, with the worker's state by reference in `cx.app` |
| `rest::serve_one(text, app, fresh, cfg) { cx => ... }` | The same, with `fresh` as the per-request state and `cfg`'s limits; `cfg` is optional |

A body that doesn't fit in `cfg.max_head` with its head is gathered as the server gathers
it, so the block runs again once it's whole. A request goose-http refuses gets its
refusal, and a block that writes no answer gets 500. An HTTP/1.1 request without `Host`
is given `Host: localhost`. A chunked body isn't decoded: give a test request a
`Content-Length`. The response has no `Date` or `Server` field
([tutorial](tutorial/09-testing.md)). `serve_one` runs no loop: a route that calls
`rest::ask` sends its job, or gets 503 for a full box, but no reply comes, so the
handler never runs with `rest::woken` and the answer is 500
([tutorial](tutorial/16-testing.md)).
