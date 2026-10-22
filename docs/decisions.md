# Decisions

This page records goose-rest's design decisions for contributors and agents: each one dated,
with its reason and what was rejected, and the spike results, the Elysia study, and the
later uses behind them. How goose-rest works as it is now is in
[Architecture](architecture.md). A change that contradicts a decision here updates it in
the same change; a decision that replaces an earlier one says so, and both stay.

## Scope

Scope (2026-10-13): a general framework, not one shaped by an application. Snowtime
native, and a porting kit for Goose like the Rust one Snowtime's port started, are later
uses that inform the design ([Later uses](#later-uses)); neither is built here.

CORS, sessions, and middleware are left to a framework by `goose-http`'s scope
(README). A template engine, an ORM, and WebSocket aren't part of the framework.
The generator reads OpenAPI as its input. Writing an OpenAPI document from the routes,
as Elysia's openapi plugin does, is planned for later (2026-10-15).

An HTTP client is in scope, and it's goose-http's `http.client` (2026-10-22). The
framework is to become Plod, for both sides of HTTP. A program makes its requests with
`http::get`, `http::post`, and the rest directly, and writes a JSON body with the
`format` overload its responses use, `rest::format_fields` for a struct's fields.
goose-rest adds no wrapper: the client needs nothing of goose-rest's, and goose-acme
uses the same one. Rejected: a module `rest.client`, drafted the same day, which used
nothing of goose-rest's and would have left goose-acme with its own copy.

## The language

The design rests on the properties of Goose that
[Architecture](architecture.md#how-goose-shapes-the-package) lists: no handler table,
middleware as an inlined block, extractors by overload, no derive, no shared memory, and
no async. They were read from the spec at `a6249a4` (2026-10-12), and each was checked
by a spike ([Spike results](#spike-results-2026-10-13)).

## The generator

Optional: it writes what a program would otherwise write by hand,
from an OpenAPI document. Its model is Elysia 2, the `kiana` branch of
`elysiajs/elysia`, read at `c91f61f` (2026-10-11). Its design, from `src/`:

- **One composed function per route.** `compile/handler/jit.ts` writes each route's
  handler as source. It holds only the hooks that route has, only the request parts
  Sucrose finds the handler reading (query, headers, body, cookie), the validators
  inline, and a synchronous path up to the first `await`.
- **Dispatch.** `handler/fetch.ts` looks a static path up in a map by method, then by
  path. Paths with parameters go to a radix tree (memoirist). A route given a fixed
  `Response` goes into Bun's own router and is answered before any JavaScript runs.
- **Schemas to code.** TypeBox schemas compile to checks. exact-mirror writes a response
  normalizer that copies only declared fields. Coercion plans turn query strings into
  numbers, and defaults are merged ahead of time.
- **AOT.** A build plugin runs the app once, captures each route's handler and
  validator source in a manifest module (`elysia/compiled`), and ships it in the
  bundle. At run time nothing is generated or evaluated, and TypeBox is left out. A
  fingerprint catches an app that changed after the build.

Half of that machinery composes, per route, the code that Goose's monomorphization and
inlined blocks already compose. The AOT step mostly removes start-up and memory costs:
the Elysia 2 post measures the first request after start-up at 0.851 ms on 1.4 and
0.046 ms with AOT, not steady throughput. What carries over is the rest, done by a
generator: a Goose program that reads a schema file and writes Goose source, which the
build compiles with the handlers.

| Elysia 2 | goose-rest |
|---|---|
| A composed handler per route, with only its hooks | The compiler does it. Middleware wraps a group of routes by nesting, as Elysia's `guard` and scoped plugins do, and inlines into each (spike 04). |
| Sucrose: parse only what the route reads | Nothing to add. `goose-http` keeps header lines as bytes and scans them only when asked, and an extractor runs only where a handler calls it. |
| Signed cookies verified on first read (`verify: 'lazy'`, the default) | **Carries over.** A middleware separates what must run (reject a bad token) from what can wait (decode claims, verify a cookie's signature), and hands the handler a lazy extractor that does the second on first call and keeps the result for the request. |
| A synchronous path up to the first `await` | A route that never waits keeps no state on the connection. Only routes that hand off to a thread or timer pay for it. |
| Compiled checks, exact-mirror, coercion plans | **Carries over.** Each schema becomes a struct, a reader that dispatches keys by length and bytes and validates as it reads, and a writer with each key's bytes as a constant that writes only declared fields. Path and query parameters get typed extractors. |
| Static paths in a map, the rest in a radix tree | **Carries over.** The route list becomes a dispatch function: static paths by length then bytes, parameterized ones by nested `match` and compares on segments, each handler called by name. |
| Fixed responses served by Bun before JavaScript | Small gain. A fixed response's head becomes a constant beside `goose-http`'s cached `Date`. |
| The dry run, the manifest, the fingerprint | Not needed. Elysia runs the app to find its routes because JavaScript declares them in code. Here the schema file declares them, and the generated code names each handler with its types, so a schema and handlers that disagree fail to compile. |

Elysia doesn't skip a parent's hook because a route ignores its result. Sucrose's
inference is the union over the handler and every hook in its chain
(`src/sucrose.ts`), so a group's hook that reads the cookie makes every route in the
group parse it. A `derive` always runs, as it must: it can reject the request. Only
signed-cookie verification is deferred to first read. goose-rest can do better than
inheritance by nesting: OpenAPI declares `security` per operation, so the generated
router applies a token check only to the operations that name it.

The router the generator writes does what was out of reach by hand. A 404 or 405 costs
no more than a match. Each path's `Allow` is a constant. No hand-kept table pairs route
numbers with handlers. Handlers keep the shape of the hand-written framework: middleware
and extractors stay blocks in the handler.

Whether the router is worth it is measured, not assumed. The serialize and template
modes of goose-http's REST tiers split the JSON writer's cost from the HTTP layer's,
which bounds what generated writers can save. A hand-written if chain at 60 routes
bounds what a generated router can save.

Decided (2026-10-13): the generator writes the router. At 60 routes in prefix scopes,
the last route of a scope, a 404 inside one, and a 405 each cost about 6,000
instructions a request more than one route, because each `http::on` scans the path
again from its start (`bench/routes.sh`). Hand-written routes stay the API without a
schema.

### The contract: OpenAPI, optionally written in TypeScript

Decided (2026-10-13): the generator's input is a subset of OpenAPI 3.1, whose types are
JSON Schema.

- Paths and methods map to routes, `operationId` to the handler's name, and path and
  query parameters to typed extractors.
- Clients, documentation, and test tools read it as it is.
- It is the format a TypeScript backend can already emit, so one contract can describe
  two backends of one API.

The subset grows with use. It starts with objects, arrays, strings with length and
format, integers and numbers with bounds, enums, nullable fields, and `$ref`. A
construct outside the subset is a generator error, not silently dropped. The
[generator reference](generator.md) lists the subset as built.
`pattern` waits on anchors in Goose's `regex`
([findings](goose-findings.md#the-regex-module-has-no-anchors-so-json-schemas-pattern-cant-be-checked)).

The OpenAPI JSON is the whole input: the Goose generator reads it and needs nothing else,
so goose-rest itself needs no JavaScript toolchain. A schema format of goose-rest's own
(TypeSpec, or Goose struct declarations with annotations) was set aside: each would be
another language beside OpenAPI.

Decided (2026-10-13), implemented (2026-10-14): an optional TypeScript helper
for writing that JSON, `ts/api.mts`. JSON is JavaScript notation, so a TypeScript file
holding the document as an object literal reads almost as the JSON does, and adds what
JSON lacks: comments, shared fragments as constants, and functions for repeated shapes.
Its main value is TypeScript types that describe only the subset goose-rest supports.
The file passes the document to the helper's `api()`, whose `const` type parameter
keeps the literal types, and `tsc` rejects a keyword, a format, a shape, or a parameter
location the generator can't handle while the schema is being written, instead of when
the generator runs. With the literals, it also rejects a `$ref` to a missing component
and a `required` name that isn't a property. Cycles, names, and number values stay the
generator's checks. Running the file with Node or Bun writes `api.json`. Two steps, TypeScript
to OpenAPI to Goose, keep each tool small and leave the JSON as an inspectable file
between them.

The case for it is an application that already has a TypeScript backend and gains a
Goose one. Snowtime is that shape: 45 routes in Hono routers per domain, with valibot
schemas for each input and output (`src/server/<domain>/<domain>.schemas.ts`), and
conformance tests over HTTP that any backend must pass. Its Rust port keeps the
TypeScript app as the source of the contract, and a Goose port would too. A contract
exported from those schemas, or written beside them in the helper, keeps both backends
on one definition. Decided (2026-10-13):

- The helper lives here, in `ts/`, until the subset settles: the commit that teaches the
  generator a keyword changes the helper's types and their tests with it.
  `scripts/test.sh` runs those tests only where `tsc` is installed. Publishing it to npm would be
  the reason to move it to a repository of its own.
- It doesn't export from valibot. valibot's own exporter does that, and the generator
  refuses what falls outside the subset. Where the export succeeds and the backends
  still differ, as with transforms such as `v.trim()` and valibot's `maxLength`
  counting UTF-16 units where JSON Schema counts code points, the conformance tests are
  the check.

### Goose's data model in generated code

From spec §3, §4.3, §7.8, and §11.2, condensed in the language author's thread of
2026-10-07 (https://x.com/wvo/status/2107979660558766351), and spike 05:

- A string with `maxLength` fits a limited array of four bytes per code point
  (`u8[..480]` for 120), and the reader counts code points. With a `format` whose values
  are ASCII (`uuid`, `date`, `date-time`, `email`, and `ascii`) it fits `n` bytes. An
  unbounded one is a variable-size `u8[]` field, kept inline in the struct.
- A `u8[]` field can't grow or be assigned after construction, nor can a struct holding
  one (§4.4). A reader keeps each `json::read_string` slice as its key arrives, in any
  order, then builds the struct with one literal, in place, with no copy. Each slice
  starts as `r.text[..0]`, not `""`. A limited-array field that a repeated key appends
  to overruns its capacity and aborts (§3.3): clear it first, or use the same pattern.
- A nested object can't be read into a local and then put in the struct, for the same
  reason. The reader records where each nested object or array starts, skips it, and
  reads it inside the struct literal, so it too is built at its destination. A struct
  built into a local and then returned costs no copy: the compiler builds it at the
  caller's destination (2026-10-13).
- Keys dispatch on `match key.len`, then compare bytes. `key == "name"` already compares
  lengths first (§4.5), so the generator doesn't add `key.len == 4 &&`.
- Recursion can't keep growable data across a recursive call, so a recursive schema (a
  `$ref` cycle) needs a reader of another shape. Until one exists, the generator rejects
  it.
- A job sent to another thread and its reply are flat values, copied whole through a
  box as `to_bytes` images, with no JSON between threads.

### With a schema

The build runs `goose-rest gen api.json -o api_gen.goose`, after writing `api.json`
from `api.ts` where there is one. The generated file is `api_gen.goose`, not
`api.gen.goose`, because an import names a module by identifiers separated by dots
(2026-10-13).

Decided (2026-10-14): goose-rest commits its generated files, under `test/gen/`,
`examples/`, `docs/tutorial/`, and `bench/`, as golden files that `scripts/test.sh`
regenerates and compares byte for byte. An application chooses for itself. It can
commit its `api_gen.goose`, so that reviewers can see a diff of the code a schema change
generates and the build needs no generator, or generate it in its build.

## The API

Decided (2026-10-14): the context is `Cx<S, A, R>`, with the
request state, the worker state, and the router's type. `rest::routes` supplies
`http::Router`; outside its block, including a WAKE, the context has `rest::NoRouter`.
Calls that match a route or read its parameters therefore fail to compile without a
router. A generated-only server builds none. `routes` builds a local context because
its router cannot outlive its block (§9.2). A typed route helper names
`type Cx = rest::Cx<St, App, http::Router>;`.

Decided (2026-10-14): `rest::serve(cfg, app[, fresh])` puts the worker's
state by reference in `cx.app` and starts `cx.state` from `fresh`. This removes a
state argument from handlers, security checks, resume functions, and `dispatch`,
with no measured cost. With request state alone, the program passes a `rest::NoState`
placeholder by reference. `rest::serve_one(text[, app[, fresh]])` has the same state
forms, with an optional `http::Config` after `fresh`, and after `fresh` the replies of
a route that waits, `rest::Wake`s, which stand in for its lane (2026-10-15).

Decided (2026-10-14), replaced on 2026-10-21 (below): `rest::routes` does not open
`rest::route`. Opening a route for every request costs more to save one line. The
program opens one around the code that can fail; generated dispatch opens each of its
own routes.

Decided (2026-10-21), replacing the decision above: routes are short, and readability
wins over what that costs. A program's routes are statements in a row, as Actix's
`web::scope` and `web::get` read, rather than an if chain of `rest::on` and
`rest::route` that ends in `rest::otherwise`:

```goose
rest::routes(cx) { cx =>
    rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
    rest::scope(cx, "/v1") {
        rest::get(cx, "/projects/:id") { project(cx, rest::param_int(cx, "id")); };
    };
};
```

- `rest::routes` opens the request's one route around its block, and answers 404, 405
  with `Allow`, OPTIONS, and 501 itself when the block left the request unanswered and
  nothing waits: no reply, body, or room to send.
- `rest::get`, `post`, `put`, `patch`, and `delete` match, mark the request taken, run
  their block, and return as any block does. The routes and scopes after a taken
  request don't match: each checks the mark inline, so one costs a branch. Code after
  its block runs, a middleware's included.
- `rest::scope(cx, "/p") { ... };` is a block: it owns the paths under its prefix,
  gives `rest::routes`' answer when its block answered nothing, and takes the request.
  No scope leaves the path narrowed for the routes after it.
- `rest::scoped(cx) { ... };` is the building block for middleware that works after
  its block or adds fields to answers. Inside `rest::routes` it runs its block as a
  route of its own and gives the default answer there, so a failure, a 404, and a 405
  inside the middleware get its fields; outside, it only runs the block.
  `rest::cors`, `rest::timed`, `rest::security_headers`, and `rest::compressed` run
  their block in it, so each has one name and works on either side of `rest::routes`.
- Inside `routes`, `rest::route` joins the one route, so a stack that opens its route
  works either side of it. Guards stay `if` conditions, around the routes they guard.
- `rest::on` and `rest::otherwise` stay, as the lower-level pieces. `rest::otherwise`
  answers nothing after a route that took the request, so it can follow
  `rest::get`. Generated dispatch begins with `rest::untaken(cx)`, and answers
  nothing after a program's route that took the request.

The mark is goose-http's `Router.bad`, which marks a path the router refuses, and
which `http::on` checks first. goose-rest sets it when a route takes the request, and
tells the two apart by whether the path is routable. That depends on what `bad`
means in goose-http, which goose-http's task 027 could change; if it does, the mark
moves to a field of goose-rest's own.

The cost is the route every request opens, including `/health` and the 404s that the
if chain answered with none, and the mark's check after a match. On macOS, against
the if chain, it's −74 to +149 instructions per request at 60 routes and +107 to +135
at 1,111, under 1%, and +225 to +257 in a scope behind `rest::cors`, which opens a
route of its own there. Requests per second stay within 3.2% of the if chain's, above
and below, in single rounds
([spike 12](../spikes/12-compact-routes/README.md#skip-based-routing-2026-10-21)).

Rejected:

- Design A, adopted on 2026-10-20 and paused before it merged: `rest::get` left
  through `return from routes`. That skipped the work of every middleware between it
  and `rest::routes`, so `rest::timed` and `rest::compressed` inside `routes` broke,
  and it answered a failure inside a scope's middleware after the middleware had
  unwound, without its fields.
- Middleware that compiles only outside `rest::routes`, beside scoped versions such
  as `rest::scoped_cors` that catch the leave in an inner `routes`. Two names for each
  middleware, and a program's own untyped middleware still compiles in both places and
  misbehaves inside `routes` without a word.
- A field in goose-http's `Router` for the mark: goose-http would never read it.
- The `bool` `rest::scope` beside the block form. It left the path narrowed, so the
  routes after a scope that matched but answered nothing matched the rest of the path.
- A route for each `rest::get`, which costs nothing but needs the if chain in a scope
  behind middleware that fails, since that scope shares one route: two forms, and the
  wrong one there goes out of line without a word. And a route's block given a context
  of a marked router type, on which `rest::get` is overloaded. That costs about as
  much, and changes the signatures of every `rest::route` block, every stack, and
  every call that reads the router.

Decided (2026-10-14): `rest::empty(cx, status)` answers without a body.
It makes a 204 one call and preserves HTTP's framing: 204 and 304 have no
`Content-Length`, and other statuses have `Content-Length: 0`.

Decided (2026-10-14): `timed` reserves 12 bytes for the duration in
`Server-Timing: app;dur=` before its block, then fills them in place. Trailing spaces
are valid field whitespace, and no response bytes move. CORS checks for a preflight
only on OPTIONS and appends its common fields. `bearer_token` uses `http::bearer`,
which checks token68. These changes reduce the measured middleware cost without
changing how blocks compose. `bench/stack.sh` measures it.

Decided (2026-10-14): response fields use `http::NO_TYPE` and
`http::JSON`, and each job's reply size comes from `http::mail_slot_size`.
These replace copies of HTTP's constants and a slot size threaded through the
context. `rest::text` keeps its own fields, `text/plain; charset=utf-8`: `http::TEXT`
names no charset, and a client then guesses one for text past ASCII.
Reusing `http::gather` is deferred: it changes the path for a body larger
than the read buffer and needs the body tests and a tier D run on Linux. Replaced on
2026-10-22 (below) by goose-http's gather pool, whose parts goose-rest composes.

Decided (2026-10-22), replacing goose-rest's own spill and its `Budget`: every run
goose-rest keeps past a handler's call is an `http::Gather` of goose-http's gather pool,
under the budget `http::gather_budget` sets, which a program calls in `main` before
`http::run`, and goose-rest keeps no setting that mirrors it: `rest::Config`, left
empty, is gone, and `serve` takes no settings of goose-rest's own (2026-10-22)
([goose-http's decision](https://github.com/kaitk/goose-http/blob/main/docs/decisions.md#the-gather-budget-counts-bytes-promised-and-refuses-at-admission)).
The budget counts bytes promised, so each run is promised its most when it's admitted,
and what the budget can't hold gets 503 `unavailable` with `Retry-After: 1` there:

- A body that `rest::body` gathers: `http::gather_head` at the request, a
  `Content-Length`'s exact size or a chunked body's limit, with the head. A chunked
  body is then refused at its head, not once it grows past the budget, and is never
  refused later; past its limit it gets 413, as before.
- A reply `rest::ask` waits for: promised `most` bytes, a new parameter after `ms`,
  `rest::REPLY_LIMIT`, 64 KB, by default, before the job is sent, so a lane does no work
  for a reply the worker can't hold. A `rest::reply_value` past `most` gets 502
  `reply_too_large`, as a body past its limit gets 413. The promise holds for every
  ask, whether the lane replies in one message, in pieces collected, or relayed; it is a
  count, and allocates nothing until a value comes in pieces. The reply's `Gather` is in
  a table of the worker's, `replies`, which `Exchange.reply` indexes: in `Exchange` it
  would grow every connection's slot by 40 bytes for routes that never ask.
- What the middleware keeps for a later answer: promised its exact size at the request,
  about 100 bytes. A budget too full for it answers the request 503 with the fields, ends
  the route's wait, and gives a route reading its body `CLOSED`; before, these runs were
  placed without a check.

This lets go of the spill, `Budget`, `Run`, the mirror of the runs in use and the
prediction of where the spill places the next (`track`, `untrack`, `spill_end`,
`free_at`, `grown_end`, `grow_run`, `placed_end`, `fits`, `run_size`), goose-rest's own
`gather_head`, `gather_piece`, and `release`, the reply run's 16-byte header, and the
spill and budget parameters threaded through `serve`, `on_event`, `on_later`, and
`serve_one`: the package is about 180 lines shorter. `Exchange` holds its run as an `http::Gather`, 58 bytes
in all where it had 50, for the promise; a body received in pieces counts down from
its limit, since a route reading pieces can keep fields in the run. The pool's length can pass the budget by what
its free spans leave unused, which goose-http's decision accepts.

Rejected: keeping the spill beside goose-http's pool, two arenas in a worker that
gathers and later holds WebSocket runs; promising a reply at its first piece, which
refuses it after the lane has done the work; and a `Gather` for the reply in
`Exchange`, above.

Decided (2026-10-22): a request no route took gets goose-http's verdict,
`http::unrouted(r)`, which goose-rest writes in the program's error shape, rather than
goose-rest deciding among 501, 400, 204, 405, and 404 again in `rest::otherwise`,
`rest::no_route`, and `rest::not_found`. The generated router has no `http::Router`,
so `no_route` and `not_found` take the verdict from its parts,
`http::unrouted(method, path, routable, allow)`, rather than build a Router for it.

### Compression

Decided (2026-10-15): `rest::compressed` lives in `rest.compression`, a module `rest`
doesn't import, as goose-http keeps its compression in `http.compression`, so only a
program that imports it declares goose-compress or builds its code. Its block gets a
context whose `out` writes to a local buffer, and
`compressed` copies the answer from there to the response, compressed where goose-http
would compress it. Rewriting the answer in the response buffer would shrink that
buffer, which Goose refuses while the handler holds the request (§5.1), and rebinding
the caller's `cx.out.buf` to a local would let it outlive the local (§9.2). So the
block takes `cx =>`, as `rest::routes`'s does, and each answer inside is copied once.

Decided (2026-10-15): a response begun with `rest::begin` inside `compressed` is
compressed as it's sent, through four hooks the core declares beside `begin`, `send`,
and `end`: generic functions that leave the response as written. `rest.compression`
overloads each for an `Exchange`, and a concrete overload wins over a generic one
(§7.1), so a program that imports the module gets its versions and the core still
imports nothing of goose-compress. `compressed` marks the exchange with a `mode` bit
while its block runs, and `begin` takes an encoder only then. The encoder's slot in
goose-http's pool is kept in a per-worker table of the module, by the connection's fd,
not in the exchange: a field there would cost every connection slot of every program
(Goose packs structs), while the table costs only a response being compressed. A
per-request field in the program's state, with `begin_compressed`, `send_compressed`,
and `end_compressed` of goose-rest's own, was the alternative: a larger API, and one
more field for the program to keep and release at `CLOSED`.

### WebSocket and HTTPS

Decided (2026-10-22): a WebSocket is `rest::ws_upgrade` and `rest::ws_read` in
`rest.websocket`, a module `rest` doesn't import, as goose-http keeps its frames in
`http.websocket`, so only a program that imports it declares goose-hash. They compose
goose-http's parts rather than wrap its helpers: `http::ws_check` for the verdict,
`http::ws_admit` for the gather pool's promise, and `http::ws_switch` for the 101, so a
refusal is written in the program's error shape, with the fields `ws_check` gives a 426;
and `http::ws_take` at `BODY` and `http::ws_release` at `CLOSED`, since goose-rest's case
function gets `cx.kind` and `cx.body`, not an `http::Event`. The upgrade then marks the
exchange as `rest::upgrade` does, through the same function, and only once the stream
is open. The program keeps the `http::WebSocket` in its request state and sends with
`http::ws_send` and `http::ws_close`: the connection holds one WebSocket for its whole
life, as goose-http's own handler state does, so a table of the module's by fd, which
compression keeps for a response's encoder, would add a lookup and nothing else, and a
field in `Cx` or the exchange would cost every program. goose-rest adds no send or close
of its own, which would only rename goose-http's.

Decided (2026-10-22): HTTPS is `rest::serve` and `rest::serve_epoll` overloads that take
goose-http's `http::TlsServer`, in `rest.tls`, a module `rest` doesn't import, so only a
program that imports it declares goose-tls and builds with OpenSSL. Each repeats
`serve`'s block over goose-http's TLS loop, as `serve_epoll` repeats it over epoll. A
`TlsServer` field in `rest::Config` was the alternative: every program would then build
goose-tls.

### Inlining

Decided (2026-10-13), from `test/inline_route.goose`'s C. A handler behind
middleware compiles to one C function, the handler, with the middleware, the route,
and the code that fails inlined into it, and each early answer compiled as a jump. Three rules keep
it so:

- **One route per request.** A function that fails returns from the innermost
  `attempt`, so a route nested in a route keeps both out of line. Middleware opens no
  route of its own outside `rest::routes`. Inside, goose-rest's runs its block in
  `rest::scoped`'s route, which `test/inline_route.goose`'s C keeps inlined with the
  request's.
- **Functions that fail stay small.** A function that fails and stays a call needs its
  route's frame, which keeps the route, everything around it, and the handler out of
  line. The extractors fail in a few statements and do their work in leaves that
  return whether it succeeded (`int_of` and `decimal`).
- **Block-taking functions are `inline fn`.** Given a handler's routes as its block, a
  function such as `cors` passes the inliner's size limit at once, and stays a call
  although it's called once ([findings](goose-findings.md#a-function-called-once-isnt-inlined-past-a-size)).
  So `route`, `attempt`, `cors`, `bearer`, `timed`, and `json_body` are `inline fn`.

### Extractors

A program declares a type's reader as
`fn rest::from_request(cx, v: const app::ProjectCreate?) -> app::ProjectCreate` (spike
01), and its writer as a `fn format(out: u8[>..]&, p: const Project&)` in its own
namespace.

Decided (2026-10-13): `take<T>` returns the value, and `from_request` gets a
null `const T?` whose type picks the overload. A `from_request(cx, v: T&)` that fills
a default `T` can't build a `T` holding `u8[]` fields, which can't be assigned after
construction (spike 05). A returned `T` is built at the caller's destination. The block
form, `take<T>(cx) { v => ... }`, would hand the block a copy of a local (goose-http's
findings).

### A JSON writer from a struct's fields

Decided (2026-10-16, task 041): `rest::format_fields(out, v)` writes a struct's fields
as a JSON object, through Goose's `const for` over `fields<T>` (spec §6, Goose
`v2026.2`), and a program opts a type in from its own `format` overload. A writer that
follows the struct can't fall behind it, as a hand-written field list can. The writer
takes every field under its declared name, since `const for` v1 has no annotations;
renamed keys and left-out fields stay with hand-written writers and the generator's.

Each field's writer is an overload chosen by its type. An untyped catch-all, which
hands a struct or enum to the program's `format`, ties with `T[]` and with a slice
reached by coercion (§7.1 makes a tie an error, and a bounded or fixed array matches
no `T[]` exactly). So every writer takes a trailing `i32`, which the catch-all
declares `f64`: an integer converted to a float is resolution's last resort, so the
catch-all loses to every other writer. The integer types get one writer each, because
a widening is a coercion too. Rejected: a writer for `T?`, which any value reaches by
coercion, tying with the integer and slice writers; an optional goes through the
catch-all, so an optional string isn't quoted.

Rejected for now: a generic reader. Choosing how to read a field needs its type, which
`const for` v1 doesn't bind (its design's future work, `<N, A, U>`), and the expected
result type never selects an overload (§7.1). Readers stay hand-written or generated.

### Handlers

`rest::fail` leaves through `return ... from rest::route`, and `Failure`'s code is an
owned `u8[]` built with `str()`; a slice of the request can't travel with the return
([findings](goose-findings.md#a-long-distance-return-cant-carry-a-slice-a-caller-passed-in)).
Decided (2026-10-13): the first answer wins. A failure after the handler began
a response leaves that response, because `route` can't shrink the write buffer while a
slice of the request is live (spec §5.1). Decided (2026-10-15): a failure with a response
still open, begun in this call or an earlier one, leaves it unended and closes the
connection, so that the client sees it cut short rather than an error inside it.

## Waiting on another thread

Checked by spike 06; built in `waiting.goose`. Goose can't store a function to call
later, so the request state holds a fixed-mode enum of what each waiting route
needs, and the app writes a case function per variant. The compiler dispatches on the
tag and checks that every variant has its case (§8.2). The enum is fixed-mode because
each request overwrites the slot (§3.5).

The default is a lane: a thread that owns the connections and receives a job describing
the whole use case from the route. It runs the job from start to finish with blocking
calls, in one transaction (2026-10-14). The route waits once, with one time limit and
one place where a full box refuses work. Tests call the job as a plain function. A route
waits more than once only when it needs a second lane in turn. The tutorial builds
both, from [work that waits](tutorial/11-waiting.md) to
[limits](tutorial/13-limits.md).

Decided (2026-10-16), replacing the name "service" (2026-10-14): the thread a route
sends work to is a *lane*, and what it sends is a *job*. In Spring, Laravel, and ASP.NET a
service means the use-case code, called a job here, rather than a thread. Calling the
thread a "service" would mislead readers familiar with those frameworks. One lane can
run jobs from many domains, and a domain's jobs may run on several lanes, so the thread
and the code need distinct names. A lane is one thread, or several running the same
jobs, each with its own box. Rejected: *pool* and
*executor*, which suggest work spread freely rather than queued by kind; *actor*, which
suggests state per entity; *worker*, which names the HTTP threads already; and plain
*thread*, which covers neither a lane's several threads nor the box in front of them.
snowtime-native calls the same thing a lane. In an application
([Best practices](best-practices/lanes.md)), a domain's jobs are in its `routes.goose`,
after the route that asks for each job, in execution order. As a domain grows, it splits
by operation into `routes/`, rather than separating jobs into their own file. The files
share the domain's namespace, so moving a function between them requires no changes to
its callers.

Decided (2026-10-16): work of minutes that a route answers with `202 Accepted`, and that
the client then polls, is a *background task*, in goose-rest's docs and goose-http's.
"Job" had named both it and the use case a route sends a lane; a background task is
made of jobs, one that starts it and one for each poll, so the two need names of their
own.

Decided (2026-10-16): the five places data lives have one name each, in the docs and
the package's comments: a *constant* (a global with a literal value), the *store*
(goose-http's `http.store`), *lane data*, *worker state* (`App`, `cx.app`), and
*request state* (`St`, `cx.state`). A lane's queue is its *box* (`http::Box`), which a
job reaches *by mail*. They replace "per-worker state", "the worker's state",
"per-request state", "shared store", and "mailbox", which the docs used side by side,
so that one place had two or three names. `App` and `St` keep their names: the tutorial
uses them from page 8 on, and `App` matches Actix.

Decided (2026-10-15): every call after a request's first goes through the same case
functions, not only a reply. A route that reads its body in pieces (`rest::body_in_pieces`),
sends its response in pieces (`rest::begin`, `rest::file`), or takes an upgraded
connection (`rest::upgrade`) gives a `Waiting` variant, as `rest::ask` does, and
`rest::serve` calls the handler again for each event of the exchange, `rest::resumed`,
with `cx.kind` saying which: `BODY`, `END`, `MORE`, or `CLOSED`, which comes once to a
route that ended early, so that its case function releases what the state holds. Built
in `pieces.goose`; the [reference](reference.md#4-later-calls) has each call. One case
function per variant handles every kind, rather than a name per kind: §8.2 needs an
overload of each name for every variant, and a generic fallback beside them takes the
whole enum, so the call never dispatches (checked on `v2026.1`). Goose can't keep a
block to call at the next event (§7.6), so a block per call isn't possible either.

goose-rest's bookkeeping for a request, `Exchange` in the connection's slot, has a
`mode` with a bit for each of these, and the request path tests it once after the
handler. The later calls go through one function, `on_later`, whose loop calls the
handler at one place, since the program's handler is inlined at each call. Goose still
inlines `on_later` into each of goose-http's calls of `serve`'s block, the request
path's included, as it inlined the call for a gathered body before; no construct keeps
it out of line ([findings](goose-findings.md#a-function-called-once-cant-be-kept-out-of-line)).
The file being sent, an `http::FileBody`, is in the program's state with a `Waiting`
variant, not in goose-rest's slot, so that a program that serves no files keeps no
bytes for one. A failure with a response begun leaves it unended, and goose-http closes
the connection: its head has gone, so the first answer wins (["Handlers"](#handlers)).

Decided (2026-10-16): a route that began a response asks for a call at a time of its
own with `rest::pause(cx, ms)`, which calls goose-http's `http::later` on the open
response, and its case function gets `http::TIMEOUT` with the response still open.
goose-http already arms a timer on an open response and delivers `TIMEOUT`; goose-rest
had been taking that `TIMEOUT` for a 504 it couldn't write. Now a `TIMEOUT` on a
response begun with `rest::begin` goes to the route, whatever asked for it, since a
504 can't follow a head. The name says what the call does to the response, as
goose-http's docs do, and keeps it apart from `WAKE`, a reply's event. Three
questions, settled:

- Replaced on 2026-10-22 (below): the deadline lives in `Exchange`, as `due`: `pause` reads the clock once and stores
  the time halfway to `ms`, and a `TIMEOUT` reads it once more. goose-http gives
  `TIMEOUT` at once when it has no timer for the wait (`Config.max_waiting`), and the
  route can't tell that from its own except by the clock. Halfway, as goose-http's
  `examples/device/` checks, because goose-http's timer falls due by the loop's clock,
  read before the handler, so a real `TIMEOUT` can come a little before `ms`. Rejected:
  leaving the check to each route, which then repeats it or streams on with no timer;
  a mode bit for "paused", since a `TIMEOUT` on an open response needs the route
  whatever asked for it; and no clock read, since nothing goose-http hands the handler
  tells the two apart.
- An early `TIMEOUT` ends the response, cleanly for a chunked one, and the route then
  gets `CLOSED`, as for any response that ends other than by its `rest::end`. A
  Server-Sent Events client reconnects to a stream that ends. Rejected: passing it to
  the route with a flag, a second kind of `TIMEOUT` for every case function to handle;
  and leaving the stream open, which goose-http then calls with `MORE` or not at all.
- A route that doesn't pause again at `TIMEOUT` gets what goose-http gives an open
  response that doesn't wait: `MORE` once the client has taken what it sent, and a
  `MORE` that neither sends nor ends closes the connection. Rejected: ending the
  response for it, which would make `TIMEOUT` differ from `MORE` for the same omission.

A client that goes during a pause gets the route `CLOSED`, as goose-http cancels the
timer. `rest::serve_one` takes a `Wake { timeout: true }` as the pause's time come, and
`early: true` as goose-http's `TIMEOUT` at once; a pause with no wake left is a client
that goes.

Decided (2026-10-21), extending the 2026-10-16 entry above: `rest::pause(cx, ms, u)`
pauses a route before its response has begun, with `u` in `cx.state.use`, so a route can
wait on the worker's timer table and then answer a normal response, as HttpArena's
`GET /delay/{ms}` needs. `rest::pause(cx, ms)` stays for a response `rest::begin` began.
A new bit of `Exchange.mode`, `PAUSED`, marks the pre-response pause. `mode` widens from
`u8` to `u16`, and `pending` becomes its bit `PENDING` (gone on 2026-10-22, below), so `Exchange` keeps its 50 bytes:
Goose packs its structs, so a wider field has no padding to fill. `PAUSED` stays out of
`LATER`, and only `on_event`'s `http::TIMEOUT` branch checks it. When set, it clears the
bit and either answers 503 `unavailable` with `Retry-After` if `clock_ns() < x.due`
(goose-http's immediate `TIMEOUT` when no timer is free; replaced on 2026-10-22, below,
by the `TIMEOUT`'s tag), or passes the `TIMEOUT` to the
handler at the call `REQUEST` and `WAKE` use, with the fields the middleware kept. A
second call to the handler would inline it twice in every program that serves.
Clearing `PAUSED` leaves a later `rest::ask` in the same exchange to get 504 if its reply
times out. Rejected: checking `due > 0` without a mode bit, which collides with
`COLLECTING`'s use of `due` for a reply run's start and with `serve_one` setting
`due = 0` for a non-early timeout.

Decided (2026-10-22), replacing the 2026-10-16 entry's first point and the clock
comparison of the 2026-10-21 entry above: goose-rest tells goose-http's `TIMEOUT` at
once, for want of a timer (`Config.max_waiting`), by its tag, `http::NO_ROOM`, which
goose-http gives from v0.5.0, rather than by the clock. `rest::pause` reads no clock and
stores no deadline, and `on_event` and `arrived` test `ev.tag`. The clock could
misclassify: an immediate `TIMEOUT` that reached the handler after half a pause's time,
as when the loop is busy, passed for the pause's own. `Exchange.due` then held only a
collected reply's start, and is renamed `reply`; with no pause moving it, serve frees
the reply's run after the `resume` from that field, and no longer saves it first.

- `rest::ask` given `NO_ROOM` answers 503 `unavailable` with `Retry-After: 1`, as a
  pause before a response does, rather than 504 `timeout`: no room to wait is a refusal
  at admission, not a lane that was slow.
- On an upgraded connection, `NO_ROOM` stays a plain `TIMEOUT` for the route, as when
  the time has passed: the 101 has gone, and `Cx` carries no tag. It waits until a
  route needs to tell them apart.
- `rest::serve_one` gives a `Wake { early: true }` as a `TIMEOUT` tagged `NO_ROOM`.

Rejected: a mode bit or field that records the wait's purpose in `Exchange` for the
check, which the tag makes unneeded.

Decided (2026-10-22), replacing the `PENDING` bit of the 2026-10-21 entry above: whether
a request's body came whole is goose-http's `Event.whole`, given at each `REQUEST`, and
goose-rest reads it there rather than copy it into each connection's `Exchange.mode`.
`after`, which has the event, tests `ev.whole` and `ev.kind`. `rest::body`,
`rest::body_in_pieces`, and the middleware's `answers_later` see only the context, so
`on_event` gives it in `Cx.more`, which says "more follows" already: at a `WAKE`, more of
the reply; at the `REQUEST`, more of the body than came with the head. `on_event`
already stored `more` for every `Cx`, so the request path loses the bit's load, mask,
and store, and gains no field; a handler that doesn't read `more` leaves a dead store.

- `rest::body` and `rest::body_in_pieces` fail with 500 `body_too_late` at a later call
  than the request's. The bit had been cleared at a `WAKE`, so `rest::body` there
  returned an empty body for one still coming, and `rest::body_in_pieces` got an `END`
  made up after the body's first piece, which its route answered, and the rest was
  dropped. Gathering needs the request's head, which has gone by then, and a body read
  in pieces is the request's, so the route reads it before it waits.

Rejected: a new `Cx` field, `pending`, which costs a store for each `Cx` built, in
`on_event` and each copy routing makes, for what `more` already carries; keeping the
bit, which costs the slot's `mode` a load, a mask, and a store per request and leaves a
copy that can go stale, as at the `WAKE`; and a flag in goose-http's `Stream`, which
would mirror its own `Exchange.body` at every place that changes it to report a value
it already reports.

Decided (2026-10-16): an upgraded connection that waits on `rest::ask` keeps one
variant, the one in `cx.state.waiting`, for every later call. From goose-http v0.3.3 the
client's bytes keep coming as `BODY` while an upgraded exchange waits, so the case
function of the ask's variant gets them, then the `WAKE`, or the `TIMEOUT`, which can't
be a 504 after the 101 and so goes to the route. The route sets the upgrade's variant
back when it wants the bytes where they went before, or asks with the upgrade's variant
and tells the events apart by `cx.kind`. A `rest::ask` while the route waits already
fails with 500 `already_waiting`: goose-http's `later` at a `BODY` restarts the one wait
the exchange has, so a second job's reply would share it. This rejected:

- goose-rest keeping the upgrade's variant aside and handing the bytes to it during the
  wait. The variant's type is the program's, which `Slot<S>` can't name, and `on_later`
  can't swap `st.state.waiting` in and out: it is checked for every state type, and a
  program whose state has no `waiting` field would stop compiling. Keeping the
  variant's bytes in the spill would work around both, at the cost of a run per waiting
  connection and a copy at each event.
- A second state field for the ask's variant, beside `waiting`: a new name every
  program's state would carry, for one combination of calls.
- `rest::ask` at a `BODY` during a wait sending its job anyway, or only restarting the
  time limit: the first gets two replies for one exchange, the second drops the job.

Decided (2026-10-18; in goose-http since 2026-10-19): a lane of N threads has a box per
thread, and `rest::ask` to it sends each job to the least busy thread, the box with the
fewest jobs queued, and to the others in turn while each is full
([Architecture](architecture.md#waiting-on-a-lane)). A box per thread keeps each box
with one owner, as goose-http's boxes have, and a thread's jobs in the order they came.
This rejected:

- The first box with room, which queues jobs behind a busy thread while another is
  idle.
- Round-robin, which ignores how busy each thread is, so a slow job holds up every job
  dealt to its thread after it.

Decided (2026-10-18): opening a lane ends the program when a box fails to open, as a
configuration that can't start does, rather than return an error. Lanes open at the
start, before any request, and a lane with fewer threads than asked would run without
saying so. Rejected: returning an error, which adds a check to every `lane_open` for a
failure a program can't serve around.

Decided (2026-10-18): a lane stops by goose-http's `http::mail_stop`, a flag in its box,
not by a message. `http::lane_stop` sets it on each of a lane's boxes, and each thread's
`http::lane` loop returns once its box is stopped and empty, so the jobs queued before
the stop are still done. A full box can't refuse the flag, and the program's job tags
need none reserved. Rejected: a stop message with a tag of the program's, which a full
box refuses, and which each lane's loop had to handle with a flag of its own.

Decided (2026-10-18): opening a lane spawns its threads, each the program's `thread_fn`
with its box and one value of the program's where given, and stopping it waits for
them, whose ids the `Lane` keeps; `http::run` spawns the workers the same way. Goose
`fb5698125` lets a generic function spawn the `thread_fn` its caller binds; before it,
every program wrote a spawn loop per lane and waited for the ids it kept itself. The
thread that opened the lane stops it, once the workers have returned. The cost is that
every `App` copy holds the ids, 8 bytes a thread. Rejected: keeping the program's loops
beside `lane_open`, two ways to start a lane.

Decided (2026-10-19), after an independent review: lanes are goose-http's, and there
is one way to use them. Replaces the 2026-10-18 entries on a placement file that chose
each lane's count within the code's bounds, on `rest::ask_by`, and on
`rest::lane_open`. `http::Lane`, `http::lane_open`, `http::lane`,
`http::lane_stop`, and the least-busy send moved to goose-http, so a goose-http program
and a goose-rest one open, run, and stop a lane alike, and `lane.goose` went. Every
program opens each lane with `http::lane_open`, even of one thread, and a route asks
one only with `rest::ask(cx, lane, ...)`: the ask to an `http::MailAddress` and
`rest::ask_by` went, since no program needed them, and each was a second way to do the
same. `LaneConfig` keeps `threads`, `slots`, and `size`; placement, its `role` and
`max`, and the `http::Seat` a lane thread took are off `main` until bare-metal Linux
measures a gain
([goose-http's decision](https://github.com/kaitk/goose-http/blob/main/docs/decisions.md#placement-is-removed-until-it-is-measured-to-help)).
The measure is what someone porting from Hono, Elysia, or Axum must learn: workers that
never block, flat values between threads, a lane of N threads, `rest::ask` and its
`resume` with a time limit, 503 from a full box, and an abort that ends the process
under a service manager. A thread that does timed work of its own between jobs, as
the tutorial's reports thread does, writes the loop that `http::lane` is, rather than
`lane` taking a time limit and a second block for two programs. Tests that play a lane
use the same `mail_*` calls, taking jobs from the box of an `http::lane_of(box)`.

### One enum of jobs per lane

Decided (2026-10-19), from spikes [10](../spikes/10-use-cases/README.md) and
[11](../spikes/11-lane-enums/README.md): each lane takes a fixed-mode enum of its jobs, a
variant per use case, and a route that waits on it keeps only the lane's mark in the
request state. This replaces, from the entries above, the job as a struct sent with a
tag constant of the program's, `rest::ask(cx, lane, tag, job, w, ms)`, the lane's if
chain over tags with `rest::asked<J>`, `rest::read_reply<T>` and the
`guard ok else { rest::fail(cx, 502, "bad_reply"); }` in every `resume`, the `Waiting`
enum in `cx.state.waiting`, and the sender's tag in a reply (`REPLY_TAG`, `cx.tag`). A
route that waits costs four pieces in two files, where it cost nine in four: a variant
of its lane's enum in `app.goose`, and the route, its `run`, and its `resume` in its
domain's file. Built in `waiting.goose`; the [reference](reference.md#41-lanes) has each
call.

- `rest::Lane<U, M>` is an `http::Lane` and the lane's mark, a variant of the program's
  `Use`. `rest::lane_open<U>(cfg, mark, W)` opens it, and `rest::ask(cx, lane, job, ms)`
  takes only a variant of `U`, so a job sent to another lane doesn't compile. `ask`
  stores the mark in `cx.state.use` once the job is sent.
- `rest::lane(box, jobs) { u, a => run(u, state, a); }` is a lane thread's loop, and
  dispatches each job to the program's `run` case functions (§8.2), each lane with a
  state type of its own. `rest::lane_job(jobs, bytes)` is one job of it, for a thread
  that writes its own loop. Amended (2026-10-19): this replaces `rest::lane<U>(box)`
  and `rest::lane_job<U>(bytes)`, whose `U` nothing tied to the lane: a thread
  running `lane<Reports>` opened as `lane_open<Writes>` compiled, and with variants
  of the same shape ran the wrong job. `rest::lane_open<U>` now passes each thread a
  `rest::Jobs<U>`, a struct with `U` only as a type parameter, as `Lane<U, M>` is; the
  thread declares `jobs: rest::Jobs<Writes>`, `thread_spawn` checks it against the
  lane's `U`, and `rest::lane` takes `U` from it. A value the program passes stays a
  parameter of its own after `jobs`, spawned through `http::lane_spawn`: Goose has no
  second struct of one name with another type parameter, and a `Jobs<U, A>` holding it
  would give the lanes without a value a second way to write the parameter.
- A reply carries its job back in front of the answer: four bytes of length, least
  significant first, the job's image, then the answer's. The mark's `resume` calls
  `resume(rest::job<Writes>(cx), cx)`, which dispatches to the domain's `resume` for
  that job, with the job's fields, and that reads `rest::answer<T>(cx)`, which fails
  the route with 502 `bad_reply` itself. `rest::relay` skips the job at a reply's
  first piece. Amended (2026-10-19): the length took two bytes, which a job image over
  65,535 bytes overflowed, and whose high byte's `as u8` aborted a debug build.
- The job and its length must fit the reply's first message, which `relay` and the
  `resume` read it from. Decided (2026-10-19): `rest::ask` checks this before it sends
  the job, against `http::mail_slot_size` of the wait, and fails the route with 500
  `job_too_large` otherwise, rather than let `rest::reply` split the job after the
  lane has done its work. The check measures the job with `bytes_of`, a view of a
  one-element array, with no second image written. A lane's enum is fixed-mode, so
  every job of the lane takes its largest variant's size: a larger variant enlarges
  every job image of the lane. `rest::reply` sends the job's head and the answer as
  two slices; only the message that holds the end of one and the start of the other
  is copied together.
- The lane side replies with `rest::reply_value(a, v)`, or `rest::reply(a, data)` in
  pieces. Spike 11 named it `done` because the old `reply_value(a, v, tag)` took any
  `a`; with `asked<J>` gone, `reply_value` takes only a lane's `rest::Asked<U>`, and
  there is no overload left to tie with.
- A `rest::fail` on the lane refuses the job: the lane replies with its own tag bit,
  `REPLY_REFUSED`, beside `REPLY_MORE` and `REPLY_CONT`, and `rest::on_reply` fails the
  route with the same status and code before the `resume` runs. So a domain's
  `check(e, x)` serves a route and a lane alike. A `run` that neither replies nor fails
  gets the route 500 `no_reply` at once, rather than a 504 when its time runs out. The
  refusal is its status's four bytes and then its code, cut to fit one message, not a
  struct: a fixed `u8[..64]` code takes its whole capacity, which a 64-byte message, as
  tutorial page 12's, can't hold. Amended (2026-10-19): `rest::play` keeps the whole
  code, and `rest::serve_one` cuts a played refusal to its own message size, so a
  test gets the status and the cut code that the real path gives, not 502
  `bad_reply` for a refusal in pieces.
- `rest::on_reply(cx) { resume(cx.state.use, cx); }` replaces `rest::route` at every
  later call, and leaves `cx.state.use` as the route set it. Amended (2026-10-19): it
  no longer sets `cx.state.use` back to its type's first variant once the route gets
  no more calls. on_reply wraps every later call, so that reset cleared an upload's
  variant after a `BODY` that failed or answered early, and the `CLOSED` that followed
  went to `Use.None`, skipping the variant's cleanup. The reset existed only so that a
  job's inputs wouldn't linger in the request state; with marks, the state never holds
  a job, and goose-http starts the state afresh for every request. `Use` no longer has
  to list `None` first.
- Tests play a lane with `rest::play(lane, job) { u, a => run(u, state, a); }`, which
  runs a job as the lane does, with no thread, and returns its reply, which
  `rest::wake` gives `rest::serve_one`. It replaces building a reply's bytes with
  `rest::value_bytes`.

A route that reads its body in pieces, sends its response in pieces, or upgrades keeps
its wait in the same field: `body_in_pieces`, `begin`, `file`, and `upgrade` take a
variant of the program's `Use`, with what the route needs at each call, as they took a
`Waiting` variant, so `Use` lists a mark for each lane beside a variant for each such
route. An exchange has one stream of later calls, so one field holds what it waits on.
On an upgraded connection that asks a lane, the 2026-10-16 entry holds with the mark in
place of the ask's variant: the mark's `resume` gets the client's bytes and the
`TIMEOUT` during the wait, and tells them from the `WAKE` by `cx.kind`, since only a
reply carries a job; `rest::job` at another event fails with 500 `not_a_reply`.
Rejected: a second field for these waits beside the mark, which every program's state
would carry for routes that wait on no lane.

The mark costs a connection's state one byte, as tier M's `rest::NoState` does (spike
11). The bytes move to the mail: each reply carries its job again, so more replies
come in pieces, which the worker collects for `answer`
([Value replies in pieces](#value-replies-in-pieces)). A `run` or `resume`
overload that takes the whole enum is an exact match and wins every call without a
word ([findings](goose-findings.md#an-overload-that-takes-the-whole-enum-hides-its-case-functions-without-a-word));
`no_reply` catches a catch-all `run` that doesn't reply, at run time only. This
rejected:

- Spike 10's one `Use` for the program, whose variant is both the job and the wait:
  every lane took one state type, nothing checked which lane a job went to, and the
  request state grew to the largest job, 131 bytes for the lanes program.
- An outer enum whose variant holds a lane's job: the package needs a hook of the
  program's to wrap each lane's job in its variant, and the state grows to the largest
  job, 132 bytes.
- A field per lane: a `None` in each lane's enum, the same hook, and a state of every
  lane's largest job together, 165 bytes.
- Keeping the tagged `ask` and `read_reply` beside the new calls: two ways to do one
  thing, which the 2026-10-19 entry above rules out.

### Value replies in pieces

Decided (2026-10-19): the lane decides whether a reply's pieces are collected. This
replaces the rule above that a job and its answer fit one reply message for
`rest::answer` to read them. `rest::reply_value` marks each of its pieces with a tag
bit, `REPLY_VALUE`, beside `REPLY_REFUSED`, `REPLY_MORE`, and `REPLY_CONT`, and the
worker appends each marked piece to a run of its spill, as it gathers a body for
`rest::body`, counted against the same `gather_budget` (since 2026-10-22, within the
`most` that `rest::ask` promises it, [above](#the-api)). It calls the handler once, at
the last piece, with the whole reply in `cx.reply`, so `rest::job` and `rest::answer`
are unchanged. `rest::reply`'s pieces stay unmarked, and the handler gets each, which
`rest::relay` sends on as a chunk.

- A reply past the budget fails the route with 502 `reply_too_large`, a code of its
  own, since `bad_reply` says the lane's bytes were wrong and these weren't. The mark
  stays in `cx.state.use`, as after a timeout.
- The run is freed after the `resume`, which may wait again, at `CLOSED`, including
  the one a route gets when it fails at an upgraded connection's bytes, at `TIMEOUT`,
  and at a later call that ends the route or leaves it not waiting, such as
  `rest::end` on an upgraded connection. A reply past the budget frees it too, and
  cuts a response begun, whose route then gets `CLOSED`.
- The exchange keeps the run's start in `due`, a pause's deadline, and the run starts
  with its length and capacity. An exchange waits on a pause or a reply, never both,
  and a pause sets `due` afresh, so the slot goose-http copies for each request keeps
  its size; three fields of their own would add 24 bytes to it for routes that never
  wait. Amended (2026-10-19): the two meet at one call, the `resume` of a collected
  reply, which can pause the response it began before the run is freed. serve reads
  the run's start before that call and frees the run from it, leaving a deadline the
  `resume` set in `due`. Amended (2026-10-22): a pause keeps no deadline, so the field
  is the run's alone, named `reply`, and serve frees the run from it after the call.

This rejected:

- The handler opting in at the first piece, as with a call in the `resume`: the first
  piece is too late to know, since the `resume` runs at it, and `job` and `answer`
  would need a second path for a reply that isn't whole yet.
- Only raising `Config.mail_size`, which stays the way to avoid pieces altogether: it
  grows every slot of every worker's box for the largest reply, where the spill holds
  a long reply only while it's collected.

## Tests

Decided (2026-10-15), for goose-rest, goose-http, and goose-compress alike: tests
follow Goose's own convention, as the Goose repository's `test/` and `docs/testing.md`
lay it out.

- A top-level `test/` holds the tests, in a folder per area.
- Each test is a small program: a `main` with `assert`s, which prints what it checks.
  Its expected output is a golden file, `test/expected/<name>.out`, with
  `<name>.stderr` for lines its standard error must hold, and `<name>.aborts` for a
  test that must abort.
- A test that must not compile carries `// error: <substring>` comments.
- The repository's own runner, `test/run_tests.py` in Python as Goose's is, finds the
  tests, compiles them in batches with `goose --multi-test`, runs each as a process of
  its own and in parallel, and reports every failure without stopping at the first.
  No runner is shared between repositories, as none is with Goose's. Here the
  batches typecheck, and each test is built with `goose build`, since its program links
  goose-http's C, which `goose build` compiles from goose-http's `http.build`
  (2026-10-15).
- Helpers the tests share are one imported module, `test/expect.goose`, not a copy in
  each test; an area's own fixtures, such as its state types, go in that area's
  `common.goose`.
- An application laid out by domain keeps the same shape: `test/<domain>/` for each
  domain's tests, and a folder per scenario for its tests over HTTP.

This replaces test programs that `scripts/test.sh` lists by hand, each with its own
helpers, where the first failed `assert` ends the program and hides the rest.

Rejected: a test framework inside Goose, as Goose has no reflection to find tests, and
checking by printing against a golden file needs none; and tests beside the code, as
Goose's compiler already leaves out of a release what its root doesn't import, so a
separate `test/` costs nothing and matches the convention any reader of Goose's own
repository knows.

Decided (2026-10-16), replacing Best practices' rule that the program's types are in
`main.goose`: an application declares `App`, `St`, `Waiting`, and its job tags in
`app.goose`, its entry, which imports the routes; `main.goose` keeps the lanes'
threads, the workers, and `main`. A test under `test/<domain>/` has a `main` of its
own, so it can't import `main.goose`, and Goose reaches a parent folder only as a
package: `import app from "../../";` loads `app.goose` and what it imports. The
application keeps its own `test/run_tests.py`, as Goose and goose-rest each do, and
the example in `docs/best-practices/testing/` has one that `scripts/test.sh` runs.
Rejected: each test declaring its own copy of the program's types, which drift from
the real ones, so a test would pass against types the program doesn't have; and an
application running its tests with goose-rest's runner, which finds only goose-rest's
own tests and would make every application depend on this repository's layout.

## Numbered sections

Decided (2026-10-16): the Best practices pages and `reference.md` number their
sections as Goose's `goose_spec.md` does, so a review can cite one in a few
characters, as "Layout §2.3" or "Reference §2.1", the way these docs cite "goose_spec
§11.1". A Best practices page takes its place in the section's index as its number,
`# 2. Layout by domain`, and its sections `## 2.1`, `### 2.1.1`; the reference numbers
its own, `## 1.`, `### 1.1`. The number is part of the heading, so it's part of the
GitHub anchor (`layout.md#23-when-a-domain-grows`): renumbering a heading changes its
anchor, and the same change fixes every link to it, in goose-rest and goose-http. A new
section goes at the end of its page where it can, so the numbers already cited keep
naming the same rule. The tutorial, `architecture.md`, `decisions.md`, and
`development.md` stay unnumbered: they're read in order or searched, not cited by
rule. Rejected: a number outside the heading, such as an HTML anchor of its own, which
keeps old links working but lets the number and the heading disagree; and numbering
every page, which gives citations no one makes.

Decided (2026-10-16): `generator.md` is numbered too, and each of the generator's
errors ends with the section that covers what it refuses, as
`#/paths/x: a path must start with '/' (generator.md §7.2)`, so a reader goes from the
error to the rule in one step. The section comes from the error's JSON pointer, §7.2
under `#/paths` or `#/security` and §4 elsewhere, and from the call site for a schema's
names, §5. The tests of each message compare it without the section, and
`test/generator/sections.goose` checks the sections themselves. A section inserted
before those in `generator.md` changes the generator's output, so it goes at the end.
Rejected: a section named at each of the generator's hundred or so call sites, which
says the same as the pointer in nearly every case.

## Spike results (2026-10-13)

On Goose `a6249a4`, and again on `46356c2` with the same results except for spike 04, whose
by-name form now inlines too, in `spikes/` (each spike's README has its command and evidence).
Nothing blocks the design; three checks need a workaround, which the design takes:

| Check | Verdict | What the design does |
|---|---|---|
| Overload chosen by type parameter (01) | Works in one namespace. Across namespaces `from_request` isn't found: a generic body looks names up where it's defined (§11.1), and Goose has no argument-dependent lookup. | The app declares `fn rest::from_request(cx, v: const app::Session?) -> app::Session`, and the generator writes the same form. `T` is given explicitly. |
| Early exit from middleware blocks (02) | Works. A 401 skips the inner blocks and the handler, and a `return` in a block returns from the handler. A middleware's own `return` leaves only the middleware, so code after the middleware call still runs. | A middleware rejects with `rest::fail`, not `return`, so the whole route unwinds. |
| `return ... from rest::route` (03) | Works across namespaces, and calling `fail` outside `route` is a compile error. The returned value can't hold a slice from the request ([findings](goose-findings.md#a-long-distance-return-cant-carry-a-slice-a-caller-passed-in)). | `route` and `fail` follow the stdlib's `exception` module: `route`'s inner handler returns `Failure[]`, empty or one element, and `Failure`'s code is an owned `u8[]` built with `str()`. Built so in `runtime.goose`. |
| Inlining to straight-line C (04) | Works. Nested middleware and `route` collapse into one C function, each early answer a `goto`, also when a block is passed on by name, `run(F)`. | `rest::route` passes `F` on by name. `route` is goose-rest's own, not `exception::try`: it answers the failure, and it's `inline fn` ([findings](goose-findings.md#a-function-called-once-isnt-inlined-past-a-size)). |
| Filling `u8[]` fields from JSON (05) | Can't fill them key by key; collecting slices, then building once, costs no copy. | Readers collect, then build once ([above](#gooses-data-model-in-generated-code)). |
| Resuming a waiting route (06) | Works, under `http::serve` too. The job crosses as a `to_bytes` image, `Waiting` lives in the request state, and a `WAKE` event dispatches to one case function per variant. A missing case fails to compile, with an error that doesn't name it ([findings](goose-findings.md#a-case-function-call-missing-a-variant-doesnt-name-it)). | Replies larger than a slot come in pieces ([Architecture](architecture.md#waiting-on-a-lane)). |
| The `format` hook from `rest::json` (07) | Works with no workaround, for nested types and types in a third namespace, beside `rest`'s own `format`. A type with no overload renders as `app::Session { 1, 2 }`, not JSON, and compiles. | `rest::json` calls `format`. The generator writes an overload per schema type, strings through `http::json_string`. |

## Later uses

Neither is part of the framework; each tells it what a real application needs.

**Snowtime native.** Taken from snowtime-native's `Cargo.toml` and `crates/` on
2026-10-13. The HTTP side (routes, extractors, middleware, JSON) is what goose-rest
builds. Most of the work of a Goose Snowtime is in the table:

| Need | In Snowtime native | In Goose |
|---|---|---|
| SQLite, WAL, one writer and readers on threads | rusqlite, lanes | A C binding package; the shim rule doesn't cover it |
| Password hashes | scrypt | Pure Goose, or a C library |
| Signed cookies, API keys | HMAC-SHA-256, SHA-256 | Pure Goose |
| Ids | UUIDv7 | Pure Goose, needs a random source |
| Time zones, holidays | jiff with the bundled tzdb | A tzdb reader, the largest pure-Goose piece |
| Sorting by name | ICU collator | No equivalent; a simplified collation would differ from TypeScript |
| Unicode normalization | unicode-normalization | Tables and code, pure Goose |
| OAuth sign-in | Outbound HTTPS | An HTTP client and TLS, neither of which exists |
| Passkeys | WebAuthn, COSE, ECDSA P-256 | Crypto, pure Goose or C |
| TLS and ACME | rustls | goose-http's planned TLS |
| Pages | The app's server bundle in V8 | Stays outside Goose: a proxy to the existing renderer |
| Auth library | better-auth-rs | Ported by hand, against the conformance tests |

**A porting kit for Goose.** Snowtime's porting kit ports a TypeScript cloud app to one
Rust server, with crates for its request extractors, error body, and validation
messages, and codemods from valibot schemas and Hono routes (2026-10-09). A Goose
version is far off (2026-10-13). It would lean on two things goose-rest has: an
OpenAPI contract exported from the app's schemas, and a generator that turns it into
types, readers, and a router.
