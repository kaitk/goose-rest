# Architecture

goose-rest is a REST framework for Goose on `goose-http`: Actix's model, changed where
Goose differs, at no cost over the hand-written `http::router` if chain wherever the
language allows. Routing, extractors, middleware, errors, per-worker state, and JSON are
the framework. A generator that writes types, readers, writers, and a router from an
OpenAPI document is an optional layer on top; a program without a schema uses all of
the rest.

Scope (2026-10-13): a general framework, not one shaped by an application. Snowtime
native, and a porting kit for Goose like the Rust one Snowtime's port started, are later
uses that inform the design ([Later uses](#later-uses)); neither is built here.

## How Goose shapes it

From the spec at `a6249a4` (2026-10-12), each checked by a spike
([Spike results](#spike-results-2026-10-13)):

- **No handler table.** Function values are compile-time generic parameters. They
  can't be stored, returned, or put in data, and there are no runtime function
  pointers (spec §7.6). Actix's `App::new().route("/x", web::get().to(h))` is a data
  structure of boxed handlers and can't exist. The application is code: routes stay an
  if chain of `rest::on` calls in `rest::routes`, or a generated `match`.
- **Middleware is a block.** A trailing block is inlined, and a `return` in it returns
  from the enclosing handler (§7.6, §7.9). `rest::cors(cx, rest::Cors { .. }) { ... }` can answer
  a preflight and not run the block, with no boxing, no dynamic dispatch, and no layer
  stack. This is cheaper than Actix's `Transform` and Tower's `Layer`, and is the
  framework's main idea.
- **Extractors by overload.** Generics are monomorphized and re-checked per
  instantiation (§7.7), so `rest::take<T>(cx)` calls `from_request(cx, v: const T?)`
  and overloading chooses by `T`, as Actix's `FromRequest` trait does.
- **No derive.** Goose has no macros, reflection, or compile-time evaluation. What Rust
  gets from serde's derive, goose-rest gets from the `format` hook written by hand, or
  from the generator ([below](#the-generator)).
- **No shared memory.** Workers share nothing but `const` data and messages (§11.2). A
  cache, a rate limiter, or a session store is per worker, or lives on a thread of its
  own that workers mail. Mailboxes and answers that wait (`mail.goose`, `http::later`)
  already carry that.
- **No async.** A handler that waits on another thread splits in two around the reply,
  with its state in the connection. The framework makes that split readable, since
  every database call that leaves the worker needs it.

## Actix, and where goose-rest differs

| Actix | goose-rest | Why |
|---|---|---|
| `HttpServer::new(\|\| App::new())` builds an `App` per worker thread | Each worker's `thread_fn` builds its own state and calls `rest::serve` | The same model. Goose enforces it: workers share nothing. |
| `web::Data<T>`, `app_data` | `App`, a struct of references to the worker's locals, in `cx.app` | A struct holds at most one resizable, as its last field (§3.4); references avoid that limit (Appendix A.6). |
| `App::route`, `web::scope`, `web::resource`, guards | `rest::on` inside `rest::routes`, with `rest::scope(cx, prefix)`; guards are `if` conditions | No handler table. |
| `FromRequest` extractors as handler arguments | `let v = rest::take<T>(cx);`, or `rest::param_int(cx, "id")` | `T` is explicit; Goose can't infer it from the result (spike 08). |
| Middleware: `wrap`, `from_fn`, `Transform` | Blocks around the dispatch or a route, inlined into it | No boxing and no call per layer (spike 04). |
| `ResponseError`, `Result<impl Responder, E>`, `?` | `rest::fail(cx, status, code)` returns from `rest::route` from any depth | `return ... from` replaces threading a `Result` up (spike 03). |
| `Responder`, `web::Json<T>` | `rest::json(cx, status, v)`, which calls `format(out, v)` | The `format` hook is Goose's one type-directed lookup (§3.7, §11.1). |
| serde's `Serialize` and `Deserialize` | `format` and a reader per type, written by hand or generated | No derive. |
| `async fn` handlers awaiting a database | A handler that asks another thread, and a case function that resumes it | No async ([Waiting on another thread](#waiting-on-another-thread)). |

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
[generator reference](../generator.md) lists the subset as built.
`pattern` waits on anchors in Goose's `regex`
([findings](../goose-findings.md#the-regex-module-has-no-anchors-so-json-schemas-pattern-cant-be-checked)).

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
  (`u8[..480]` for 120), and the reader counts code points. An unbounded one is a
  variable-size `u8[]` field, kept inline in the struct.
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
  mailbox as `to_bytes` images, with no JSON between threads.

## Usage

The examples are sketches; the [tutorial](../tutorial/README.md) quotes programs the test
suite builds and requests.

Decided (2026-10-14): the context is `Cx<S, A, R>`, with the
request's state, the worker's state, and the router's type. `rest::routes` supplies
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
forms, with an optional `http::Config` after `fresh`.

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

### Without a schema

The framework alone, as an Actix program would use it:

```rust
namespace app;

fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    rest::route(cx) {
                        let s = security_session(cx);
                        if rest::on(cx, "GET", "/projects/:id") {
                            get_project(cx, s, rest::param_int(cx, "id"));
                        } else if rest::on(cx, "POST", "/projects") {
                            create_project(cx, s, rest::take<ProjectCreate>(cx));
                        } else {
                            rest::otherwise(cx);
                        }
                    };
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}
```

Built: `timed` and `cors` add their fields to every answer inside them, the
route's errors included, so they go outside `rest::route`, and answer what they refuse
themselves. Checks that fail, `rest::bearer` and the program's own, go inside it.
`rest::scope` narrows the router to a prefix, and `rest::otherwise` answers 404, 405,
and OPTIONS across scopes from the routes it passed.

### Inlining

Decided (2026-10-13), from `test/inline_route.goose`'s C. A handler behind
middleware compiles to one C function, the handler, with the middleware, the route,
and the code that fails inlined into it, and each early answer a jump. Three rules keep
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
  although it's called once ([findings](../goose-findings.md#a-function-called-once-isnt-inlined-past-a-size)).
  So `route`, `attempt`, `cors`, `bearer`, `timed`, and `json_body` are `inline fn`.

`ProjectCreate` has a reader the program declares as
`fn rest::from_request(cx, v: const app::ProjectCreate?) -> app::ProjectCreate` (spike
01), and `Project` a `fn format(out: u8[>..]&, p: const Project&)` in its own namespace.

Decided (2026-10-13): `take<T>` returns the value, and `from_request` gets a
null `const T?` whose type picks the overload. A `from_request(cx, v: T&)` that fills
a default `T` can't build a `T` holding `u8[]` fields, which can't be assigned after
construction (spike 05). A returned `T` is built at the caller's destination. The block
form, `take<T>(cx) { v => ... }`, would hand the block a copy of a local (goose-http's
findings).

### Handlers

```rust
namespace app;

fn get_project(cx, s: Session, id: i64) {
    let p = find_project(cx.app, s.org, id);
    guard p.id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    rest::json(cx, 200, p);                   // calls format(out, p)
}

fn create_project(cx, s: Session, body: const ProjectCreate&) {
    rest::json(cx, 201, insert_project(cx.app, s.org, body));
}
```

A body arrives parsed and validated. A malformed one is answered with 400 and its field
errors, in one error shape for every route, before the handler runs. `rest::fail`
leaves through `return ... from rest::route`, so a helper several calls down can answer
404 without passing an error back up. Every caller of `fail` runs inside `route`, or it
doesn't compile (spike 03). `Failure`'s code is an owned `u8[]` built with `str()`, and
a field name the generator writes is a literal; a slice of the request can't travel
with the return ([findings](../goose-findings.md#a-long-distance-return-cant-carry-a-slice-a-caller-passed-in)).
Decided (2026-10-13): the first answer wins. A failure after the handler began
a response leaves that response, because `route` can't shrink the write buffer while a
slice of the request is live (spec §5.1).

### Security

A security check is the part that must run; it fails the route. What can wait is a lazy
extractor, run on first call and kept in the per-request state for the request.

```rust
struct Session { user: i64, org: i64, expires: i64 }

fn security_session(cx) -> Session {
    let raw, has = rest::cookie(cx, "session");
    guard raw.len > 0 else { rest::fail(cx, 401, "unauthenticated"); }
    let s = cx.app.sessions.find(raw);        // a per-worker cache, then the database
    guard s.user != 0 && s.expires > clock_ns() else { rest::fail(cx, 401, "unauthenticated"); }
    return s;
}

fn profile(cx, s: Session) -> const Profile& {
    return rest::once(cx.state.profile) { load_profile(cx.app, s.user) };
}
```

`cx.state.profile` is a `rest::Once<Profile>`, which starts each request undone.

`cx.state` is `goose-http`'s per-request state `S`: fixed-size, kept in a `reusable`
pool slot (§5.4), and reset per request. The worker's application state is `cx.app`.

### With a schema

```text
api.ts              the document, typed to the subset (optional)    (written)
api.json            the OpenAPI subset                              (written, or from api.ts)
api_gen.goose       types, readers, writers, router                 (generated)
app.goose           handlers, security checks, application state    (written)
main.goose          workers and middleware                          (written)
```

The build runs `goose-rest gen api.json -o api_gen.goose`, after writing `api.json`
from `api.ts` where there is one. The generated file is `api_gen.goose`, not
`api.gen.goose`, because an import names a module by identifiers separated by dots
(2026-10-13).

Decided (2026-10-14): goose-rest commits its generated files, under `test/gen/`,
`examples/`, `docs/tutorial/`, and `bench/`, as golden files that `scripts/test.sh`
regenerates and compares byte for byte. An application chooses for itself. It can
commit its `api_gen.goose`, so that a schema change shows as a diff of the code it
makes in review and the build needs no generator, or generate it in its build.

```json
"paths": {
  "/projects": {
    "get":  { "operationId": "list_projects", "security": [{"session": []}],
              "parameters": [{"name": "archived", "in": "query", "schema": {"type": "boolean"}}] },
    "post": { "operationId": "create_project", "security": [{"session": []}],
              "requestBody": { "required": true, "content": { "application/json":
                { "schema": {"$ref": "#/components/schemas/ProjectCreate"} } } } }
  },
  "/projects/{id}": {
    "get":  { "operationId": "get_project", "security": [{"session": []}],
              "parameters": [{"name": "id", "in": "path", "required": true,
                              "schema": {"type": "integer"}}] }
  },
  "/health": { "get": { "operationId": "health" } }
},
"components": { "schemas": {
  "ProjectCreate": { "type": "object", "required": ["name"], "additionalProperties": false,
    "properties": { "name":  {"type": "string", "minLength": 1, "maxLength": 120},
                    "color": {"type": "string", "maxLength": 7} } }
}}
```

The generator writes plain Goose, read and debugged like any other file, never edited.
This is its output for `ProjectCreate` and the router, shortened, and the
[reference](../generator.md) has the rest.

```rust
namespace api;

struct ProjectCreate { name: u8[..480], has_color: bool, color: u8[..28] }

// Reads the ProjectCreate at the cursor, checks it, and builds it once. Errors
// are sticky, as json::Reader's are: after one, it returns an empty value.
fn read_project_create(r: json::Reader&, scratch: u8[>..]&) -> ProjectCreate {
    var name = r.text[..0];
    var has_name = false;
    var color = r.text[..0];
    var has_color = false;
    json::each_member(r) { key =>
        match key.len {
            4 => if key == "name" { name = json::read_string(r, scratch); has_name = true; }
                 else { json::fail(r, "unknown member"); },
            5 => if key == "color" { color = json::read_string(r, scratch); has_color = true; }
                 else { json::fail(r, "unknown member"); },
            _ => json::fail(r, "unknown member"),     // additionalProperties: false
        }
    };
    if !has_name { json::fail(r, "name: required"); }
    {
        let n_ = rest::code_points(name);             // -1 unless UTF-8
        if n_ < 0 { json::fail(r, "name: not UTF-8"); }
        if n_ >= 0 && n_ < 1 { json::fail(r, "name: minLength"); }
        if n_ > 120 { json::fail(r, "name: maxLength"); }
    }
    ...                                               // color's maxLength
    if r.error.len > 0 { return ProjectCreate { .. }; }
    return ProjectCreate { name: name, has_color: has_color, color: color };
}

// Writes only the declared fields, each key's bytes a constant.
fn format(out: u8[>..]&, v: const ProjectCreate&) {
    out.append("{\"name\":");
    json::format_string(out, v.name);
    if v.has_color {
        out.append(",\"color\":");
        json::format_string(out, v.color);
    }
    out.push('}');
}

fn dispatch(cx) {
    let allow = rest::allow_before(cx);
    let path = http::path_of(cx.req.target);
    let m = cx.req.method;
    guard http::known_method(m) && http::is_routable(path) else { rest::no_route(cx, m, path); return; }
    let plain = find(path, "%") < 0;
    if plain {
        match path.len {                      // static paths: length, then bytes
            7 => {
                if path == "/health" {
                    if m == "GET" || m == "HEAD" {
                        rest::route(cx) {
                            app::health(cx);
                        };
                        return;
                    }
                    rest::no_method(cx, "GET, HEAD", allow);   // Allow is a constant
                    return;
                }
            },
            9 => { ... },                     // /projects
            _ => {},
        }
    }
    if path.len > 0 && path[0] == '/' {       // then by segment, literals before parameters
        let e0 = 0;
        if e0 < path.len {
            let s1, e1 = rest::segment(path, e0);
            if rest::segment_is(s1, "projects", plain) {
                ...
                if e1 < path.len {
                    let s2, e2 = rest::segment(path, e1);
                    if s2.len > 0 {
                        if e2 == path.len {
                            if m == "GET" || m == "HEAD" {
                                rest::route(cx) {
                                    let s_ = app::security_session(cx);         // only where named
                                    let id = rest::path_int(cx, s2, "id");      // 400 unless an integer
                                    app::get_project(cx, s_, id);
                                };
                                return;
                            }
                            rest::no_method(cx, "GET, HEAD", allow);
                            return;
                        }
                    }
                }
            }
            ...
        }
    }
    rest::not_found(cx, m, path, allow);
}
```

Each object also gets a `fn rest::from_request` that reads the JSON
body, and an operation with query, header, or cookie parameters gets a struct of them,
`<OperationId>Params`, with its own `from_request`. The router reads both with
`rest::take` and passes them to the handler after the path parameters.

Each handler call is typed from its operation. A missing `app::get_project`, or one
whose `id` isn't an `i64`, fails to compile, which keeps schema and code in step
without Elysia's dry run and fingerprint. `/health` names no `security`, so no session
code is generated for it. A reader's errors are static text, a property name and a
keyword, because the reader's error is a slice and the key is a slice of the request;
`json::Reader`'s `error_at` locates the member.

### Waiting on another thread

Checked by spike 06; built in `waiting.goose`, whose header shows the API:
`rest::ask`, `rest::woken`, `rest::answer`, and `rest::relay`. `rest::wanted` tells the
other thread whether the route still waits, so it can skip the work of a client that has
gone. Goose can't store a function to call later, so the per-request state holds a
fixed-mode enum of what each waiting route needs, and the app writes a case function per
variant. The compiler dispatches on the tag and checks that every variant has its case
(§8.2). The enum is fixed-mode because each request overwrites the slot (§3.5).

The default is a service: a thread that owns the connections, to which a route sends one
job naming the whole use case, and which does it start to end with blocking calls, in
one transaction (2026-10-14). A route then waits once, with one time limit and one place
a full box refuses work, and a use case is tested as a plain call. A route waits more than
once only for what one service can't do: a second service in turn. The tutorial builds
both, from [work that waits](../tutorial/13-waiting.md) to
[limits](../tutorial/15-limits.md).

```rust
let REPORT: i32 = 1;
enum Waiting { None, Report { org: i64, from: i64, to: i64 } }
struct St { waiting: Waiting = Waiting.None }

// On the worker: sends the job to the database thread and returns.
fn report(cx, s: Session, q: api::ReportParams) {
    rest::ask(cx, cx.app.db, REPORT, ReportJob { org: s.org, from: q.from, to: q.to },
              Waiting.Report { org: s.org, from: q.from, to: q.to });
}

// When the answer arrives in the worker's mailbox.
fn resume(w: Waiting.Report, cx) {
    rest::relay(cx, 200, "application/json"); // the database thread wrote the JSON
}
```

The job crosses as a `to_bytes` image and is read back with `from_bytes`, which verifies
it (§12). The mailbox carries bytes in fixed-size slots (256 bytes by default; a longer
message returns `TOO_LONG`), as goose-http's
[mail between threads](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#mail-between-threads)
explains. A reply larger than a slot comes in pieces of at most a
slot; `rest::relay` sends each as a chunk and calls `http::later` again until the last.
The job carries the slot size, and the sender retries a piece that finds the box full.
A program whose
replies all fit raises `Config.mail_size` instead. A route that never waits keeps
nothing on the connection.

### Main

```rust
import http from "github.com/kaitk/goose-http@<commit>";
import rest from "github.com/kaitk/goose-rest@<commit>";
import app;

thread_fn worker(cfg: http::Config, db: http::MailAddress) {
    var sessions = app::sessions();           // per worker: caches, prepared statements
    var app = app::App { sessions: sessions, db: db };
    let e = rest::serve(cfg, app, app::St { .. }) { cx => app::handle(cx) };
    http::report(e);
}

fn main() {
    let cfg = http::Config { port: 8080, .. };
    let db = app::start_db_thread("app.db");
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg, db)); }
    for id in ids { thread_wait(id); }
}
```

`GET /projects/42` then costs a router match, an integer parse, the session check, the
handler, and the writer. It looks up no handler, runs no boxed middleware, and parses
nothing the route doesn't read.

## Spike results (2026-10-13)

On Goose `a6249a4`, and again on `46356c2` with the same results but spike 04's, whose
by-name form now inlines too, in `spikes/` (each spike's README has its command and evidence).
Nothing blocks the design; three checks need a workaround, which the design takes:

| Check | Verdict | What the design does |
|---|---|---|
| Overload chosen by type parameter (01) | Works in one namespace. Across namespaces `from_request` isn't found: a generic body looks names up where it's defined (§11.1), and Goose has no argument-dependent lookup. | The app declares `fn rest::from_request(cx, v: const app::Session?) -> app::Session`, and the generator writes the same form. `T` is given explicitly. |
| Early exit from middleware blocks (02) | Works. A 401 skips the inner blocks and the handler, and a `return` in a block returns from the handler. A middleware's own `return` leaves only the middleware, so code after the middleware call still runs. | A middleware rejects with `rest::fail`, not `return`, so the whole route unwinds. |
| `return ... from rest::route` (03) | Works across namespaces, and calling `fail` outside `route` is a compile error. The returned value can't hold a slice from the request ([findings](../goose-findings.md#a-long-distance-return-cant-carry-a-slice-a-caller-passed-in)). | `route` and `fail` follow the stdlib's `exception` module: `route`'s inner handler returns `Failure[]`, empty or one element, and `Failure`'s code is an owned `u8[]` built with `str()`. Built so in `runtime.goose`. |
| Inlining to straight-line C (04) | Works. Nested middleware and `route` collapse into one C function, each early answer a `goto`, also when a block is passed on by name, `run(F)`. | `rest::route` passes `F` on by name. `route` is goose-rest's own, not `exception::try`: it answers the failure, and it's `inline fn` ([findings](../goose-findings.md#a-function-called-once-isnt-inlined-past-a-size)). |
| Filling `u8[]` fields from JSON (05) | Can't fill them key by key; collecting slices, then building once, costs no copy. | Readers collect, then build once ([above](#gooses-data-model-in-generated-code)). |
| Resuming a waiting route (06) | Works, under `http::serve` too. The job crosses as a `to_bytes` image, `Waiting` lives in the per-request state, and a `WAKE` event dispatches to one case function per variant. A missing case fails to compile, with an error that doesn't name it ([findings](../goose-findings.md#a-case-function-call-missing-a-variant-doesnt-name-it)). | Replies larger than a slot come in pieces ([above](#waiting-on-another-thread)). |
| The `format` hook from `rest::json` (07) | Works with no workaround, for nested types and types in a third namespace, beside `rest`'s own `format`. A type with no overload renders as `app::Session { 1, 2 }`, not JSON, and compiles. | `rest::json` calls `format`. The generator writes an overload per schema type, strings through `json::format_string`. |

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

CORS, sessions, and middleware are left to a framework by `goose-http`'s scope
(README). A template engine, an ORM, and WebSocket aren't part of the framework.
The generator reads OpenAPI as its input. Writing an OpenAPI document from the routes,
as Elysia's openapi plugin does, is planned for later (2026-10-15).
