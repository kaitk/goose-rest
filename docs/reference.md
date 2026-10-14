# Reference

goose-rest's middleware, extractors, and errors: what each call does, what it gives,
and what it answers when it fails. The [tutorial](tutorial.md) introduces them in order,
and the [generator reference](generator.md) covers what `goose-rest gen` writes.

## Middleware

Middleware is a block around the routes it applies to, inlined into the handler: a scope
can have its own, and a public route none.

| Call | Does |
|---|---|
| `rest::timed(cx) { ... }` | Adds `Server-Timing: app;dur=<ms>` to the answer, and writes an access log line to standard error: method, target, status, bytes, milliseconds. `rest::timed(cx, false)` skips the log. |
| `rest::cors(cx, rest::Cors { origins: "...", .. }) { ... }` | Adds the CORS fields to every answer inside, errors included, for an origin in `origins` (separated by spaces, or `*`). Answers a preflight with 204 itself, and an origin not listed with 403 `origin_not_allowed`. `methods`, `headers`, `expose`, `max_age`, and `credentials` set the rest. |
| `rest::bearer(cx) { token => ... }` | Fails 401 `unauthenticated` with `WWW-Authenticate: Bearer` without a bearer token; `rest::invalid_token(cx)` refuses one. `rest::bearer_token(cx)` returns it, for a generated router's security check. |
| `rest::scope(r, "/v1")` | Whether the path starts with the prefix at a segment boundary; the routes inside match the rest. `rest::otherwise` answers 404, 405, and OPTIONS across scopes. |

`timed` and `cors` go outside `rest::route`, so that the errors it answers get their
fields; `bearer` and anything else that fails goes inside it. A request has one route:
routes nested in routes don't inline ([architecture](architecture/README.md#inlining)).
An answer written later, when a waiting route resumes, gets neither middleware's fields.

Declare your own middleware that takes a block as `inline fn`, as goose-rest's own are:

```goose
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
| `rest::param(cx, r, "name")` | the path parameter, decoded | |
| `rest::param_int(cx, r, "id")` | the path parameter as an `i64` | `id: integer` |
| `rest::query(cx, "q")` | the query parameter, decoded with `+` as a space, and whether it's there | |
| `rest::query_int(cx, "page")`, `rest::query_bool(cx, "all")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `page: integer`, `all: boolean` |
| `rest::header(cx, "X-Request-Id")`, `rest::cookie(cx, "sid")` | the value, and whether it's there | |
| `rest::int_of(cx, v, "name")`, `rest::bool_of(cx, v, "name")` | `v` as an `i64` or a `bool` | `name: integer`, `name: boolean` |
| `rest::require(cx, "q", found)` | | `q: required` |
| `rest::take<T>(cx)` | a `T`, by `T`'s `from_request` overload | its own |
| `rest::body(cx, limit)` | the body, whole, of at most `limit` bytes (1 MB by default) | 413 `payload_too_large` |

`rest::take<T>` reads any type with an overload declared in the `rest` namespace, as
`fn rest::from_request(cx, v: const app::Session?) -> app::Session`. `v` is always null,
and its type picks the overload. The generator writes one for each schema object, which
reads the JSON body: 415 unless the request says `application/json`, and 400
`invalid_body` for a body the reader refuses.

goose-http hands a body to the handler with its head when both fit its read buffer,
8 KB by default. `rest::body` reads a longer one too: at its first call, the route leaves
without an answer, `rest::serve` gathers the body up to the limit, and then calls the
handler again with the body whole. The code before a route's first `rest::body`, or
`rest::take` of a JSON type, therefore runs twice for such a body, and must not change
state before it; an answer there, such as a 401, ends the request ungathered. A `Content-Length` over the limit is refused with 413 before
the body is sent, and a chunked body once it passes the limit. The first call's limit
holds for the request, so a route that takes a JSON body over 1 MB calls `rest::body`
with its limit first; a generated route does so for its `x-body-limit`
([generator](generator.md)). `http::Config`'s `max_body`, 1 MB by default, caps
every route, so a program with a larger limit raises it too: to `api::MAX_BODY` with a
schema.

```goose
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
| 413 | `payload_too_large` | `rest::body`, and `rest::take` of a schema type: a body over the limit |
| 415 | `unsupported_media_type` | `rest::take` of a schema type: a JSON body sent as another media type |
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

```goose
fn rest::error_body(body: u8[>..]&, st: const app::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":");
    json::format_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    body.push('}');
}
```
