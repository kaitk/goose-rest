# Plan: a minimal framework on goose-http

Status: todo (asked for 2026-10-13; not started). A proof of concept for later, not a
priority. It builds on the API goose-http's task 027 leaves; this plan was goose-http's
task 023 until it moved here (2026-10-13).

An Axum- or Actix-like framework in Goose, on `goose-http`, whose routing and request
handling cost no more than the hand-written `http::router` if chain. goose-http's task
021 already leaves frameworks to it. Snowtime native is the first real application in
view, but a later one: this plan lists what Snowtime needs, and builds only the general
part.

## How Goose shapes it

Notes from the spec (the Goose checkout at `a6249a4`, 2026-10-12). Each is to be
confirmed by a spike before the design relies on it.

- **No handler table.** Function values are compile-time generic parameters. They
  can't be stored, returned, or put in data, and there are no runtime function
  pointers (spec §7.6). Axum's `Router::new().route("/x", get(h))` is a data structure
  of boxed handlers and can't exist. The application is code: routes stay an if chain
  or a `match`, as `http::router` is now.
- **Middleware is a block.** A trailing block is inlined, and a `return` in it returns
  from the enclosing handler (§7.6, §7.9). `rest::with_session(cx) { s => ... }` can
  answer 401 and not run the block, with no boxing, no dynamic dispatch, and no layer
  stack. This is cheaper than Tower, and is the framework's main idea.
- **Extractors by overload.** Generics are monomorphized and re-checked per
  instantiation (§7.7), so `rest::take<T>(cx) { v => ... }` can call
  `from_request(cx, v: T&)` and let overloading choose by `T`, as Axum's `FromRequest`
  trait does. Whether a generic body resolves an overload by its type parameter this
  way is the first thing the spike checks.
- **No derive.** Goose has no macros, reflection, or compile-time evaluation. What
  Rust gets from derive and Elysia from its compiler, goose-rest gets from a generator
  ([below](#a-generator-in-elysias-spirit)).
- **No shared memory.** Workers share nothing but `const` data and messages (§11.2). A
  cache, a rate limiter, or a session store is per worker, or lives on a thread of its
  own that workers mail. Mailboxes and answers that wait (`mail.goose`, `http::later`)
  already carry that.
- **No async.** A handler that waits on another thread splits in two around the reply,
  with its state in the connection (`http::serve` with state). The framework should
  make that split readable, since every database call that leaves the worker needs it.

## A generator in Elysia's spirit

Proposed (2026-10-13). Elysia 2 is the `kiana` branch of `elysiajs/elysia`, read at
`c91f61f` (2026-10-11). Its design, from `src/`:

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
| A composed handler per route, with only its hooks | The compiler does it. Middleware wraps a group of routes by nesting, as Elysia's `guard` and scoped plugins do, and inlines into each. The spike checks the generated C. |
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
numbers with handlers. Handlers keep the shape of
[How Goose shapes it](#how-goose-shapes-it): middleware and extractors stay blocks in
the handler.

Whether this is worth it is measured, not assumed. The serialize and template modes of
goose-http's task 021 split the JSON writer's cost from the HTTP layer's, which bounds
what generated writers can save. A hand-written if chain at Snowtime's 60 routes bounds what a
generated router can save. If the if chain costs little next to the rest of a request,
the generator writes the types and their readers and writers, and the routes stay a
chain with prefix scopes.

The generator's input should be a subset of OpenAPI 3.1, whose types are JSON Schema:

- Paths and methods map to routes, `operationId` to the handler's name, and path and
  query parameters to typed extractors.
- Clients and documentation read it as it is.

The subset grows with use. It starts with objects, arrays, strings with length and
format, integers and numbers with bounds, enums, nullable fields, and `$ref`. A
construct outside the subset is a generator error, not silently dropped.

The OpenAPI JSON is the contract: the Goose generator reads it and needs nothing else,
so goose-rest itself needs no JavaScript toolchain. A schema format of goose-rest's
own (TypeSpec, or Goose struct declarations with annotations) was set aside: each
would be another language beside OpenAPI.

Open (2026-10-13): an optional TypeScript helper for writing that JSON. JSON is
JavaScript notation, so a `.ts` file exporting the document as an object literal
reads almost as the JSON does, and adds what JSON lacks: comments, shared fragments as
constants, and functions for repeated shapes. Its main value is TypeScript types that
describe only the subset goose-rest supports. With `satisfies Api`, `tsc` rejects a
keyword, a format, or a parameter location the generator can't handle while the
schema is being written, instead of when the generator runs. Running the file writes
`api.json`. Two steps, TypeScript to OpenAPI to Goose, keep each tool small and leave
the JSON as an inspectable file between them. A proof of concept that writes Goose
straight from TypeScript can come later, if ever. Still to settle:

- Whether the helper lives in goose-rest's repository or in one of its own.
- Whether it also exports from a schema library, as Snowtime would want for its
  valibot schemas. That export is lossy: transforms and custom checks have no JSON
  Schema form, and valibot's `maxLength` counts UTF-16 units where JSON Schema counts
  code points. Snowtime's conformance tests would be the check that both backends
  validate alike.

Goose's data model shapes the generated code (spec §3, §4.3, §7.8, §11.2; condensed in
the language author's thread of 2026-10-07, https://x.com/wvo/status/2107979660558766351):

- A string with `maxLength` fits a limited array (`u8[..120]`); an unbounded one is a
  variable-size `u8[]` field, kept inline in the struct. A value is built in place at
  its destination, so a reader can't fill variable-size fields one key at a time; it
  collects them, then builds the struct once ([Review results](#review-results-2026-10-13)).
- Recursion can't keep growable data across a recursive call, so a recursive schema (a
  `$ref` cycle) needs a reader of another shape. Until one exists, the generator
  rejects it.
- A job sent to another thread and its reply are flat values, copied whole through a
  mailbox, with no JSON between threads.

## Usage

Proposed (2026-10-13). The [Review results](#review-results-2026-10-13) correct
several of these snippets, and take precedence. How a program would use goose-rest, as
designed above. Every
name here is provisional, and the snippets are sketches. Three things in them are
unverified and are the spike's first checks: `rest::fail` leaving through `return ...
from rest::route`, nested middleware blocks inlining to straight-line C, and resuming
a waiting route through a generated `match`.

### Files

```text
api.ts              the document, typed to the subset (optional)    (written)
api.json            the OpenAPI subset                              (written, or from api.ts)
api.gen.goose       types, readers, writers, router                 (generated)
app.goose           handlers, security checks, application state    (written)
main.goose          workers and middleware                          (written)
```

The build runs `goose-rest gen api.json -o api.gen.goose`, after writing `api.json`
from `api.ts` where there is one. Whether the generated files are committed is open.
Committing them shows each schema change as a diff in review.

### The OpenAPI subset

Abridged:

```json
"paths": {
  "/projects": {
    "get":  { "operationId": "list_projects", "security": [{"session": []}],
              "parameters": [{"name": "archived", "in": "query", "schema": {"type": "boolean"}}] },
    "post": { "operationId": "create_project", "security": [{"session": []}],
              "requestBody": {"$ref": "#/components/schemas/ProjectCreate"} }
  },
  "/projects/{id}": {
    "get":  { "operationId": "get_project", "security": [{"session": []}],
              "parameters": [{"name": "id", "in": "path", "schema": {"type": "integer"}}] }
  },
  "/health": { "get": { "operationId": "health" } }
},
"components": { "schemas": {
  "ProjectCreate": { "type": "object", "required": ["name"], "additionalProperties": false,
    "properties": { "name":  {"type": "string", "minLength": 1, "maxLength": 120},
                    "color": {"type": "string", "pattern": "^#[0-9a-f]{6}$"} } }
}}
```

### What the generator writes

Plain Goose, read and debugged like any other file, never edited.

```goose
namespace api;

struct ProjectCreate { name: u8[..120], color: u8[..7], has_color: bool }

// Reads and validates in one pass: keys by length, then bytes. Errors are
// sticky, as json::Reader's are.
fn read(r: json::Reader&, v: ProjectCreate&) {
    var seen_name = false;
    json::each_member(r) { key =>
        if key.len == 4 && key == "name" {
            let s = json::read_string(r, scratch);
            guard s.len >= 1 && s.len <= 120 else { rest::invalid(r, "name", "length"); }
            v.name.append(s);
            seen_name = true;
        } else if key.len == 5 && key == "color" { ... }
        else { rest::invalid(r, key, "unknown"); }      // additionalProperties: false
    };
    if !seen_name { rest::invalid(r, "name", "required"); }
}

// Writes only declared fields, each key's bytes a constant.
fn write(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");   json::format_int(out, p.id);
    out.append(",\"name\":"); json::format_string(out, p.name);
    out.push('}');
}

fn dispatch(cx: rest::Cx&, app) {
    let path = cx.path;
    match path.len {                          // static paths: length, then bytes
        7 => if path == "/health" {
            if cx.is("GET") { return rest::route(cx) { app::health(cx, app) }; }
            return rest::not_allowed(cx, "GET, HEAD");   // Allow is a constant
        },
        9 => if path == "/projects" { ... },
        _ => {},
    }
    if rest::under(path, "/projects/") {      // paths with parameters: by segment
        let id = rest::segment_int(cx, 10);   // 400 unless an integer
        return rest::route(cx) {
            let s = app::security_session(cx, app);   // only where the operation names it
            app::get_project(cx, app, s, id)
        };
    }
    rest::not_found(cx);
}
```

Each handler call is typed from its operation. A missing `app::get_project`, or one
whose `id` isn't an `i64`, fails to compile, which keeps schema and code in step
without Elysia's dry run and fingerprint. `/health` names no `security`, so no session
code is generated for it.

### Handlers

```goose
namespace app;

fn get_project(cx: rest::Cx&, app: App&, s: Session, id: i64) {
    let p = find_project(app, s.org, id);
    guard p.id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::json(cx, 200, p);                   // api::write, chosen by p's type
}

fn create_project(cx: rest::Cx&, app: App&, s: Session, body: const api::ProjectCreate&) {
    rest::json(cx, 201, insert_project(app, s.org, body));
}

fn health(cx: rest::Cx&, app: App&) { rest::text(cx, 200, "ok"); }
```

A body arrives parsed and validated. A malformed one is answered with 400 and its
field errors, in one error shape for every route, before the handler runs.
`rest::fail` leaves through `return ... from rest::route`, so a helper several calls
down can answer 404 without passing an error back up.

### Security

Each scheme in `securitySchemes` maps to a function named after it, which the
generated router calls only for operations that name the scheme. It is the part that
must run. What can wait is a lazy extractor, run on first call and kept in `cx` for the
request.

```goose
struct Session { user: i64, org: i64, expires: i64 }

fn security_session(cx: rest::Cx&, app: App&) -> Session {
    let raw = http::cookie(cx.req, "session");
    guard raw.len > 0 else { rest::fail(cx, 401, "unauthenticated"); }
    let s = app.sessions.find(raw);           // a per-worker cache, then the database
    guard s.user != 0 && s.expires > cx.now else { rest::fail(cx, 401, "unauthenticated"); }
    return s;
}

fn profile(cx: rest::Cx&, app: App&, s: Session) -> const Profile& {
    return rest::once(cx, cx.cache.profile) { load_profile(app, s.user) };
}
```

### Middleware

Blocks around the dispatch, for what every route shares:

```goose
fn handle(cx: rest::Cx&, app: App&) {
    rest::timed(cx) {                         // Server-Timing and the access log
        rest::cors(cx, ALLOWED_ORIGINS) {     // answers a preflight itself
            api::dispatch(cx, app)
        }
    }
}
```

A route not in the schema, such as static files or a proxy to Snowtime's page
renderer, is an `http::router` if chain in `handle`, before or after the dispatch.

### Waiting on another thread

The least settled part. Goose can't store a function to call later, so the schema
names the continuation, and the generator writes the `match` that calls it.

```json
"/reports": { "get": { "operationId": "report", "x-goose-resume": "report_done" } }
```

```goose
// On the worker: sends the job to the database thread and returns. The
// connection keeps only the route's number and the job's key.
fn report(cx: rest::Cx&, app: App&, s: Session, q: api::ReportQuery) {
    rest::ask(cx, app.db, ReportJob { org: s.org, from: q.from, to: q.to });
}

// When the answer arrives in the worker's mailbox.
fn report_done(cx: rest::Cx&, app: App&, reply: const u8[:]) {
    rest::json_bytes(cx, 200, reply);         // the database thread wrote the JSON
}
```

A route without `x-goose-resume` keeps nothing on the connection.

### Main

```goose
import http from "github.com/kaitk/goose-http@v0.2.0";
import rest from "github.com/kaitk/goose-rest@v0.1.0";
import api;
import app;

thread_fn worker(cfg: http::Config, db: http::MailAddress) {
    var state = app::open(db);                // per worker: caches, prepared statements
    let e = rest::serve(cfg, state) { cx => app::handle(cx, state) };
    http::report(e);
}

fn main() {
    let cfg = http::Config { port: 8080, .. };
    let db = app::start_db_thread("snowtime.db");
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg, db)); }
    for id in ids { thread_wait(id); }
}
```

`GET /projects/42` then costs a length match, a prefix compare, an integer parse, the
session check its operation names, the handler, and the generated writer. It looks up
no handler, runs no boxed middleware, and parses nothing the route doesn't read.

## Spike results (2026-10-13)

On Goose `a6249a4`, in goose-rest's `spikes/` (each spike's README has its command and
evidence). Nothing blocks the design; three checks need a workaround, which the design
now takes:

| Check | Verdict | What the design does |
|---|---|---|
| Overload chosen by type parameter | Works in one namespace. Across namespaces `from_request` isn't found: a generic body looks names up where it's defined (§11.1), and Goose has no argument-dependent lookup. | The app declares its extractors and writers as `fn rest::from_request(cx: rest::Cx&, v: app::Session&)` and `fn rest::write(...)`, and the generator writes them so. `T` is given explicitly: it can't be inferred from a block's typed parameter. |
| Early exit from middleware blocks | Works. A 401 skips the inner blocks and the handler, and a `return` in a block returns from the handler. A middleware's own `return` leaves only the middleware, so code after the middleware call still runs. | A middleware rejects with `rest::fail`, not `return`, so the whole route unwinds. |
| `return ... from rest::route` | Works across namespaces, and calling `fail` outside `route` is a compile error. The returned value can't hold a slice from the request ([findings](goose-findings.md#a-long-distance-return-cant-carry-a-slice-a-caller-passed-in)). | `route` and `fail` follow the stdlib's `exception` module: `route`'s inner handler returns `Failure[]`, empty or one element, and `Failure`'s code is an owned `u8[]` built with `str()`. Tested by hand on `a6249a4`; spike 03 still uses `u8[..32]`. |
| Inlining to straight-line C | Works. Nested middleware and `route` collapse into one C function, each early answer a `goto`. Passing a block on by name, `run(F)`, inlines nothing on that path ([findings](goose-findings.md#passing-a-function-value-on-by-name-keeps-every-hof-around-it-out-of-line)). | Library HOFs never pass `F` on by name; they write `run() { F() }`. So `route` is goose-rest's own, not `exception::try`, which forwards its body by name. |

Not yet run: resuming a waiting route, now through case functions
([Review results](#review-results-2026-10-13)).

## Review results (2026-10-13)

A review of this design against the Goose docs and code at `a6249a4`, after the spikes.
These corrections take precedence over the [Usage](#usage) snippets, which predate it.
The review's proposals for `goose-http` itself are its task 027.

- **Writers through the `format` hook.** A user `format` overload is looked up in the
  namespace its type is declared in (spec §3.7), the one type-directed lookup in Goose
  (§11.1). The generator writes `fn api::format(out: u8[>..]&, p: const Project&)`,
  and `rest::json` calls `format(out, v)`, so writers need no declaring into `rest::`,
  and a nested schema type finds its own writer. `print(p)` then prints JSON.
  Unverified from a generic body in `rest`. Extractors still need spike 01's
  workaround: `fn rest::from_request(...)`.
- **Readers collect, then build once.** A `u8[]` field can't grow or be assigned after
  construction, nor can a struct holding one (§4.4; goose-rest spike 05). A reader
  keeps each `json::read_string` slice as its key arrives, in any order, then builds
  the struct with one literal, in place, with no copy. Each slice starts as
  `r.text[..0]`, not `""`. A limited-array field that a repeated key appends to
  overruns its capacity and aborts (§3.3): clear it first, or use the same pattern.
  JSON Schema's `maxLength` counts code points, so a limited array holds four bytes
  per code point, and the check counts code points.
- **Key dispatch is `match key.len`.** `key == "name"` compares lengths first (§4.5), so
  `key.len == 4 &&` before it checks twice.
- **Application state is a struct of references.** A struct holds at most one
  resizable, as its last field (§3.4). Caches, sessions, and prepared statements are
  locals of the worker, and `App` holds references to them (spec Appendix A.6). It
  can't be `goose-http`'s per-request state `S`, which is fixed-size, kept in a
  `reusable` pool slot (§5.4), and reset per request (`http.goose:596`). That state is
  where `rest::once` keeps its per-request values.
- **Resume through case functions, not a generated `match`.** The per-request state
  holds a fixed-mode enum such as `Waiting { None, Report { org, from, to } }`, and the
  app writes `fn resume(cx, app, w: Waiting.Report, reply)`. The compiler dispatches on
  the tag and checks that every variant has its case (§8.2). This replaces
  `x-goose-resume`, and the generator writes nothing for it. The enum is fixed-mode
  because each request overwrites the slot (§3.5).
- **Jobs and replies cross threads as `to_bytes` images.** The mailbox carries bytes in
  fixed-size slots (256 bytes by default; a longer message returns `FULL`), so a job is
  sent with `to_bytes` and read back with `from_bytes`, which verifies it (§12). A
  reply larger than a slot, such as a report, needs bigger slots or chunks: open.
- **Every `rest::fail` caller is inside `rest::route`.** `rest::segment_int`'s 400 goes
  through `fail`, so it runs inside the `route` block, not before it, or it doesn't
  compile (spike 03).
- **Validation errors carry literals or owned bytes.** A generated field name is a
  literal and may travel with `return ... from`. An unknown key is a slice of the
  request and may not (`docs/goose-findings.md`): it is copied with `str()`, or left out
  of the message.

## The general framework, minimal

- [x] A spike confirms the language assumptions above: overload choice by type
      parameter, early `return` from middleware blocks, `return ... from rest::route`
      from a handler's callees, and nested blocks that inline to straight-line code
      ([Spike results](#spike-results-2026-10-13))
- [x] A spike settles whether a reader can fill `u8[]` fields key by key: it can't, and
      collecting slices, then building once, costs no copy (goose-rest spike 05)
- [ ] A spike resumes a waiting route through case functions on a fixed-mode enum
- [ ] Settle the TypeScript helper (open above); if kept, its types describe the
      subset exactly, and `tsc` rejects what the generator would
- [ ] A context type over `Request`, `Reply`, and the router, passed to handlers
- [ ] Prefix scopes, and 404, 405, and `OPTIONS` from `http::otherwise` across them
- [ ] Extractors: path parameters as integers or strings, query, headers, cookies,
      JSON body into a struct, each failure answered with 400 or 415
- [ ] The generator, in Goose: structs, readers, and writers from the OpenAPI subset,
      with errors for what's outside it
- [ ] The generated router, if the if chain's measured cost at 60 routes justifies it,
      with 404, 405, and `Allow` the same as the if chain's
- [ ] Middleware as blocks, with examples: CORS, a bearer token check, request timing
- [ ] An error type and `return ... from` to a single JSON error writer
- [ ] Per-worker application state, and an example of a call to a worker thread and
      back through a mailbox
- [ ] goose-http's task 021 tiers served on goose-rest, measured against `goose-http`
      alone and against Axum and actix-web in their fastest configuration, with the same
      worker count. The framework's overhead is the number this plan exists to keep small.

CORS, sessions, and middleware are left to a framework by `goose-http`'s scope
(README). A template engine, an ORM, and WebSocket aren't part of the minimal
framework. OpenAPI is its input, not something it writes.

## What Snowtime native would also need

Taken from snowtime-native's `Cargo.toml` and `crates/` on 2026-10-13. None of it is
part of this plan.

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
| TLS and ACME | rustls | goose-http's task 014 |
| Pages | The app's server bundle in V8 | Stays outside Goose: a proxy to the existing renderer |
| Auth library | better-auth-rs | Ported by hand, against the conformance tests |

The HTTP side of Snowtime (routes, extractors, middleware, JSON) is what this plan
builds. Most of the work of a Goose Snowtime is in the table.
