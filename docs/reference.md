# Reference

Plod's middleware, extractors, errors, and test helper: what each call does, what
it gives, and what it answers when it fails. The [tutorial](tutorial/README.md) introduces them
in order, and the [generator reference](generator.md) covers what `plod gen` writes.

## 1. Context and routes

`plod::serve(cfg, app) { cx => handle(cx) };` serves requests with the worker state
by reference in `cx.app`. `plod::serve(cfg, app, fresh)` also starts each request's
`cx.state` from `fresh`. A program with no state can call `plod::serve(cfg)`.
With request state alone, bind `var app = plod::NoState { .. };` and pass it beside
`fresh`. goose-http's `http::gather_budget(bytes)`, called
in `main` before `http::run`, bounds what each worker's gather pool promises at once:
the bodies it gathers ([Extractors](#3-extractors)), the replies `plod::ask` waits for
([Lanes](#41-lanes)), and what the middleware keeps for an answer at a later call
([Middleware](#2-middleware)). `plod::serve_epoll` has
the same forms, and the module `plod.tls` adds both with HTTPS ([HTTPS](#13-https)).

The context is `plod::Cx<S, A, R>`: the request state, the worker state, and the
router type. Its `req`, `body`, `out`, and `scratch` carry the request and response.
It has `plod::NoRouter` outside a `plod::routes` block, including when a waiting route
resumes. The block receives a context with an `http::Router`:

```rust
plod::routes(cx) { cx =>
    plod::get(cx, "/projects/:id") { show(cx, plod::param_int(cx, "id")); };
    plod::delete(cx, "/projects/:id") { remove(cx, plod::param_int(cx, "id")); };
};
```

`routes` builds the router, passes its context by reference, and runs its block as
the request's one route, so a `plod::fail` anywhere inside answers. When the block
leaves the request unanswered, with no reply, body, or room to send awaited, `routes`
answers as `plod::otherwise` does: 404, 405 with `Allow`, OPTIONS, 501, and 400
`bad_path`.

| Call | Does |
|---|---|
| `plod::get(cx, pattern) { ... }` | For a GET or HEAD on `pattern`, takes the request and runs the block |
| `plod::post`, `plod::put`, `plod::patch`, `plod::delete` | The same for their method |
| `plod::scope(cx, "/v1") { ... }` | For a path that starts with the prefix at a segment boundary, runs the block, whose routes match the rest of the path; then answers as `routes` does if the block didn't, and takes the request |
| `plod::route(cx) { ... }` | Inside `routes`, runs the block in its route; outside, opens a route of its own |
| `plod::scoped(cx) { ... }` | Inside `routes`, runs the block as a route of its own, answers as `routes` does if the block didn't, and takes the request; outside, runs the block. For middleware ([Middleware](#2-middleware)) |
| `plod::on(cx, method, pattern)` | Whether the request is `method` on `pattern`, for an `if` of the program's own; it doesn't take the request |
| `plod::otherwise(cx)` | Answers as `routes` does when no route answered, before the block ends; after a route that took the request, nothing |
| `plod::untaken(cx)` | Whether no route has taken the request yet; always true outside `routes` |

A route that matches takes the request, and the routes and scopes after it don't match.
Its block returns as any block does, so the code after the route runs, a middleware's
work after its block included. A scope owns the paths under its prefix: the routes
after it don't match them, and it answers a 404 or 405 for them itself, inside the
middleware around it.

A pattern has literal segments, `:name` for one segment, and `*name` at the end for
the rest of the path. A route that matches with another method adds its method to the
`Allow` of the 405 and OPTIONS answers, across scopes. A guard is an `if` around the
routes it guards, `if admin(cx) { plod::get(cx, "/admin") { ... }; }`: a request that
fails it gets 404, not 405. `get` and its kin, `scope`, `on`, `param`, `param_int`,
and `otherwise` require that router's context, so calls outside the block fail to
compile. A typed route helper
can name `type Cx = plod::Cx<St, App, http::Router>;` and take `cx: Cx&`.
The generated `api::dispatch(cx)` works with either context. Inside the block, it reads
the preceding routes' `Allow`, and answers nothing after one of them took the request.
Generated handlers receive path parameters as
arguments; pass those to helpers rather than read the last hand-written match.

`cx.kind` identifies the event the handler is called for: `http::REQUEST` for a request,
and the corresponding event for each later call ([Later calls](#4-later-calls)). `plod::resumed(cx)` is
true for every call after a request's first.

`plod::json` and `plod::json_bytes` answer `application/json`; `plod::text` answers
`text/plain; charset=utf-8`. `plod::empty(cx,
status)` answers without a body: 204 and 304 omit `Content-Length`, and other statuses write
`Content-Length: 0`.

### 1.1 JSON from a struct's fields

`plod::format_fields(out, v)` writes the struct `v` as a JSON object: every field, in
declaration order, keyed by its name as declared. A program's `format` overload calls
it, which `plod::json` then finds:

```rust
fn format(out: u8[>..]&, p: const Project&) { plod::format_fields(out, p); }
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

### 1.2 Cookies out

`plod::set_cookie(cx, cookie)` writes one `Set-Cookie` field through
`http::set_cookie`. Pass an `http::Cookie`, whose fields and validation are in
[goose-http's cookie API](https://github.com/kaitk/goose-http/blob/v0.4.3/docs/api.md#helpers-for-apis).
It returns `false` and writes nothing when goose-http refuses the cookie. Each call
writes a separate field.

Call it while the response's head is open: between `http::start` and `http::finish`,
or after `plod::begin` and before the first `plod::send` or `plod::end`.
`plod::json`, `plod::text`, and `plod::empty` write the whole answer at once, so use
the head and body writers separately for an answer with cookies:

```rust
http::start(cx.out, 200);
plod::set_cookie(cx, http::Cookie { name: "sid", value: id, path: "/",
                                  secure: true, http_only: true, same_site: "Lax" });
http::finish(cx.out, http::JSON, "{\"ok\":true}");
```

`plod::clear_cookie(cx, cookie)` uses the same writer, with an empty value,
`Max-Age=0`, and an expiry at the Unix epoch. It preserves the other attributes and
returns the same boolean. Pass the original name, path, and domain to remove the
same cookie. Neither helper stores cookies or adds request state.

### 1.3 HTTPS

`plod::serve` and `plod::serve_epoll` with HTTPS are in the module `plod.tls`, which
`plod` doesn't import, so a program without it builds without goose-tls and OpenSSL. To
use them, declare goose-tls in the root file at the tag goose-http's `tls.goose` names,
import the module, and give each worker goose-http's `http::TlsServer`:

```rust
import http from "github.com/kaitk/goose-http@v0.5.6";
import tls from "github.com/kaitk/goose-tls@v0.0.5";
import plod from "github.com/kaitk/plod@<tag>";
import plod.tls;

thread_fn worker(cfg: http::Config, ctx: tls::Context) {
    var server = http::tls_server(ctx);
    var app = plod::NoState { .. };
    let e = plod::serve(cfg, app, St { .. }, server) { cx => handle(cx) };
    http::release(server);
    if e.code != 0 { http::report(e); }
}
```

`plod::serve(cfg, app, fresh, server)` serves TLS 1.3 on the listeners that ask for
it, `Config.tls` or a `Listener`'s `tls`, and the rest as `plod::serve` does;
`plod::serve_epoll` takes the same arguments. A context made with
`["h2", "http/1.1"]` as its ALPN protocols serves h2 to a client that chooses it and
HTTP/1.1 to one that doesn't, on one port; one made with `["http/1.1"]` serves only
HTTP/1.1. Handlers don't change, and a WebSocket on a TLS listener is `wss://`. The
context, the listeners, and what the loops refuse are goose-http's
([HTTPS](https://github.com/kaitk/goose-http/blob/main/docs/api.md#https)), and the
build needs CMake and OpenSSL 3's headers
([goose-tls's setup](https://github.com/kaitk/goose-tls/blob/main/docs/development.md#openssl)).

**A context per connection.** Both forms also take a server with a chooser, goose-http's
`http::TlsServerOf<C>`, which moves a connection to another context at its ClientHello.
ACME's TLS-ALPN-01 challenge (RFC 8737) needs this: a client offering `acme-tls/1` for
the challenged name gets the challenge certificate, and every other client gets the
server's certificate and the routes, on the same port:

```rust
struct Chooser { challenge: tls::Context }

fn http::tls_hello(c: Chooser&, conn: tls::Conn) {
    if tls::server_name(conn) == "example.com" && tls::offers(conn, "acme-tls/1") {
        tls::use_context(conn, c.challenge);
    }
}

thread_fn worker(cfg: http::Config, ctx: tls::Context, c: Chooser) {
    var server = http::tls_server(ctx, c);
    var app = plod::NoState { .. };
    let e = plod::serve(cfg, app, St { .. }, server) { cx => handle(cx) };
    http::release(server);
    if e.code != 0 { http::report(e); }
}
```

The program calls `tls::choose_context(ctx)` once, before the workers start, and
declares `http::tls_hello` for its chooser's type, which the handshake calls once a
connection. The chooser is the worker's own, and the contexts it holds are the
program's to free. A challenge or a renewed certificate from another thread reaches
the chooser as the program arranges, such as by mail that `tls_hello` takes
([goose-http's context per connection](https://github.com/kaitk/goose-http/blob/main/docs/api.md#https)).

## 2. Middleware

Middleware is a block around the routes it applies to, inlined into the handler: a scope
can have its own, and a public route none.

| Call | Does |
|---|---|
| `plod::timed(cx) { ... }` | Adds `Server-Timing: app;dur=<ms>` with a 12-byte duration field padded with trailing spaces, and writes an access log line to standard error: method, target, status, bytes, milliseconds. `plod::timed(cx, false)` skips the log. |
| `plod::cors(cx, plod::Cors { origins: "...", .. }) { ... }` | Adds the CORS fields to every answer inside, errors included, for an origin in `origins` (separated by spaces, or `*`). `*` answers `Access-Control-Allow-Origin: *` and never sends credentials, whatever `credentials` says, so a program that sends credentials lists its origins. Answers a preflight with 204 itself, and an origin not listed with 403 `origin_not_allowed`. `methods`, `headers`, `expose`, `max_age`, and `credentials` set the rest. |
| `plod::security_headers(cx, cfg) { ... }` | Adds a prepared security policy to every answer inside, errors included. HTML and API presets, configurable per scope: [Security headers](#22-security-headers). |
| `plod::compressed(cx) { cx => ... }` | Compresses the answers inside, errors included, by the request's `Accept-Encoding`, with goose-http's gzip, deflate, and zstd. An optional module: [Compression](#21-compression). |
| `plod::bearer(cx) { token => ... }` | Fails 401 `unauthenticated` with `WWW-Authenticate: Bearer` without a bearer token; `plod::invalid_token(cx)` refuses one. `plod::bearer_token(cx)` returns it, for a generated router's security check. |

`timed`, `cors`, `security_headers`, and `compressed` work on either side of
`plod::routes`. Around it, every answer gets their fields, the 404s outside every
scope included. Inside it, each runs its block in `plod::scoped`, so a failure, a 404,
and a 405 inside it are answered there, with its fields. That also takes the request:
inside `plod::routes`, put such middleware in a scope, or after the routes beside it.
`bearer` and anything else that fails go inside `plod::routes`. A request has one
route: routes nested in routes don't inline, `plod::scoped`'s aside
([architecture](architecture.md#middleware-and-inlining)). A program's own `inline fn`
can nest several middleware and pass its block on, so a scope has one level:
[A stack of your own](tutorial/07-middleware.md#a-stack-of-your-own).

A program's own middleware that works after its block, or adds fields to answers,
runs its block in `plod::scoped`. Without it, the middleware sees a 404 in its block
before `plod::routes` writes it, and a failure inside unwinds past it:

```rust
// Logs each request its block answers, with the status and the time it took.
inline fn audited<F>(cx) {
    let begun = clock_ns();
    plod::scoped(cx) { F(); };
    audit(cx.state, cx.req.method, cx.req.target, cx.out.stream.status, clock_ns() - begun);
}
```

Which answers get the fields:

| Answer | CORS fields | `Server-Timing` and log line |
|---|---|---|
| Written in the route, at the request | yes | yes, the route's time |
| A response begun in the route (`plod::begin`, `plod::file`, `plod::upgrade`) | in its head | in its head |
| Written at a later call ([Later calls](#4-later-calls)) of a route that called `plod::ask`, `plod::pause`, or `plod::body_in_pieces` at the request: at `WAKE` or `TIMEOUT`, at a body's `BODY` or `END`, a response begun then, a 504 `timeout`, a 503 `unavailable`, or a 413 past the limit | yes | yes, timed from the request to the answer's head |
| Written once a body left to gather (`plod::body`) is whole, when the route runs again | yes | yes, timed from that run |
| Plod's 413 while a body is gathered, for a chunked body past its limit | no | no |

When a route leaves its request unanswered for a later call, each middleware keeps what it
decided with the exchange: the fields its answers get, and `timed`'s start and log
setting. Plod adds them to the answer that call writes, after goose-http's current
`Server` and `Date`, and drops them once the answer's head is written or the exchange
ends. What they keep, about 100 bytes, is a run of the worker's gather pool, promised
from its gather budget ([Extractors](#3-extractors)): a budget that can't promise it
answers the request 503 `unavailable` with `Retry-After: 1` and the fields, ends the
route's wait, and gives a route that reads its body in pieces `CLOSED`. A route that
uses none of these middleware keeps nothing. At a later call,
`cors`, `timed`, and `security_headers` run their block as it is, so a handler can
also wrap its later calls in them.

`timed` reserves its duration field in `cx.out.common` before the block and fills it
after the response is written, so the body doesn't move. Both `timed` and `cors` take
the context by reference. CORS looks for a preflight's request-method field only on
OPTIONS. `bearer_token` uses `http::bearer` and requires a token68 bearer token.

### 2.1 Compression

`plod::compressed` is in the module `plod.compression`, which `plod` doesn't import, so
a program without it builds without goose-compress. To use it, declare goose-compress in
the root file at the tag goose-http's `compression.goose` names, and import the
module:

```rust
import http from "github.com/kaitk/goose-http@v0.5.6";
import compress from "github.com/kaitk/goose-compress@v0.1.2";
import plod from "github.com/kaitk/plod@<tag>";
import plod.compression;

fn handle(cx) {
    plod::timed(cx) {
        plod::compressed(cx) { cx =>
            plod::routes(cx) { cx => ... };
        };
    };
}
```

The block gets its own context, as the block passed to `plod::routes` does. Its answer goes
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
| `plod::json`, `json_bytes`, `text`, and errors, of `min_size` bytes or more | Compressed, with `Vary` |
| Shorter, HEAD, 206, or for a request that accepts no coding | `Vary` alone |
| A type `http::compressible` refuses, such as `image/png`; one with a `Content-Encoding` already | As written |
| Without a body (`plod::empty`, 204, 304) | As written |
| Begun with `plod::begin`, for a request that accepts a coding | Compressed as it's sent, chunked, with `Vary` |
| Begun with `plod::begin` for a request that accepts a coding, but HEAD, 206, a status without a body, or HTTP/1.0 | `Vary` alone, without the length `begin` was given |
| Begun with `plod::begin`, for a request that accepts no coding | `Vary` alone, with the length `begin` was given |
| Begun with `plod::begin`, of a type `http::compressible` refuses, or with no type | As written |
| `plod::file`, `plod::relay`'s reply in pieces, `http::begin` | As written |

Put `compressed` around `plod::routes`, or around a scope's routes inside it, as
[`examples/compress`](../examples/compress/main.goose) compresses two scopes with options
of their own; either way the errors inside are compressed. Put it inside `timed`, which
then logs the compressed size. CORS and other fields added inside
it are kept. An answer written after the block returns, when a waiting route resumes,
is compressed only if the resumed handler runs inside `compressed` too. Each answer
inside is copied once, compressed or not: the response buffer can't shrink while a
handler holds the request. Request bodies sent with a `Content-Encoding` aren't
decoded.

A response begun with `plod::begin` inside `compressed` is compressed as goose-http's
`http::begin_compressed` compresses one: each `plod::send` is compressed and flushed as a
chunk of its own, so the client can decode all it has, and `plod::end` sends the coding's
trailer. Its later calls (`MORE`) needn't run inside `compressed`: the response keeps
the coding it began with, as [`examples/compress`](../examples/compress/main.goose)'s
`/v1/export` shows. Each response being compressed holds an encoder from goose-http's
pool until `plod::end`, or until `CLOSED` when it ends otherwise: about 460 KB for gzip
and deflate, and 1 MB for zstd. A worker builds one per response being compressed at the same time and
reuses it afterward. A program that doesn't compress keeps no bytes for it.

`plod::file` sends a file as it is, inside `compressed` too. Compressed on the fly, the
file would lose its `Content-Length`, its ranges, and the epoll loop's `sendfile`, and
goose-http's `http::serve_file` doesn't compress one either. goose-http serves a copy
stored compressed instead, `path.br`, `path.zst`, or `path.gz`, with
`http::open_precompressed`; `plod::file` opens `path` alone.

Declare your own middleware that takes a block as `inline fn`, as Plod's own are:

```rust
inline fn resolve_tenant<F>(cx) {
    let id, has = plod::header(cx, "X-Tenant");
    guard has else { plod::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Goose's `-O2` inlines a function called once only up to a size threshold, and a handler's
routes exceed that threshold as soon as they're passed as the block. A plain `fn` then stays a C function that reaches
the handler's locals through pointers, and every middleware around it stays out of line
too. `inline fn` folds it into the handler ([findings](goose-findings.md#a-function-called-once-isnt-inlined-past-a-size),
aardappel/goose#33).

### 2.2 Security headers

`plod::security_html()` and `plod::security_api()` return editable
`plod::SecurityHeaders` options. In worker setup, pass each scope's options to
`plod::prepare_security_headers(options)`, which validates them and writes the
field bytes once into a `plod::SecurityFields`. Keep that value for the worker's
life, and pass it to `plod::security_headers(cx, cfg) { ... }` by reference.

| Option | HTML | API | Values |
|---|---|---|---|
| `nosniff` | `true` | `true` | Emits `X-Content-Type-Options: nosniff`; `false` omits it. |
| `frame_options` | `"DENY"` | `"DENY"` | `"DENY"`, `"SAMEORIGIN"`, or `""` to omit. |
| `xss_protection` | `true` | `false` | Emits `X-XSS-Protection: 0`; `false` omits it. It never enables the legacy XSS filter. |
| `referrer_policy` | `"strict-origin-when-cross-origin"` | `""` | The eight policies below, or `""` to omit. |
| `hsts` | `true` | `true` | Emits `Strict-Transport-Security`; `false` omits it. |
| `hsts_max_age` | `31536000` | `31536000` | Nonnegative seconds, including `0` to revoke the policy. |
| `hsts_subdomains` | `true` | `true` | Adds `includeSubDomains` to HSTS. |
| `hsts_preload` | `false` | `false` | Adds `preload` to HSTS. |
| `opener_policy` | `"same-origin"` | `""` | COOP: `"same-origin"`, `"same-origin-allow-popups"`, `"unsafe-none"`, or `""`. |
| `resource_policy` | `"same-origin"` | `""` | CORP: `"same-origin"`, `"same-site"`, `"cross-origin"`, or `""`. |
| `embedder_policy` | `""` | `""` | COEP: `"require-corp"`, `"credentialless"`, `"unsafe-none"`, or `""`. |
| `content_security_policy` | `""` | `"frame-ancestors 'none'"` | CSP policy string; empty omits it. |
| `report_only` | `false` | `false` | Writes CSP as `Content-Security-Policy-Report-Only` instead. |
| `permissions_policy` | `""` | `""` | `Permissions-Policy` string; empty omits it. |
| `cross_domain_policy` | `"none"` | `"none"` | `X-Permitted-Cross-Domain-Policies`; empty omits it. |
| `dns_prefetch_control` | `true` | `false` | Emits `X-DNS-Prefetch-Control: off`; `false` omits it. |
| `cache_control` | `""` | `"no-store"` | `Cache-Control` string; empty omits it. |
| `no_cache` | `false` | `false` | Replaces `cache_control` with `no-cache, no-store, max-age=0, must-revalidate`, and adds `Pragma: no-cache` and `Expires: 0`. |

The eight referrer policies are `no-referrer`, `no-referrer-when-downgrade`,
`origin`, `origin-when-cross-origin`, `same-origin`, `strict-origin`,
`strict-origin-when-cross-origin`, and `unsafe-url`. Invalid option values or
HTTP field values, including strings containing CR or LF, abort during preparation.

HSTS is an ordinary configured field: both presets emit it, with no TLS check
or proxy option. Set `hsts = false` to omit it. The API preset sends the
[OWASP REST baseline](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html#security-headers)
plus `X-Permitted-Cross-Domain-Policies: none`. Document policies stay available
as options; the API preset omits them to save bytes on every answer. The HTML
preset leaves CSP, COEP, permissions, and caching to the application.

For routes that need another policy, prepare both policies at setup:

```rust
let options = plod::security_html();
var embedded_options = options;
embedded_options.frame_options = "";
embedded_options.content_security_policy = "frame-ancestors https://partner.example";
let site = plod::prepare_security_headers(options);
let embed = plod::prepare_security_headers(embedded_options);
```

Select one where the handler calls the middleware:

```rust
plod::security_headers(cx, if starts_with(cx.req.target, "/embed") { embed } else { site }) {
    // Dispatch routes here.
};
```

Nesting `security_headers` isn't supported. The middleware restores the outer
common fields when its block returns.

Around `plod::routes` or inside a scope, route errors carry its fields too.
It preserves the selected policy for deferred replies, timeout errors, and
bodies read in pieces, as `cors` does. A call after the request runs its block
without reapplying fields. Body-gathering errors raised before the handler runs
have no scope policy, as in the CORS table above.

When there are no outer common fields, the middleware points `cx.out.common`
at the prepared bytes. `http::start` copies them once into the response. With
outer common fields, it first copies those fields and the policy into scratch.
It validates and formats no fields during a request. Deferred responses retain
fields through `keep_fields`, copying to scratch first only if needed. This adds
no bytes to the connection's request state.

## 3. Extractors

Each extractor reads one part of the request, and fails the route with 400 when that
part is malformed ([Errors](#5-errors)), so it runs inside a route. A value that
has escapes to decode is decoded into `cx.scratch`, which lasts until the handler
returns. Otherwise the extractor returns the request's own bytes.

| Call | Gives | Fails with `detail` |
|---|---|---|
| `plod::param(cx, "name")` | the path parameter, decoded | |
| `plod::param_int(cx, "id")` | the path parameter as an `i64` | `id: integer` |
| `plod::query(cx, "q")` | the query parameter, decoded with `+` as a space, and whether it's there | |
| `plod::query_int(cx, "page")`, `plod::query_bool(cx, "all")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `page: integer`, `all: boolean` |
| `plod::form(cx, "name")` | the field of an `application/x-www-form-urlencoded` body, decoded with `+` as a space, and whether it's there | `name: encoding`; 415 `unsupported_media_type` for another media type |
| `plod::form_int(cx, "n")`, `plod::form_bool(cx, "on")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `n: integer`, `on: boolean` |
| `plod::part(cx, "name")` | the text of a part of a `multipart/form-data` body, as sent, and whether it's there | 415 `unsupported_media_type` for another media type or a missing or unusable boundary; `body: multipart` for a body that isn't multipart |
| `plod::part_int(cx, "n")`, `plod::part_bool(cx, "on")` | an `i64` or a `bool` (`true`, `false`), and whether it's there | `n: integer`, `on: boolean`, and `part`'s |
| `plod::file_part(cx, "pic")` | a part's bytes, its filename (`""` without one), its content type (`application/octet-stream` without one), and whether it's there | `part`'s |
| `plod::header(cx, "X-Request-Id")`, `plod::cookie(cx, "sid")` | the value, and whether it's there | |
| `plod::int_of(cx, v, "name")`, `plod::bool_of(cx, v, "name")` | `v` as an `i64` or a `bool` | `name: integer`, `name: boolean` |
| `plod::require(cx, "q", found)` | | `q: required` |
| `plod::take<T>(cx)` | a `T`, by `T`'s `from_request` overload | its own |
| `plod::body(cx, limit)` | the body, whole, of at most `limit` bytes (1 MB by default); a larger one in pieces with `plod::body_in_pieces` ([later calls](#4-later-calls)) | 413 `payload_too_large`; 503 `unavailable` past the worker's gather budget; 500 `body_too_late` at a later call than the request's |

A query parameter, form field, or cookie that repeats gives its first value, and its
name is compared as sent, without decoding it.

The form extractors read the body with `plod::body`, which gathers it as described below.
They accept a Content-Type with parameters, such as
`application/x-www-form-urlencoded; charset=utf-8`. A route that accepts a form over
1 MB calls `plod::body(cx, limit)` before the first form extractor.

The multipart extractors read the whole body the same way and take the first part
with the name asked for through goose-http's `http::find_part`, whose rules decide
what is malformed. What they return are slices of the body, never copies. An upload
read as it arrives goes through goose-http's `http::each_part`
([goose-http's API](https://github.com/kaitk/goose-http/blob/main/docs/api.md)), a
piece at a time with `plod::body_in_pieces` ([tutorial](tutorial/14-bodies-in-pieces.md#a-multipart-form)).

A program that builds its own `http::Router` can still pass it explicitly to
`plod::param(cx, r, name)`, `plod::param_int(cx, r, name)`, and `plod::otherwise(cx, r)`.

`plod::take<T>` reads any type with an overload declared in the `plod` namespace, as
`fn plod::from_request(cx, v: const app::Session?) -> app::Session`. `v` is always null,
and its type picks the overload. The generator writes one for each schema object, which
reads the JSON body: 415 unless the request says `application/json`, and 400
`invalid_body` for a body the reader refuses.

goose-http hands a body to the handler with its head when both fit its read buffer,
8 KB by default
([goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)).
`plod::body` reads a longer one too: at its first call, the route leaves
without an answer, `plod::serve` gathers the body up to the limit, and then calls the
handler again with the body whole. The code before a route's first `plod::body`,
`plod::take` of a JSON type, or form extractor therefore runs twice for such a body and
must not change state; an answer there, such as a 401, ends the request without gathering
the body. A `Content-Length` over the limit is refused with 413 before
the body is sent, and a chunked body once it passes the limit. The first call's limit
holds for the request, so a route that takes a JSON body over 1 MB calls `plod::body`
with its limit first; a generated route does so for its `x-body-limit`
([generator](generator.md)). `http::Config`'s `max_body`, 1 MB by default, caps
every route, so a program with a larger limit raises it too: to `api::MAX_BODY` with a
schema.

Each worker gathers bodies into goose-http's gather pool, memory it keeps for its life,
at the most it has held at once
([goose-http's parts](https://github.com/kaitk/goose-http/blob/main/docs/api.md#parts)).
A body with a `Content-Length` takes its head and its length, in one run placed at its
head, and a chunked one 16 KB, doubling as it fills. The gather budget, 64 MB by
default, is the most the worker promises at once, so that the memory follows the
configuration rather than what clients send. A program sets it with goose-http's
`http::gather_budget`, in `main` before `http::run`, for every worker:

```rust
http::gather_budget(16 * 1024 * 1024);
http::run(cfg, worker);
```

A body is promised its bytes at its head: a `Content-Length`'s, or for a chunked body
the route's limit, with the head. One the budget can't promise gets 503 `unavailable`
with `Retry-After: 1` there, in the program's error shape, before the body is sent and
before `100 Continue`; the connection stays open. A body admitted is never refused
later: a chunked one past its limit gets 413, and the connection closes. The pool can
grow past the budget by what its free spaces leave unused, since a budget of promises
can't see where the pool places a run. Bodies read with `plod::body_in_pieces` don't
count against the budget: a route that takes large bodies, or many at once, reads them
in pieces. The budget also holds the replies `plod::ask` waits for
([Lanes](#41-lanes)), and what the middleware keeps for an answer at a later call
([Middleware](#2-middleware)), which a budget too full to hold answers 503 at the
request.

```rust
plod::post(cx, "/projects") {
    let body = plod::take<api::ProjectCreate>(cx);
    let page, has_page = plod::query_int(cx, "page");
    plod::json(cx, 201, create_project(cx, body, if has_page { page } else { 1 }));
};
```

`plod::once(cx.state.profile) { load_profile(...) }` computes a value on its first call
in a request and returns it from then on. The slot is a `plod::Once<T>` field of the
request state, so each request starts with a fresh slot.

## 4. Later calls

A route that waits on another thread, reads its body in pieces, sends its response in
pieces, or takes an upgraded connection says what it waits on in `cx.state.use`, a
field of the program's `Use` enum, `None` for a route that waits on nothing: `plod::ask` puts the
lane's mark there ([Lanes](#41-lanes)), and the other calls the variant they're given.
`plod::serve` then calls the handler again for each event of that exchange, and the
handler sends each later call to a `resume` case function per variant, inside
`plod::on_reply`:

```rust
plod::serve(cfg, app, St { .. }) { cx =>
    if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
};
```

`plod::on_reply(cx) { ... }` is `plod::route` for a later call. It fails the route
with a lane's refusal before its block runs, and leaves `cx.state.use` as the route set
it, so a `CLOSED` after an early answer reaches the variant that holds what to release.
goose-http starts the request state afresh for each request. `cx.kind` says which
event it is, and `cx.req` is empty. A variant carries the request data its route needs,
and the request state holds the route's progress.

| The route called | The case function gets `cx.kind` | Plod handles |
|---|---|---|
| `plod::ask` | `http::WAKE`, at the lane's mark, with the job and its answer in `cx.reply`; on an upgraded connection, also `http::BODY` per arrival during the wait, and `http::TIMEOUT` | a refusal; a value's pieces, collected for one `WAKE`; `TIMEOUT`: 504 `timeout`, or 503 `unavailable` with `Retry-After: 1` for goose-http's `TIMEOUT` at once, with no timer free; except on an upgraded connection, whose route gets either |
| `plod::body_in_pieces` | `http::BODY` per piece, in `cx.body`; then `http::END`; or `http::CLOSED` | the limit: 413 |
| `plod::begin` | `http::MORE`; `http::CLOSED` | a `HEAD` request: no calls |
| `plod::pause`, before `plod::begin` | `http::TIMEOUT` | goose-http's `TIMEOUT` at once, with no timer free: 503 `unavailable` with `Retry-After: 1` |
| `plod::pause`, after `plod::begin` | `http::TIMEOUT`, the response still open; `http::CLOSED` if the client goes first | goose-http's `TIMEOUT` at once, with no timer free: the response ends, then `CLOSED` |
| `plod::own_waits`, then a wait of goose-http's, such as `http::wait_socket` | `http::WAKE` when the socket is ready or mail comes, with the mail's bytes in `cx.reply`; `http::TIMEOUT`, goose-http's at once included; `http::CLOSED` if the client goes during a wait | nothing: the route answers each |
| `plod::file`, `plod::files` | `http::MORE`; `http::CLOSED`, both for `plod::send_file` | a range, as 206; 304, 416, and `HEAD`: no calls |
| `plod::upgrade` | `http::BODY` per arrival; `http::CLOSED`; `http::DRAINED` after `http::after_drain` | |
| `plod::ws_upgrade` | `http::BODY` per arrival and `http::CLOSED`, both for `plod::ws_read`; `http::DRAINED` after `http::after_drain` | pings, Closes, and frames the protocol forbids ([WebSocket](#43-websocket)) |
| `plod::relay`, at a reply's first piece | none | the reply's later pieces |

`http::CLOSED` means that the exchange ended before the route finished, and that the
case function releases what the state holds, such as a file. It comes once, to a route
that called `body_in_pieces`, `begin`, `file`, or `upgrade`, when the client goes, when a body
passes its limit, when the route answers or fails before a body's `END`, when it
fails with its response begun, or when Plod ends a paused response; and to a route
that called `own_waits`, when the client goes during a wait. Anything the case function writes is discarded. A route that answers at the
`END`, or calls `plod::end`, gets none, nor does one that only asked, or paused before a response.

A failure after a response has begun can't be answered: its head has already been sent. The route
leaves the response unended, goose-http closes the connection, and the client sees the
response cut short.

| Call | Does | Fails with |
|---|---|---|
| `plod::body_in_pieces(cx, limit, u)` | With `u`, a variant of `Use`, in `cx.state.use`: the body in pieces as they arrive, up to `limit` bytes. A body that came whole with its head comes as one `BODY` and the `END`, and an empty one as the `END` alone. The code around it runs once. | 413 `payload_too_large` for a `Content-Length` over `limit`, before the body is sent; a chunked body past it gets 413 and the connection closes. 500 `body_already_read` after `plod::body`, and `plod::body` after it. 500 `body_too_late` at a later call than the request's. 500 `not_served` outside `plod::serve` and `serve_one`. |
| `plod::begin(cx, status, content_type, length, u)` | With `u` in `cx.state.use`, begins a response sent in pieces: `Content-Type` unless `content_type` is empty, and a `Content-Length` of `length`, or chunked for -1. `MORE` comes each time the client has taken what was sent; one that neither sends nor ends closes the connection. If the response begins while a body is being read, the body's pieces still arrive, followed by `MORE`. Inside `plod::compressed`, a response of a type worth compressing is compressed ([Compression](#21-compression)). | |
| `plod::pause(cx, ms, u)` | With `u` in `cx.state.use`, pauses the route for `ms` milliseconds before a response has begun: `TIMEOUT` comes after `ms` milliseconds, and the case function answers or waits again. Needs `Config.mail_slots` and `max_waiting`: past `max_waiting`, or with no mail slots, goose-http has no timer and gives `TIMEOUT` at once, tagged `http::NO_ROOM`, which Plod answers with 503 `unavailable` and `Retry-After: 1` without calling the handler. | 500 `already_waiting`; 500 `not_served` outside `plod::serve` and `serve_one` |
| `plod::pause(cx, ms)` | Pauses the response `plod::begin` began, for events sent over time such as Server-Sent Events: `TIMEOUT` comes after `ms` milliseconds, and the case function sends the next piece and pauses again, or ends. What was sent still goes out meanwhile, and no `MORE` comes until the pause ends; a `TIMEOUT` call that neither pauses nor ends gets `MORE` next. Call it in the route, or at `MORE` or `TIMEOUT`. Needs `Config.mail_slots` and `max_waiting`: past `max_waiting`, goose-http has no timer and gives `TIMEOUT` at once, tagged `http::NO_ROOM`, which Plod answers by ending the response. | 500 `not_sending` without a response begun and open; 500 `not_served` outside `plod::serve` and `serve_one` |
| `plod::own_waits(cx, u)` | With `u` in `cx.state.use`, gives the route every event of the waits it begins itself with goose-http, as on a socket with `http::wait_socket`, or for mail with `http::later`, as a database pool does: the `WAKE`, the `TIMEOUT`, which Plod then doesn't answer, goose-http's at once with no timer free included, and the `CLOSED` of a client that goes during a wait, where the route gives back what it holds. It holds from the call to the end of the exchange, so a `plod::ask`'s `TIMEOUT` comes to the route too. Each wait needs `Config.mail_slots` and `max_waiting`, as `http::later`'s does. | 500 `not_served` outside `plod::serve` and `serve_one` |
| `plod::send(cx, data)` | `http::send`: the next piece, or raw bytes after an upgrade. | |
| `plod::end(cx, trailers)` | `http::end`: ends the response, with trailers when chunked, or closes an upgraded connection. The route gets no more calls. | |
| `plod::file(cx, path, body, u, content_type)` | With `u` in `cx.state.use`, `http::serve_file`'s answer, with `ETag`, `Last-Modified`, and `Accept-Ranges`, and a type by `path`'s extension when `content_type` is empty. `body`, an `http::FileBody` in the request state, holds what's left to send. | 404 `file_not_found`, 403 `forbidden`, 500 `file_unreadable` |
| `plod::files(cx, dir, name, body, u)` | In a route, `plod::file`'s answer for the file in `dir` that the path parameter `name` names, decoded once. A name that is empty or ends in `/` serves that directory's `index.html`. A copy beside the file, `NAME.br`, `NAME.zst`, or `NAME.gz`, goes in its place when the request's `Accept-Encoding` takes it, with `Content-Encoding` and the original's type (`http::open_precompressed`); each answer has `Vary: Accept-Encoding`. | 404 `file_not_found` also for a `.` or `..` segment, a backslash, a colon, or NUL in the decoded name; 403 `forbidden`, 500 `file_unreadable` |
| `plod::send_file(cx, body)` | For the case function: at `MORE`, the next piece of up to 64 KB, and the end after the last; at `CLOSED`, closes the file. | |
| `plod::upgrade(cx, protocol, u)` | With `u` in `cx.state.use`, `http::upgrade`'s 101. The client's bytes then come as `BODY`, with no `END` and no limit, and `plod::send` writes bytes as they are. `http::upgrade_of(cx.req)` is what the request asks to switch to. An HTTP/2 stream can't switch: goose-http answers it 501, and the route gets no calls. | |

`plod::files` mounts a directory under a route that ends in `*name`, and its case
function is `plod::file`'s:

```rust
plod::get(cx, "/static/*name") { plod::files(cx, "/data/static", "name", cx.state.file, Use.File); };

fn resume(u: Use.File, cx) { plod::send_file(cx, cx.state.file); }
```

It reads the parameter as the path has it, still encoded, since a second decoding would
turn `%252e` into `.`. The router answers a `.` or `..` segment, escaped or not, with 400
`bad_path` before any route runs. Only a name that is empty or ends in `/` gets the
directory's `index.html`: a directory requested without the `/`, such as
`/static/docs`, answers 404 `file_not_found`, since its page's relative links would
resolve against `/static/`. The type comes from goose-http's `http::content_type_of`, and an extension it
doesn't know gets `application/octet-stream`.

`http::Config`'s `max_body` caps `plod::body_in_pieces`'s limit as it caps `plod::body`'s. A
piece of about 16 KB at each `MORE` keeps within `Config.max_queued`
([goose-http's long responses](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#long-responses)).
A route that upgraded can ask a lane (`plod::ask`), at the request or at a `BODY`.
Every later call goes to the `resume` of the variant in `cx.state.use`, and
`plod::ask` puts the lane's mark there, so while the route waits, the mark's `resume`
gets the client's bytes as `BODY`, and `plod::send` can answer them. It then gets the
reply as `WAKE`, or `TIMEOUT` when the time limit passes, in place of a 504, which
can't follow the 101. Only the `WAKE` carries a job, so this `resume` tells the events
apart by `cx.kind` before it calls `plod::job`, which fails with 500 `not_a_reply` at
any other. A `resume` that does nothing at `TIMEOUT` leaves the connection open, no
longer waiting. To get the bytes where they went before the wait, the program sets
`cx.state.use` back to the upgrade's variant at the `WAKE` and the `TIMEOUT`; nothing
restores it otherwise. `plod::end` during the wait ends it and closes the connection. A
`plod::ask` while the route waits already, as at a `BODY` during a wait, fails with 500
`already_waiting`, which closes the connection: an exchange has one wait, whose reply a
second job would share. A client can send at any time, so a route that asks at a `BODY`
checks `plod::is_waiting(cx)` first.

```rust
fn resume(u: Use.Asked, cx) {
    if cx.kind == http::WAKE {
        resume(plod::job<Asks>(cx), cx);   // the reply, with its job
    } else if cx.kind == http::BODY {
        plod::send(cx, cx.body);           // bytes during the wait
    } else if cx.kind == http::TIMEOUT {
        plod::send(cx, "timeout");
        cx.state.use = Use.Echo;           // the bytes after go to the upgrade's again
    }
}

fn resume(u: Asks.Lookup, cx) {
    plod::send(cx, plod::answer<Found>(cx).text);
    cx.state.use = Use.Echo;
}
```

A WebSocket is an upgrade with frames ([WebSocket](#43-websocket)). The tutorial builds an upload with `body_in_pieces`
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
struct App { reports: plod::Lane<Reports, Use> }

thread_fn reader(box: http::Box, jobs: plod::Jobs<Reports>) {
    var r = Reader { .. };
    plod::lane(box, jobs) { u, a => run(u, r, a); };
}

fn run(u: Reports.Totals, r: Reader&, a) {
    let t = totals(r, u.project);
    if t.entries == 0 { plod::fail(a, 404, "no_such_project"); }   // fails the route
    plod::reply_value(a, t);
}

fn resume(u: Use.Report, cx) { resume(plod::job<Reports>(cx), cx); }
fn resume(u: Reports.Totals, cx) { plod::json(cx, 200, plod::answer<Totals>(cx)); }

let reports = plod::lane_open<Reports>(http::LaneConfig { threads: 2, .. }, Use.Report, reader);
http::run(cfg, App { reports: reports }, worker);
plod::lane_stop(reports);
```

| Call | Does | Fails with |
|---|---|---|
| `http::LaneConfig { threads, slots, size }` | A lane's threads (1; at least 1, at most 64), and each box's `slots`, a power of two of at least 2 (64), of `size` bytes (256). | |
| `plod::lane_open<U>(cfg, mark, W)` | Opens a `plod::Lane<U, M>` of jobs of the enum `U`, with `mark`, through `http::lane_open`: spawns its threads, each the `thread_fn W(box: http::Box, jobs: plod::Jobs<U>)` with a box of its own. `plod::lane_open<U>(cfg, mark, a, W)` passes each `a` too: `thread_fn W(box: http::Box, jobs: plod::Jobs<U>, a: A)`. A `W` whose `jobs` names another enum than `U` doesn't compile. The `Lane` is flat, so it crosses `http::run` in worker state. | A box that fails to open ends the program. |
| `plod::lane(box, jobs) { u, a => ... }` | A lane thread's loop: the block gets each job, a `U` of `jobs`, a `plod::Jobs<U>`, and `a`, where its reply goes, in the order they came, until the lane is stopped and its box empty; then closes the box. A job the block neither replies to nor fails refuses with 500 `no_reply`. | |
| `plod::lane_job(jobs, bytes) { u, a => ... }` | One job of `plod::lane`, from a message's bytes: for a thread that writes its own loop, as one doing timed work between jobs does, and for a test that reads the job a route sent, with a `plod::Jobs<U> { .. }` of its own. `plod::lane_of<U>(box, mark)`, a lane of a box with no thread, and a `plod::Jobs<U>` literal passed here are for tests and hand-written loops: nothing checks their `U` against the lane's enum, as `plod::lane_open` checks a thread's. | |
| `plod::lane_stop(lane)` | `http::lane_stop`: stops every box of `lane` and waits for its threads, each of which takes what its box holds first. A full box can't refuse the stop. | |
| `plod::ask(cx, lane, job, ms, most)` | Sends `job`, a variant of the lane's enum, to the least busy thread of `lane`, the one whose box holds the fewest, or to the others in turn while each is full, and waits for the reply with the lane's mark in `cx.state.use` ([Later calls](#4-later-calls)), promised `most` bytes, 64 KB by default, of the worker's gather budget while it waits. A variant of another lane's enum doesn't compile. | 503 `unavailable` with `Retry-After: 1`, before the job is sent, when the gather budget can't promise `most`; 503 `unavailable` when every box is full, the lane is stopped, or the job is longer than a slot; 500 `job_too_large`, before the job is sent, when the job and its 4-byte length don't fit one message of the reply; 500 `already_waiting` |
| `plod::try_ask(cx, lane, job, ms, most)` | `plod::ask`, except that a job it can't admit doesn't fail the route. Returns `http::SENT` once the job is sent, the route waiting as `plod::ask` leaves it, or else why not, with nothing sent or promised and `cx.state.use` as it was: `plod::NO_BUDGET` when the gather budget can't promise `most`, `http::FULL` when every box is full, `http::STALE` once the lane is stopped, or `http::TOO_LONG` for a job longer than a slot. goose-http's `TIMEOUT` at once, with no timer free, comes after the handler returns, as for `plod::ask`. | 500 `job_too_large`; 500 `already_waiting` |
| `plod::reply_value(a, v)` | On the lane: replies `v`, a flat value, after the job, in pieces of the worker's message size, each marked as a value's, which the worker collects whole before the `resume` runs. A piece that finds the worker's box full waits for room, a millisecond at a time, until the route's wait ends. Returns false once the route has gone. | The route: 502 `reply_too_large` past the `most` its `plod::ask` gave |
| `plod::reply(a, data)` | On the lane: replies `data` after the job, in pieces of the worker's message size, for `plod::relay`, waiting for room as `plod::reply_value` does. Returns false once the route has gone. | |
| `plod::fail(a, status, code)` | On the lane: refuses the job, which fails the route with `status` and `code` before its `resume` runs, waiting for room as `plod::reply_value` does. A domain's `check(e, x)` that calls `plod::fail(x, ...)` serves a route's `cx` and a lane's `a` alike. | |
| `plod::try_reply(a, v)` | On the lane: `plod::reply_value` in one message, which never waits for room. Returns `http::SENT`, or why nothing was sent: `http::FULL` when the worker's box is full, `http::STALE` once the route has gone, or `http::TOO_LONG` when the job, its 4-byte length, and `v` don't fit one message. The job counts as answered either way, so a reply not sent leaves the route to its time limit, 504 `timeout`. | |
| `plod::try_refuse(a, status, code)` | On the lane: `plod::fail` in one message, as `plod::try_reply` sends a reply, with its results; `code` is cut to fit. The `run` returns after it. | |
| `plod::still_wanted(a)` | On the lane: whether the route still waits, for work worth skipping. A snapshot: the route can still go before the reply. | |
| `plod::job<U>(cx)` | In the mark's `resume`: the job the reply carries back. | 500 `not_a_reply` at another event than `WAKE`; 502 `bad_reply` |
| `plod::answer<T>(cx)` | In a job's `resume`: the value `plod::reply_value` replied, whole however many pieces it came in. | 502 `bad_reply` for a reply that isn't a `T`, as one `plod::reply` sent in pieces |
| `plod::relay(cx, status, content_type)` | In a job's `resume`: answers with the bytes `plod::reply` replied after the job, whole, or chunked as the pieces come. | 502 `bad_reply` |

`plod::try_ask` refuses at admission and leaves what follows to the route: it answers
its own way, or pauses and asks again within a deadline it keeps in its variant. A
refusal promises nothing and leaves the route not waiting, so it can pause:

```rust
plod::get(cx, "/items/:id") {
    let job = Looks.Item { id: plod::param_int(cx, "id") };
    if plod::try_ask(cx, cx.app.items, job) != http::SENT {
        plod::pause(cx, 5, Use.Retry { job: job, until: clock_ns() + 250000000 });
    }
};

fn resume(u: Use.Retry, cx) {
    if plod::try_ask(cx, cx.app.items, u.job) == http::SENT { return; }
    guard clock_ns() < u.until else { plod::fail(cx, 503, "busy"); }
    plod::pause(cx, 5, u);
}
```

A server whose lanes every worker asks answers a refusal at once, without retrying, and
sizes its boxes from the asks each worker admits
([Sizing a lane's admissions and boxes](best-practices/lanes.md#67-sizing-a-lanes-admissions-and-boxes)).

`plod::try_reply` and `plod::try_refuse` are the lane's side of the same rule: a send to
a full box returns at once, and the lane decides. `plod::reply_value`, `plod::reply`,
and `plod::fail` wait for room instead, which suits most lanes: every lane that replies
to a worker shares its box, as do the pieces of a long reply, which the wait paces. A
lane that every worker asks uses `try_reply`, so that one worker whose box is full
doesn't hold up the jobs of all the others; the reply it drops ends as that route's
504:

```rust
fn run(u: Looks.Item, c: Cache&, a) {
    guard plod::still_wanted(a) else { return; }
    let row, found = look_up(c, u.id);
    guard found else {
        plod::try_refuse(a, 404, "not_found");
        return;
    }
    if plod::try_reply(a, row) == http::TOO_LONG { plod::try_refuse(a, 500, "reply_too_long"); }
}
```

`ms` defaults to 5000, as for every `plod::ask` and `plod::try_ask`. A reply longer than one message of
the worker's box, `http::Config.mail_size` bytes, 256 by default, comes in pieces. The
pieces of a `plod::reply_value` carry a tag bit of their own, `plod::REPLY_VALUE`, and
the worker collects them in a run of its gather pool, the memory it gathers bodies in,
up to the `most` bytes `plod::ask` promised the reply from the gather budget
([Extractors](#3-extractors)): the echoed job, its length, and the
value. The `resume` runs once,
at the last piece, with the whole reply, so `plod::job` and `plod::answer` read it as
they read one message. The wait's time limit restarts at each piece. A reply past
`most` fails the route with 502 `reply_too_large`, or cuts short
a response already begun, and leaves the mark in `cx.state.use`, as a timeout does. A
client that goes, or a time limit that passes, before the last piece frees what was
collected. `plod::reply`'s pieces aren't collected: `plod::relay` sends each on as it
comes, so the worker holds one piece at a time. Raising `mail_size` to the largest job
and answer avoids pieces altogether, at the cost of every slot of every worker's box.
The request state keeps only the mark: what a `resume` needs from the request goes in
the job, which comes back with the reply.

The reply's first message holds the job, behind its length in 4 bytes, so a job must
fit one message with them: `plod::ask` fails the route with 500 `job_too_large` before
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
`plod::lane` answers 500 `no_reply` for a catch-all `run` that doesn't reply; nothing
catches one that does, or a catch-all `resume`. Don't write either.

The best practices give each kind of slow work a lane, and grow one by threads
([Lanes of several threads](best-practices/lanes.md#66-lanes-of-several-threads)).

### 4.2 Server-Sent Events

`plod::sse_begin(cx, u)` begins a 200 response through `plod::begin`, with `u` in
`cx.state.use`. It sets `Content-Type: text/event-stream`, `Cache-Control: no-cache`,
and `X-Accel-Buffering: no`. A HEAD request gets these fields and no body or later
calls. Each helper below sends one complete frame through `plod::send`:

| Call | Sends |
|---|---|
| `plod::sse_event(cx, event, data)` | A named event, with one `data:` line per line of `data`, then a blank line. An empty name uses the browser's default event type. Returns `false` without writing for a name containing CR or LF. |
| `plod::sse_data(cx, data)` | An unnamed data event. |
| `plod::sse_json(cx, v, event)` | JSON from `v`'s `format` overload, as data in the named event. `event` defaults to `""`. Returns the same boolean as `sse_event`. |
| `plod::sse_comment(cx, text)` | A comment for a heartbeat, with one `:` line per line of `text`. `text` defaults to `""`. Comments dispatch no event. |
| `plod::sse_retry(cx, ms)` | The browser's reconnect delay in milliseconds. Returns `false` without writing for a negative delay. Zero is allowed. |

Data and comments split LF, CRLF, and bare CR, including empty and trailing lines.
Every line gets its prefix, so text containing newlines cannot inject another field.
JSON uses the same writer as `plod::json`: give the struct a JSON `format` overload,
hand-written, generated, or using `plod::format_fields` ([JSON writers](#11-json-from-a-structs-fields)).

Pause between frames with `plod::pause(cx, ms)`, handle `http::TIMEOUT` in the
variant's resume function, and finish with `plod::end`. Check HEAD before pausing:

```rust
plod::sse_begin(cx, Use.Events);
if cx.out.head { return; }
plod::sse_comment(cx, "alive");
plod::pause(cx, 15000);
```

At each timeout, send the next event or a heartbeat and pause again. The existing
[later-call rules](#4-later-calls) apply, including timer capacity and `CLOSED` when
the client leaves. The helpers keep no stream state of their own and add no work to
requests that don't call them.

### 4.3 WebSocket

`plod::ws_upgrade` and `plod::ws_read` are in the module `plod.websocket`, which `plod`
doesn't import, so a program without it builds without goose-hash. To use them, declare
goose-hash in the root file at the tag goose-http's `websocket.goose` names, import the
module, and keep the connection's `http::WebSocket` in the request state:

```rust
import http from "github.com/kaitk/goose-http@v0.5.6";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import plod from "github.com/kaitk/plod@<tag>";
import plod.websocket;

enum Use { None, Echo }

struct St { use: Use = Use.None, ws: http::WebSocket = http::WebSocket { .. } }

// in a route
plod::get(cx, "/ws") { plod::ws_upgrade(cx, cx.state.ws, Use.Echo); };

fn resume(u: Use.Echo, cx) {
    plod::ws_read(cx, cx.state.ws) { op, data => http::ws_send(cx.out, op, data); };
}
```

| Call | Does | Fails with |
|---|---|---|
| `plod::ws_upgrade(cx, ws, u, protocol)` | With `u` in `cx.state.use`, answers a request to open a WebSocket with 101 and `Sec-WebSocket-Accept`, as `plod::upgrade` does, and promises `ws` its `limit`, 64 KiB by default, and `http::WS_SLACK` bytes of the worker's gather pool, under the budget `http::gather_budget` sets. Set `ws.limit` before it. With `protocol`, the 101 names it in `Sec-WebSocket-Protocol`; `http::field_of(cx.req, "sec-websocket-protocol")` gives those the client offered. | 426 `upgrade_required`, with `Connection: Upgrade` and `Upgrade: websocket`, or with `Sec-WebSocket-Version: 13` for another version; 400 `bad_handshake` for a method other than `GET`, a malformed `Sec-WebSocket-Key`, or a `protocol` that isn't a valid field value (`http::is_field`); 501 `not_implemented` on an HTTP/2 stream; 503 `unavailable` with `Retry-After: 1` where the budget can't promise `ws` its bytes |
| `plod::ws_read(cx, ws) { op, data => ... }` | For the case function: at `BODY`, reads the frames `cx.body` completes and runs the block with each whole message, `op` `http::WS_TEXT` or `http::WS_BINARY`, a message in fragments joined; `data` lasts until the block returns. At `CLOSED`, gives back what `ws` holds. Other kinds, such as `TIMEOUT`, are the case function's. | |

Send with goose-http's `http::ws_send(cx.out, op, data)`, at any later call, and close
with `http::ws_close(cx.out, ws, code, reason)`. A ping gets its pong and the client's
Close its Close without the block, and a frame the protocol forbids or a message past
`ws.limit` closes the connection with its close code
([goose-http's WebSocket](https://github.com/kaitk/goose-http/blob/main/docs/api.md#websocket)).
Once the connection closes, from either side, the case function gets `CLOSED`, where
`ws_read` gives the pool its bytes back, so pass `CLOSED` to it too. A route that waits
on a lane gets the frames in the mark's `resume`, as for [`plod::upgrade`](#4-later-calls).
A route that publishes to a client that may read slowly calls
`http::after_drain(cx.out)` after a batch, and sends the next one when the case function
gets `http::DRAINED`
([goose-http's broadcasts](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#broadcasts-to-upgraded-connections)).
[`examples/websocket`](../examples/websocket/main.goose) echoes each message.

## 5. Errors

By default, every error Plod answers is a JSON object whose member `error` is a
code in snake_case, with `detail` and `at` where the table names them; a program can write
another shape, as the end of this section shows:

```json
{"error":"project_not_found"}
```

| Status | Code | From |
|---|---|---|
| any | the code given | `plod::fail(cx, status, code)` in a route, or `plod::fail(a, status, code)` on a lane |
| 400 | `invalid_body`, with `detail` and `at` | `plod::fail_body(cx, r)`, for a body a JSON reader refused |
| 400 | `invalid_parameter`, with `detail` | the [extractors](#3-extractors), `plod::fail_param`, and the generated router: a parameter missing, malformed, or outside its schema, as `id: integer`, `q: required`, or `page: minimum` |
| 400 | `bad_path` | `plod::routes` and `plod::otherwise`: a path with a dot-segment or an escaped control byte |
| 400 | `bad_handshake` | `plod::ws_upgrade`: a method other than `GET`, a malformed `Sec-WebSocket-Key`, or a subprotocol that isn't a valid field value ([WebSocket](#43-websocket)) |
| 401 | `unauthenticated`, with `WWW-Authenticate: Bearer` | `plod::bearer`: no bearer token |
| 401 | `invalid_token`, with `WWW-Authenticate: Bearer error="invalid_token"` | `plod::invalid_token(cx)` |
| 403 | `origin_not_allowed` | `plod::cors`: an `Origin` it doesn't list |
| 404 | `not_found` | `plod::routes` and `plod::otherwise`: no route's path matched |
| 405 | `method_not_allowed`, with an `Allow` field | `plod::routes` and `plod::otherwise`: a route's path matched with another method |
| 403 | `forbidden` | `plod::file`: a file the program may not read |
| 404 | `file_not_found` | `plod::file`: no file, or a directory, at the path |
| 413 | `payload_too_large` | `plod::body`, `plod::body_in_pieces`, `plod::take` of a schema type, and the form extractors: a body over the limit |
| 415 | `unsupported_media_type` | `plod::take` of a schema type: a JSON body sent as another media type; the form extractors: a body that isn't `application/x-www-form-urlencoded`; the multipart extractors: a body that isn't `multipart/form-data` with a usable boundary |
| 426 | `upgrade_required`, with `Connection: Upgrade` and `Upgrade: websocket`, or `Sec-WebSocket-Version: 13` | `plod::ws_upgrade`: a request that doesn't ask for a WebSocket, or asks for another version |
| 500 | `already_waiting` | `plod::ask` or `plod::pause(cx, ms, u)` while the route waits already, as at an upgraded connection's `BODY` during a wait |
| 500 | `body_already_read` | `plod::body_in_pieces` after `plod::body`, or `plod::body` after `plod::body_in_pieces` |
| 500 | `body_too_late` | `plod::body`, `plod::body_in_pieces`, and the extractors that read the body, at a later call than the request's, as in a `resume` |
| 500 | `file_unreadable` | `plod::file`: a file that couldn't be opened for another reason |
| 500 | `job_too_large` | `plod::ask`: a job that, with its length, doesn't fit one message of the reply ([Lanes](#41-lanes)) |
| 500 | `no_reply` | `plod::lane`: a job whose `run` neither replied nor failed |
| 500 | `not_a_reply` | `plod::job` at another event than `WAKE`, as an upgraded connection's `BODY` during a wait |
| 500 | `not_sending` | `plod::pause` without a response begun with `plod::begin` and still open |
| 500 | `not_served` | `plod::body_in_pieces` or `plod::pause` with a context that `plod::serve` or `serve_one` didn't make |
| 501 | `not_implemented` | `plod::routes` and `plod::otherwise`: a method HTTP doesn't define; `plod::ws_upgrade` on an HTTP/2 stream |
| 502 | `bad_reply` | `plod::job`, `plod::answer`, and `plod::relay`: a reply that doesn't hold its job, or a value of the type read |
| 502 | `reply_too_large` | `plod::ask`: a reply of `plod::reply_value`, in pieces, past the `most` the ask gave ([Lanes](#41-lanes)) |
| 503 | `unavailable` | `plod::ask`: every box of the lane is full, or the lane is stopped ([Lanes](#41-lanes)) |
| 503 | `unavailable`, with `Retry-After: 1` | `plod::body`, `plod::take` of a schema type, and the form extractors: a body past the worker's gather budget ([Extractors](#3-extractors)); `plod::ask`: a reply past it; `plod::cors` and `plod::timed`: fields kept for a later answer past it; `plod::ask` and `plod::pause(cx, ms, u)`: no timer free ([Later calls](#4-later-calls)); `plod::ws_upgrade`: a WebSocket's bytes past the budget |

The generated router answers 404, 405, 501, and `bad_path` as `plod::otherwise` does,
through `plod::no_route`, `plod::no_method`, and `plod::not_found`. Each takes the status
from goose-http's `http::unrouted`.

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
there are none); the status line and the fields stay Plod's:

```rust
fn plod::error_body(body: u8[>..]&, st: const app::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":");
    http::json_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    body.push('}');
}
```

To use [RFC 9457 problem details](https://www.rfc-editor.org/rfc/rfc9457.html),
have that overload call `plod::problem_body`, and select the media type with
`plod::error_type` for the same state type:

```rust
fn plod::error_body(body: u8[>..]&, st: const app::St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    plod::problem_body(body, status, code, detail, at);
}

fn plod::error_type(st: const app::St&) {
    "Content-Type: application/problem+json\r\nContent-Length: "
}
```

Both overloads resolve at compile time. They apply to every error in the table,
including `plod::fail` and errors answered at later calls. Programs without the
overloads keep the default body and `application/json`.
`error_type` returns the fields `http::finish` takes, ending in `Content-Length: `;
its default returns `http::JSON`. The status line, `Allow`, `WWW-Authenticate`, and
`Retry-After` stay the same.

| Input | Problem member |
|---|---|
| Constant | `type` is always `"about:blank"` |
| `status` | `status`, a number, and `title`, the reason phrase goose-http uses for that status; an unlisted status has an empty title |
| `detail` | `detail`, unchanged, when not empty |
| `at` | `at`, an extension member, when not negative; still a byte offset in the body |
| `code` | Accepted by the helper but not written |

For example, a reader's error becomes:

```json
{"type":"about:blank","title":"Bad Request","status":400,"detail":"name: maxLength","at":31}
```

The preset omits the optional `instance`: the hook has no request path, including
for delayed errors. A program that needs it can write its own `error_body` overload
using an instance it keeps in its request state.

## 6. Testing

| Call | Answers |
|---|---|
| `plod::serve_one(text) { cx => ... }` | The response's bytes to `text`, one request's bytes, answered through the block inside `plod::route`, as `plod::serve` answers it |
| `plod::serve_one(text, app) { cx => ... }` | The same, with the worker state by reference in `cx.app` |
| `plod::serve_one(text, app, fresh, cfg) { cx => ... }` | The same, with `fresh` as the request state and `cfg`'s limits; `cfg` is optional. The gather budget is the one `http::gather_budget` last set |
| `plod::serve_one(text, app, fresh, wakes, cfg) { cx => ... }` | The same, with `wakes`, a `plod::Wake` for each wait of a route that calls `plod::ask` or `plod::pause`, in order |
| `plod::Wake { data, tag, timeout, early, sent }` | What a wait gets in place of the thread it asked: a reply of `data` with `tag`, as `plod::wake` gives them, or with `timeout: true`, the end of the wait, which is a `plod::pause`'s time come; with `early: true` as well, goose-http's `TIMEOUT` at once, tagged `http::NO_ROOM` for want of a timer (503 for `plod::ask` and before `plod::begin`, or the end of the response after it); on an upgraded connection, `sent` comes first, as one `http::BODY` during the wait |
| `plod::play(lane, job) { u, a => ... }` | Runs `job`, a variant of `lane`'s enum, through the block, as `plod::lane` runs it, with no thread or mail, and returns its reply, a `plod::Played`: an answer, a refusal for a `plod::fail`, its code whole, or 500 `no_reply` for neither. `plod::still_wanted` is true. The block is the lane's own, `run(u, state, a)`, to test a use case, or a stand-in that replies what a test needs. |
| `plod::wake(p)` | The `Wake` that gives a route what `p`, a `plod::Played`, replied |
| `plod::refusal(p)` | The status and code of the refusal `p` replied, or 0 and `""` for an answer |

A body that doesn't fit in `cfg.max_head` with its head comes in pieces of
`cfg.max_head` bytes: gathered as the server gathers it, within the gather budget,
so the block runs again once it's whole, or passed to a route that called `plod::body_in_pieces`. A body shorter than its
`Content-Length` is a client that hung up midway: its pieces come, then `http::CLOSED`
in place of `http::END`. A response begun with `plod::begin` or `plod::file` is taken to
its end, `http::MORE` at a time, as by a client that keeps up. On a connection the route
upgraded, the bytes of `text` after the request's head are the client's: they come as
one `http::BODY` once the route doesn't wait, and then the client closes. A request goose-http refuses gets its
refusal, and a block that writes no answer gets 500. An HTTP/1.1 request without `Host`
is given `Host: localhost`. A chunked body isn't decoded: give a test request a
`Content-Length`. The response has no `Date` or `Server` field
([tutorial](tutorial/09-testing.md)).

A route that calls `plod::ask` sends its job, or gets 503 for a full box, or 500
`job_too_large` for a job that doesn't fit a message of `cfg.mail_size` bytes. `serve_one`
then calls the handler again with the wait's `Wake`, as `plod::serve` calls it when the
reply comes: as `http::WAKE`, in pieces of `cfg.mail_size` bytes with the tags
`plod::reply` and `plod::reply_value` give them, a value's collected whole within
the `most` its `plod::ask` gave, a refusal, its code cut to one message as a lane cuts it, as
the route's failure, or as the timeout's 504, which an upgraded connection gets
as `http::TIMEOUT`. On an upgraded connection, the `Wake`'s `sent` comes first, as one
`http::BODY` during the wait. A piece that comes once the route
no longer waits is dropped. A wait with no `Wake` left ends the exchange: the answer is
what the route wrote, or 500 for nothing, and a route paused with its response open
gets `http::CLOSED`, as for a client that goes. A paused route gets each `Wake` with
`timeout: true` as its `http::TIMEOUT`, or with `early: true` as 503 before `plod::begin`
and the end of the response after it. No thread runs and no time passes, so a reply
that comes late, or a client that goes while its job waits, is tested over HTTP
([tutorial](tutorial/16-testing.md)).
