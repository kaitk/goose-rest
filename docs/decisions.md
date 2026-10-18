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
again from its start (`bench/routes.sh`). The if chain stays the API without a schema.

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

Decided (2026-10-14): `rest::routes` does not open `rest::route`. Opening a
route for every request costs more to save one line. The program opens one around
the code that can fail; generated dispatch opens each of its own routes.

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
than the read buffer and needs the body tests and a tier D run on Linux.

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

### Inlining

Decided (2026-10-13), from `test/inline_route.goose`'s C. A handler behind
middleware compiles to one C function, the handler, with the middleware, the route,
and the code that fails inlined into it, and each early answer compiled as a jump. Three rules keep
it so:

- **One route per request.** A function that fails returns from the innermost
  `attempt`, so a route nested in a route keeps both out of line. Middleware doesn't
  open routes of its own.
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

- The deadline lives in `Exchange`, as `due`: `pause` reads the clock once and stores
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

Decided (2026-10-18): a lane of N threads has a box per thread, and `rest::ask` to it
sends each job to the least busy thread, the box with the fewest jobs queued by
`http::mail_queued`, and to the others in turn while each is full. Built in
`lane.goose`; [Architecture](architecture.md#waiting-on-a-lane) has how the pick works. A
box per thread keeps each box with one owner, as goose-http's boxes have, and a
thread's jobs in the order they came. `rest::ask_by` sends one key's jobs to one thread,
the key modulo N, for jobs that must not overtake each other within a run. This
rejected:

- The first box with room, which queues jobs behind a busy thread while another is
  idle.
- Round-robin, which ignores how busy each thread is, so a slow job holds up every job
  dealt to its thread after it.

Decided (2026-10-18): the code bounds a lane, and a placement file chooses within the
bounds. A lane opens from a `rest::LaneConfig` literal, as `http::Config` does, with
`threads` (1) where the file gives no count, and `max`, which is `threads` unless
written. A file may give any count up to `max`, and a count above it is cut, with a
warning. The code knows which lanes can grow at all: a writer that owns its data, or
SQLite's one writer, can't, and needs nothing written. The file knows the machine: how
many cores it has and which a lane should take
([best practices](best-practices/lanes.md#67-placing-lanes-per-machine)). Rejected: the
count in code alone, which a new kind of machine changes by a build; and the count in
the file alone, unbounded, which could give a writer a second thread.

Decided (2026-10-18): `rest::lane_open` ends the program when a box fails to open, as
a configuration that can't start does, rather than return an error. Lanes open at the
start, before any request, and a lane with fewer threads than its bounds and placement
gave would run without saying so. Rejected: returning an error, which adds a check to
every `lane_open` for a failure a program can't serve around.

Decided (2026-10-18): a lane stops by goose-http's `http::mail_stop`, a flag in its box,
not by a message. `rest::lane_stop` sets it on each of a lane's boxes, and
`rest::lane`, the thread's loop, returns once its box is stopped and empty, so the jobs
queued before the stop are still done. A full box can't refuse the flag, and the
program's job tags need none reserved. Rejected: a stop message with a tag of the
program's, which a full box refuses, and which each lane's loop had to handle with a
flag of its own.

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
