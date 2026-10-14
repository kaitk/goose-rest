# goose-rest, by example

<details>
<summary>Table of contents</summary>

- [1. The one idea](#1-the-one-idea)
- [2. Running something](#2-running-something)
- [3. Routes and extractors](#3-routes-and-extractors)
- [4. Answers and errors](#4-answers-and-errors)
- [5. JSON bodies](#5-json-bodies)
- [6. The whole API from a schema](#6-the-whole-api-from-a-schema)
- [7. Generated and hand-written routes](#7-generated-and-hand-written-routes)
- [8. Middleware and scopes](#8-middleware-and-scopes)
- [9. Large bodies](#9-large-bodies)
- [10. State](#10-state)
- [11. The schema in TypeScript, Python, or Rust](#11-the-schema-in-typescript-python-or-rust)
- [12. Testing without sockets](#12-testing-without-sockets)
- [13. On a board](#13-on-a-board)
- [14. Where to go next](#14-where-to-go-next)

</details>

This tutorial builds a small projects API with goose-rest, one step at a time. It assumes
you know another web framework, such as Actix, Axum, Express, or FastAPI, and that you
have read [Goose, by example](https://github.com/aardappel/goose/blob/master/docs/tutorial.md),
or will alongside this. It covers what differs from those frameworks; the
[reference](reference.md) and the [generator reference](generator.md) have the exact
rules.

Each step is a program under [`tutorial/`](tutorial/), and every Goose and JSON block
below is quoted from one of them or from [`examples/`](../examples/).
`scripts/test.sh` builds each program, sends it the requests in its `requests.sh`, and
compares the answers with its `expected.txt`, so what this page shows is what the code
does.

---

## 1. The one idea

A goose-rest server is a few worker threads, each running goose-http's event loop with
your handler inlined into it. Workers share nothing but constants and messages: each
has its own copy of the globals, and there are no locks. Each one builds its own state,
and a request runs start to finish on the worker that read it.

Inside a worker, a route runs inside `rest::route`, and `rest::fail` answers the request
from any depth below it. From [`tutorial/02-hello`](tutorial/02-hello/main.goose):

```goose
fn handle(cx) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/hello/:name") {
        rest::route(cx) { hello(cx, rest::param(cx, r, "name")); };
    } else {
        rest::otherwise(cx, r);
    }
}

fn hello(cx, name: const u8[:]) {
    rest::text(cx, 200, greeting(cx, name));
}

fn greeting(cx, name: const u8[:]) -> u8[>..] {
    guard name.len <= 20 else { rest::fail(cx, 400, "name_too_long"); }
    return str("hello, ", name);
}
```

`greeting` returns a string, not a `Result`, and `hello` doesn't check anything. When
the name is too long, `rest::fail` leaves through Goose's `return ... from`, straight
to the `rest::route` around `hello`, which answers `400 {"error":"name_too_long"}`.
The compiler checks that every call that can fail runs inside a `rest::route`: one
outside it doesn't compile.

The rest of goose-rest follows from these two facts:

- There is no handler table. Goose can't store a function, so routes are code: an
  `if` chain over `http::router`, or a router the generator writes as a `match`.
- Middleware is a block around routes, inlined into the handler, so it costs no call
  and no boxing. A `rest::fail` inside it leaves the whole route.
- State a request changes lives in its worker, or on a thread of its own that workers
  send messages to ([section 10](#10-state)).

---

## 2. Running something

A program's root file declares both packages, goose-http at goose-rest's pin and
goose-rest at a pushed commit, each by its full commit hash:

```text
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "github.com/kaitk/goose-rest@<40-hex commit>";
```

The tutorial's programs live in this repository, so they import goose-rest by path
instead (`import rest from "../../../";`). The [README](../README.md#pins) has the
current goose-http pin.

A worker is a `thread_fn` that calls `rest::serve`, which calls its block with a
`rest::Cx`, the request's context, for each request:

```goose
thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    assert(http::stop_on_signals() == 0);
    let cfg = http::Config { port: port as i32, .. };
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
```

`http::worker_count` is `cfg.workers`, or without it one worker per hardware thread (per
performance core on macOS), and `http::stop_on_signals` makes SIGINT and SIGTERM stop
the server rather than end the process. The other
programs repeat this `main`, some with `workers: 1`.

Build with `goose build`. `goose run`, the in-process TinyCC backend, can't run threads,
and a server spawns them:

```sh
goose build -o build/hello docs/tutorial/02-hello/main.goose
build/hello 8080
curl -s localhost:8080/hello/goose              # hello, goose
curl -s localhost:8080/hello/aaaaaaaaaaaaaaaaaaaaaaaaa
                                                # {"error":"name_too_long"}
curl -s -X POST localhost:8080/hello/goose      # {"error":"method_not_allowed"}
```

---

## 3. Routes and extractors

A router is goose-http's `http::router`, and each route an `http::on` with a method and
a pattern: literal segments, `:name` for one segment, and `*name`, last, for the rest of
the path. `GET` routes take `HEAD` too. A route that matches the path with another method
adds the method to the router's `Allow`, so `rest::otherwise`, at the end of the chain,
answers 405 with `Allow` where the path exists, 404 where it doesn't, and OPTIONS itself.

`rest::scope` takes a prefix off the path, so the routes inside it match the rest. From
[`tutorial/03-routes`](tutorial/03-routes/main.goose):

```goose
fn handle(cx) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/health") {
        rest::text(cx, 200, "ok");
    } else if rest::scope(r, "/v1") {
        rest::route(cx) { v1(cx, r); };
    } else {
        rest::otherwise(cx, r);
    }
}
```

Extractors read one part of the request each. They are plain calls, made where the
handler needs the value, rather than handler arguments as in Actix or Axum:

```goose
fn v1(cx, r: http::Router&) {
    if http::on(r, "GET", "/projects") {
        let q, has_q = rest::query(cx, "q");
        let archived, has_archived = rest::query_bool(cx, "archived");
        let limit, has_limit = rest::query_int(cx, "limit");
        rest::json(cx, 200, Listing { q: q, archived: archived, limit: if has_limit { limit } else { 10 } });
    } else if http::on(r, "GET", "/projects/:id") {
        rest::json(cx, 200, find_project(cx, rest::param_int(cx, r, "id")));
    } else if http::on(r, "GET", "/me") {
        let user, has_user = rest::header(cx, "X-User");
        rest::require(cx, "X-User", has_user);
        let theme, has_theme = rest::cookie(cx, "theme");
        rest::text(cx, 200, str(user, " likes ", if has_theme { theme } else { "light" }));
    } else {
        rest::otherwise(cx, r);
    }
}
```

An optional value comes with a `bool` that says whether the request has it, and a value
that doesn't parse fails the route with 400. `rest::require` turns a missing one into a
failure too:

```text
GET /v1/projects?archived=yes  400 {"error":"invalid_parameter","detail":"archived: boolean"}
GET /v1/projects/two           400 {"error":"invalid_parameter","detail":"id: integer"}
GET /v1/me                     400 {"error":"invalid_parameter","detail":"X-User: required"}
DELETE /v1/projects/2          405 {"error":"method_not_allowed"}
```

An extractor returns a slice of the request where there is nothing to decode, and
otherwise decodes into `cx.scratch`. Either lasts until the handler returns, so a
value is used in the request and copied if it must outlive it. The
[reference](reference.md#extractors) lists every extractor and what it fails with.

---

## 4. Answers and errors

A route answers once, with one of these:

| Call | Answers |
|---|---|
| `rest::json(cx, status, v)` | `v` as JSON, written by `v`'s `format` overload |
| `rest::json_bytes(cx, status, body)` | JSON the program wrote itself |
| `rest::text(cx, status, s)` | `s` as `text/plain; charset=utf-8` |
| `rest::fail(cx, status, code)` | `{"error": code}`, from anywhere inside `rest::route` |
| `http::start`, `http::field`, `http::finish` | anything else, such as a 204 or a page |

`rest::json` calls `format(out, v)`, Goose's one type-directed hook, and Goose finds the
overload in the namespace that declares `v`'s type. There is no derive: a type gets its
JSON from a `format` you write, or from the generator ([section 5](#5-json-bodies)).
From `tutorial/03-routes`:

```goose
fn format(out: u8[>..]&, p: const Project&) {
    out.append("{\"id\":");
    format(out, p.id);
    out.append(",\"name\":");
    json::format_string(out, p.name);
    out.push('}');
}
```

A type without its own `format` still compiles, and is written as Goose prints it, such
as `app::Session { 1, 2 }`, which isn't JSON. A string's `format` is std's, which writes its
bytes unquoted, so answer a string inside an object.

`rest::fail` takes a code, and any function inside a route can call it.
`find_project` returns a reference, and fails where there is nothing to return:

```goose
fn find_project(cx, id: i64) -> const Project& {
    for &p in PROJECTS {
        if p.id == id { return p; }
    }
    rest::fail(cx, 404, "project_not_found");
}
```

Every error goose-rest writes, its own and the program's, has one shape:
`{"error": code}`, with `detail` for a parameter or a body and `at` for where a body's
reader stopped. The [reference](reference.md#errors) lists each status and code. The
first answer wins: a route that answers and then fails keeps its answer.

A program picks its own shape with an overload of `rest::error_body` for the type of its
per-request state, which `rest::serve(cfg, fresh)` sets ([section 10](#10-state)). The
overload gets every error, including the 404s, 405s, and 413s goose-rest writes itself.
From [`tutorial/04-errors`](tutorial/04-errors/main.goose):

```goose
struct St { unused: bool = false }

fn rest::error_body(body: u8[>..]&, st: const St&, status: i32, code: const u8[:],
                    detail: const u8[:], at: i64) {
    body.append("{\"error\":{\"code\":");
    json::format_string(body, code);
    body.append(",\"status\":");
    format(body, status);
    if detail.len > 0 {
        body.append(",\"message\":");
        json::format_string(body, detail);
    }
    body.append("}}");
}
```

```goose
    let e = rest::serve(cfg, St { .. }) { cx => handle(cx) };
```

```text
GET /projects/2  404 {"error":{"code":"project_not_found","status":404}}
GET /projects/x  400 {"error":{"code":"invalid_parameter","status":400,"message":"id: integer"}}
POST /projects/1 405 {"error":{"code":"method_not_allowed","status":405}}
```

The overload is declared in the `rest` namespace, `fn rest::error_body`, because a
generic function finds names where it's defined, not where it's called. The same holds
for `rest::from_request`, next.

---

## 5. JSON bodies

`rest::take<T>(cx)` is goose-rest's extractor by type, Actix's `web::Json<T>`. It calls
the overload `rest::from_request(cx, v: const T?)` that you, or the generator, declare
for `T`. `v` is always null; only its type matters.

For a body read by hand, the overload passes a reader to `rest::json_body`, which
answers 415 unless the request says `application/json`, and 400 `invalid_body` for a body
the reader refuses. A reader collects each member as a slice, checks them, and builds the
struct once at the end: a struct holding a string can't be filled field by field. From
[`tutorial/05-reader`](tutorial/05-reader/main.goose):

```goose
struct ProjectCreate { name: u8[..256] }

fn read_create(r: json::Reader&, scratch: u8[>..]&) -> ProjectCreate {
    var name = r.text[..0];
    var has_name = false;
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); has_name = true; }
        else { json::fail(r, "unknown member"); }
    };
    if !has_name { json::fail(r, "name: required"); }
    let n = rest::code_points(name);
    if has_name && (n < 1 || n > 64) { json::fail(r, "name: length"); }
    if r.error.len > 0 { return ProjectCreate { name: "" }; }
    return ProjectCreate { name: name };
}

fn rest::from_request(cx, v: const ProjectCreate?) -> ProjectCreate {
    rest::json_body(cx) { r, scratch => read_create(r, scratch) }
}
```

```goose
    if http::on(r, "POST", "/projects") {
        rest::route(cx) {
            let body = rest::take<ProjectCreate>(cx);
            let p .= app.projects.push(Project { id: app.projects.len + 1, name: body.name });
            rest::json(cx, 201, p);
        };
```

```text
POST /projects 201 {"id":1,"name":"goose"}
POST /projects 400 {"error":"invalid_body","detail":"name: length","at":12}
POST /projects 400 {"error":"invalid_body","detail":"expected ',' or '}'","at":16}
POST /projects 415 {"error":"unsupported_media_type"}
```

`T` is given explicitly, `take<ProjectCreate>`: Goose can't infer it from what the result
is assigned to.

Writing readers by hand gets old. The generator writes the struct, the reader, the
`format` writer, and the `from_request` overload for each schema in an OpenAPI
document's `components`. A document without `paths` gets only those, and the routes stay
yours. From [`tutorial/05-types`](tutorial/05-types/api.json):

```json
  "components": {
    "schemas": {
      "Project": {
        "type": "object",
        "required": ["id", "name"],
        "properties": {
          "id": { "type": "integer", "minimum": 1 },
          "name": { "type": "string", "minLength": 1, "maxLength": 64 },
          "color": { "type": "string", "maxLength": 7 }
        }
      },
```

Generate `api_gen.goose` beside it, and import it from the root as `.api_gen`:

```sh
goose build -o build/goose-rest gen/main.goose        # once, from this repository
build/goose-rest gen docs/tutorial/05-types/api.json -o docs/tutorial/05-types/api_gen.goose
```

The generated namespace is `api`. `Project` becomes a struct with `has_color` before its
optional `color`, and its strings limited arrays of four bytes per code point:

```goose
struct Project {
    id: i64,
    name: u8[..256],
    has_color: bool,
    color: u8[..28],
}
```

The hand-written routes use the generated types as their own:

```goose
    if http::on(r, "POST", "/projects") {
        rest::route(cx) {
            let body = rest::take<api::ProjectCreate>(cx);
            let p .= app.projects.push(api::Project {
                id: app.projects.len + 1, name: body.name, has_color: body.has_color, color: body.color,
            });
            rest::json(cx, 201, p);
        };
```

The generated reader names the field and the check that failed, and the writer leaves
out an optional field that isn't there:

```text
POST /projects 201 {"id":1,"name":"goose","color":"#00ff00"}
POST /projects 201 {"id":2,"name":"gander"}
POST /projects 400 {"error":"invalid_body","detail":"color: maxLength","at":39}
POST /projects 400 {"error":"invalid_body","detail":"unknown member","at":26}
```

The generator's file is never edited by hand: change the schema and regenerate.
`scripts/test.sh` regenerates every `api_gen.goose` in this repository and fails when one
differs from the committed file. The [generator reference](generator.md#the-subset)
lists the schema keywords it reads, and refuses anything else with the construct's JSON
pointer rather than drop it.

---

## 6. The whole API from a schema

With `paths`, the generator also writes the router, `api::dispatch(cx, state)`, and the
program writes the handlers it calls. [`tutorial/06-schema`](tutorial/06-schema/) has
three files besides the schema: `api_gen.goose`, generated; `app.goose`, the handlers;
and `main.goose`, the workers. Here are the paths from its `api.json`:

```json
  "paths": {
    "/health": { "get": { "operationId": "health" } },
    "/v1/projects": {
      "get": {
        "operationId": "listProjects",
        "parameters": [
          { "name": "q", "in": "query", "schema": { "type": "string", "maxLength": 64 } },
          { "name": "limit", "in": "query", "schema": { "type": "integer", "minimum": 1, "maximum": 100 } }
        ]
      },
      "post": {
        "operationId": "createProject",
        "security": [{ "token": [] }],
        "requestBody": {
          "required": true,
          "x-body-limit": 16384,
          "content": { "application/json": { "schema": { "$ref": "#/components/schemas/ProjectCreate" } } }
        }
      }
    },
    "/v1/projects/{id}": {
      "get": {
        "operationId": "getProject",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "integer", "minimum": 1 } }]
      }
    }
  },
```

Each operation calls a handler in the `app` namespace, named after its `operationId` in
snake_case: `listProjects` calls `app::list_projects`. A handler's arguments come in this
order:

1. `cx`, and `state`, whatever the program passed to `dispatch`.
2. The security check's result, when the operation names a scheme.
3. The path parameters, in the template's order, typed: an `integer` is an `i64`.
4. A struct of the query, header, and cookie parameters, `<OperationId>Params`.
5. The body, as the `$ref`'s type.

So the handlers in [`app.goose`](tutorial/06-schema/app.goose) are:

```goose
fn health(cx, state: App&) { rest::text(cx, 200, "ok"); }

fn list_projects(cx, state: App&, q: api::ListProjectsParams) {
    rest::json(cx, 200, Listing { app: state, q: if q.has_q { q.q } else { "" }, limit: if q.has_limit { q.limit } else { 20 } });
}

fn create_project(cx, state: App&, user: const u8[:], body: const api::ProjectCreate&) {
    let p .= state.projects.push(api::Project { id: state.projects.len + 1, name: body.name, owner: user });
    rest::json(cx, 201, p);
}

fn get_project(cx, state: App&, id: i64) {
    guard id <= state.projects.len else { rest::fail(cx, 404, "project_not_found"); }
    rest::json(cx, 200, state.projects[id - 1]);
}
```

`get_project` doesn't check that `id` is at least 1: the router has, from the schema's
`minimum`, and answered `400 {"error":"invalid_parameter","detail":"id: minimum"}`
without calling it. The parameters struct holds each optional parameter after a
`has_` flag:

```goose
struct ListProjectsParams {
    has_q: bool,
    q: const u8[:],
    has_limit: bool,
    limit: i64,
}
```

A scheme in `security` calls `app::security_<scheme>(cx, state)` before the handler, and
the handler gets what it returns. Here the `token` scheme checks a bearer token and
returns the user it belongs to:

```goose
fn security_token(cx, state: App&) -> const u8[:] {
    guard rest::bearer_token(cx) == state.token else { rest::invalid_token(cx); }
    return "ada";
}
```

The router calls the handlers by name, with their types, so the schema and the handlers
can't drift apart unnoticed. Delete `get_project`, and the build stops:

```text
api_gen.goose:258: error: unknown function: app::get_project
                                            app::get_project(cx, state, id);
  in fn rest::attempt<F = {block at api_gen.goose:255:57}>() instantiated from .../runtime.goose:206
  in fn rest::route<F = {block at api_gen.goose:255:57}>(rest::Cx<rest::NoState>) instantiated from api_gen.goose:255
  in fn api::dispatch(rest::Cx<rest::NoState>, app::App&) instantiated from main.goose:32
  ...
```

Declare its `id` as a string instead, and it stops with
`argument 3: cannot pass i64 as const u8[:]`. Read the chain from the top: the line in
`api_gen.goose` names the call, and the operation is the one around it.

The workflow, then, is: change `api.json`, regenerate `api_gen.goose`, and let the
compiler list the handlers to add or change. This repository commits both files, so
that a schema change shows in review as a diff of the code it makes; whether a program
must is left open ([architecture](architecture/README.md#with-a-schema)).

The router itself is a `match` on the path's length for the static paths, then a walk
segment by segment, literals before parameters. Its answers are the `if` chain's,
byte for byte, except that a typed parameter is checked and a literal path wins over a
template that also matches ([generator reference](generator.md#how-it-matches)).

---

## 7. Generated and hand-written routes

`dispatch` answers every request it's given, with 404 for a path the schema doesn't
have. A route the schema can't describe, such as one whose body isn't JSON, goes
before it, in a scope of its own. From
[`tutorial/06-schema/main.goose`](tutorial/06-schema/main.goose):

```goose
fn handle(cx, state: app::App&) {
    var r = http::router(cx.req);
    if rest::scope(r, "/uploads") {
        rest::route(cx) { uploads(cx, state, r); };
    } else {
        api::dispatch(cx, state);
    }
}

// Uploads of any bytes, which a schema can't describe: its bodies are JSON.
fn uploads(cx, state: app::App&, r: http::Router&) {
    if http::on(r, "PUT", "/:name") {
        app::security_token(cx, state);
        let data = rest::body(cx, UPLOAD_LIMIT);
        rest::json(cx, 200, Upload { name: rest::param(cx, r, "name"), bytes: data.len });
    } else {
        rest::otherwise(cx, r);
    }
}
```

The scope ends in its own `rest::otherwise`, so `GET /uploads/logo.png` gets 405, as it
would from the router. The hand-written route calls `app::security_token` itself, the
same check the generated routes make.

Use a scope rather than a lone `http::on` before `dispatch`. `dispatch` doesn't see the
`Allow` that `http::on` collects, so with a lone `PUT /uploads/:name` route, a `GET` of
the same path falls through to `dispatch` and gets 404, not 405. A scope also shadows
any schema path under its prefix, so keep the two apart.

---

## 8. Middleware and scopes

Middleware is a function that takes a block, the routes it wraps. goose-rest has three,
and a program writes its own the same way. From
[`tutorial/08-middleware`](tutorial/08-middleware/main.goose):

```goose
fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            var r = http::router(cx.req);
            if http::on(r, "GET", "/health") {
                rest::text(cx, 200, "ok");
            } else if rest::scope(r, "/v1") {
                rest::route(cx) {
                    tenant(cx) { id => v1(cx, r, id); };
                };
            } else if rest::scope(r, "/admin") {
                rest::route(cx) {
                    rest::bearer(cx) { token =>
                        guard token == "secret" else { rest::invalid_token(cx); }
                        admin(cx, r);
                    };
                };
            } else {
                rest::otherwise(cx, r);
            }
        };
    };
}
```

- `rest::timed` adds `Server-Timing: app;dur=<ms>` to every answer and writes an access
  log line to standard error: `GET /v1/projects 200 182 0.012`.
- `rest::cors` adds the CORS fields to every answer inside it, errors included, answers
  a preflight with 204 itself, and refuses an origin it doesn't list with 403.
- `rest::bearer` gives its block the bearer token, or fails with 401 `unauthenticated`;
  the block refuses a wrong one with `rest::invalid_token`.

Where a middleware goes is how it applies. `/health` is public, every route under `/v1`
needs a tenant, and every route under `/admin` a token, checked before the route is
matched. A middleware that adds fields to every answer, as `timed` and `cors` do, goes
outside `rest::route`, so that the errors the route answers get the fields too. One that
fails, as `bearer` and `tenant` do, goes inside it. A request has one `rest::route`:
routes nested in routes keep each other out of line.

The program's own middleware is `tenant`:

```goose
inline fn tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Declare it `inline fn`. Goose inlines a plain function called once only up to a size, and
a block of routes passes that size at once, so a plain `fn` stays a call, and the
middleware around it stays out of line too. `inline fn` folds it into the handler, which
then compiles to one C function, each early answer a jump
([architecture](architecture/README.md#inlining)).

With a schema, middleware goes around `dispatch`, as `tutorial/06-schema` does with
`timed`:

```goose
    let e = rest::serve(cfg) { cx =>
        rest::timed(cx) { handle(cx, state); };
    };
```

The [reference](reference.md#middleware) has each middleware's options.

---

## 9. Large bodies

goose-http reads a request into a buffer of 8 KB by default, and a body that fits there
with its head comes to the handler whole. A longer body is gathered only when a route
asks for it, with `rest::body(cx, limit)`, or with `rest::take` of a JSON type, which
calls `rest::body` with its default of 1 MB. At that first call, the route leaves without
answering, `rest::serve` reads the body up to the limit, and then calls the handler
again with the body whole.

So the code before a route's first `rest::body` or `rest::take` runs twice for a long
body, and must not change state. A check there is fine: an answer there, such as a 401,
ends the request without reading the body. `uploads` in
[section 7](#7-generated-and-hand-written-routes) checks the token, then reads the body:

```goose
        app::security_token(cx, state);
        let data = rest::body(cx, UPLOAD_LIMIT);
```

Three limits apply, and the smallest wins:

| Limit | Set by | Past it |
|---|---|---|
| A route's | its first `rest::body(cx, limit)`, 1 MB without one | 413 `{"error":"payload_too_large"}` |
| A generated route's | `x-body-limit` on its `requestBody`, in bytes | the same |
| The server's | `http::Config`'s `max_body`, 1 MB by default | goose-http's 413, without a body, before any route runs |

`createProject` takes up to 16 KB, by its `x-body-limit`, and the uploads up to 2 MB, so
`main` raises the server's limit to the larger of the two. `api::MAX_BODY` is the
largest `x-body-limit` in the schema, or 1 MB:

```goose
let UPLOAD_LIMIT: i64 = 2 * 1024 * 1024;
```

```goose
    let cfg = http::Config { port: port as i32, workers: 1, max_body: max(api::MAX_BODY, UPLOAD_LIMIT), .. };
```

```text
POST /v1/projects 201 {"id":2,"name":"big","owner":"ada"}          a 12 KB body, gathered
POST /v1/projects 413 {"error":"payload_too_large"}                a 20 KB body
PUT /uploads/logo.png 200 {"name":"logo.png","bytes":1500000}
PUT /uploads/logo.png 413                                          3 MB, past max_body
```

A body whose `Content-Length` is over the limit is refused before it's sent, and a
chunked one once it passes the limit. The first call's limit holds for the request, so a
route that takes a JSON body over 1 MB calls `rest::body` with its limit before
`rest::take`, as a generated route does for its `x-body-limit`.

---

## 10. State

Workers share nothing, so state lives in one of three places.

**Per worker.** The worker's `thread_fn` owns it as locals, and the handler gets a
struct of references to them, as Actix's `web::Data` but without the `Arc`. From
`tutorial/06-schema`:

```goose
struct App { projects: api::Project[>..]&, token: const u8[:] }
```

```goose
thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var state = app::App { projects: projects, token: "secret" };
```

Each worker has its own `projects`, so a project created on one worker isn't on another.
The tutorial's programs that keep projects run one worker for that reason. A cache or a
rate limiter is fine per worker; data every worker must see goes on a thread of its own,
below.

**Per request.** `rest::serve(cfg, fresh)` gives each request `cx.state`, a fresh copy
of `fresh`. Its type picks the error shape ([section 4](#4-answers-and-errors)), and a
`rest::Once<T>` field in it computes a value on its first use in a request. From
[`tutorial/10-state`](tutorial/10-state/main.goose):

```goose
struct User { name: u8[..64] }

// The per-request state, which starts from St { .. } for each request.
struct St { user: rest::Once<User> }

// The per-worker state, which lasts as long as the worker.
struct App { lookups: i64 }

// The request's user, looked up on the first call in a request.
fn user(cx, app: App&) -> User& {
    return rest::once(cx.state.user) { lookup(cx, app) };
}
```

```goose
        rest::route(cx) {
            guard user(cx, app).name != "mallory" else { rest::fail(cx, 403, "forbidden"); }
            rest::text(cx, 200, str(user(cx, app).name, ", lookups so far: ", app.lookups));
        };
```

The route calls `user` twice, and `lookup` runs once:

```text
GET /me 200 ada, lookups so far: 1
GET /me 200 grace, lookups so far: 2
```

**On another thread.** A database connection, or anything every worker shares, lives on
a thread of its own, and a route asks it with `rest::ask`. Goose has no `async`, and
can't keep a closure to call later, so the route keeps what it needs in a variant of the
program's `Waiting` enum, in the per-request state, and returns. When the reply comes,
the handler runs again, and resumes through a function per variant. From
[`examples/waiting`](../examples/waiting/main.goose):

```goose
enum Waiting {
    None,
    Report { org: i64, from: i64, to: i64 },
    Export,
}

// The per-request state: rest::ask keeps the route's Waiting here.
struct St { waiting: Waiting = Waiting.None }
```

```goose
        rest::ask(cx, db, REPORT, ReportJob { org: org, from: from, to: to },
                  Waiting.Report { org: org, from: from, to: to });
```

```goose
fn resume(w: Waiting.Report, cx) {
    let rep, ok = rest::reply_value<ReportReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    var body: u8[>..] = [];
    format(body, "{\"org\":", w.org, ",\"from\":", w.from, ",\"to\":", w.to, ",\"days\":", rep.days,
           ",\"total\":", rep.total, "}");
    http::respond(cx.out, 200, "application/json", body);
}
```

```goose
    let e = rest::serve(cfg, St { .. }) { cx =>
        if rest::woken(cx) {
            rest::route(cx) { resume(cx.state.waiting, cx); };
        } else {
            handle(cx, db);
        }
    };
```

The compiler checks that every variant has its `resume`. The other thread takes jobs
with `rest::asked<J>` and replies with `rest::answer` or `rest::answer_value`. A reply
longer than a mailbox message comes in pieces, which `rest::relay` sends on as a chunked
response. `waiting.goose`'s header and the example have the whole API, including the
`http::Config` fields a waiting route needs (`mail_slots`, `mail_size`, `max_waiting`).
An answer written when a route resumes gets neither `timed`'s nor `cors`'s fields.

---

## 11. The schema in TypeScript, Python, or Rust

`api.json` is plain OpenAPI 3.1, and any tool that writes OpenAPI can write it, as long
as it stays inside the [subset](generator.md#the-subset) the generator reads.

goose-rest's own helper is [`ts/api.mts`](../ts/api.mts): TypeScript types that
describe only that subset. A file passes the document to `api()`, and `tsc` refuses a
keyword or a shape the generator doesn't read while you type it, with comments and
shared constants that JSON lacks. [`tutorial/06-schema/api.mts`](tutorial/06-schema/api.mts)
writes the same `api.json` as above:

```ts
import { api, json } from "../../../ts/api.mts";

// A project's name, the same in what a client sends and what it gets back.
const name = { type: "string", minLength: 1, maxLength: 64 } as const;
```

```ts
      ProjectCreate: {
        type: "object",
        required: ["name"],
        additionalProperties: false,
        properties: { name },
      },
```

```sh
node docs/tutorial/06-schema/api.mts > docs/tutorial/06-schema/api.json   # Node 22.18+, or bun
```

A `pattern`, which the generator doesn't support yet, fails at `tsc`, before the
generator runs:

```text
error TS2322: Type '"^[a-z]+$"' is not assignable to type '"pattern isn't supported on a string"'.
```

`tsc` also refuses a `$ref` to a missing component, a `required` name that isn't a
property, and a path parameter its template doesn't name. The generator still checks
what types can't: cycles, names, and number ranges. `scripts/test.sh` type-checks this
file with `ts/`, and checks that it prints the committed `api.json`, where `tsc` is
installed ([development.md](development.md#run-the-typescript-helpers-tests)).

A schema can also come from Python or Rust. pydantic models, or a FastAPI app, export
OpenAPI with their `$ref`s under `#/components/schemas`, and the generator reads the
`anyOf` with `null` that pydantic and schemars write for an optional value
([generator reference](generator.md#export-it-from-python-or-rust)). A backend in
another language and a Goose one can then share one contract.

---

## 12. Testing without sockets

A handler is a function of a `rest::Cx`, so a test can build one from a request's bytes,
call the handler, and compare what it wrote, with no server and no threads. Such a test
runs in-process through TinyCC, `goose test.goose`. From
[`tutorial/06-schema/test.goose`](tutorial/06-schema/test.goose):

```goose
fn answer(state: app::App&, text: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let req, status = http::parse(text);
    assert(status == 200);
    var keep = true;
    var stream = http::Stream { .. };
    var none = rest::NoState { .. };
    var scratch: u8[>..] = [];
    var cx = rest::Cx<rest::NoState> {
        req: req, body: text[req.len..],
        out: http::Reply { buf: out, common: "", keep_alive: keep, minor: 1, head: false, stream: stream },
        state: none, scratch: scratch,
    };
    api::dispatch(cx, state);
    return out;
}
```

```goose
    expect(body_of(answer(state, post("", "{\"name\": \"goose\"}"))), "{\"error\":\"unauthenticated\"}");
    expect(body_of(answer(state, post("Authorization: Bearer secret\r\n", "{\"name\": \"goose\"}"))),
           "{\"id\":1,\"name\":\"goose\",\"owner\":\"ada\"}");
```

The test imports `api_gen.goose` and `app.goose` as `main.goose` does, so it can't import
`main.goose` itself: keep the handlers out of the file with `main`. The answer is the
whole response, so a test can compare the status line and fields too. `http::parse`
refuses an HTTP/1.1 request without `Host`. A body larger than the read buffer isn't
gathered here: `cx` has no gathering, so `rest::body` takes the body as given.
[`test/test_router.goose`](../test/test_router.goose) uses the same harness to check the
generated router against an `if` chain of the same 60 routes.

For the whole server, the tutorial's programs and the examples follow one pattern: a
`requests.sh` lists requests as `req METHOD PATH [curl options]`, and
`scripts/test-examples.sh` builds the program, starts it on a local port, runs the
requests with `curl`, and compares `METHOD PATH STATUS BODY` lines with `expected.txt`.
From `tutorial/06-schema/requests.sh`:

```sh
req POST /v1/projects -H "$auth" -H "$json" -d '{"name": "goose"}'
req GET '/v1/projects?limit=0'
```

```text
POST /v1/projects 201 {"id":1,"name":"goose","owner":"ada"}
GET /v1/projects?limit=0 400 {"error":"invalid_parameter","detail":"limit: minimum"}
```

The script takes the directories to test, so `scripts/test-examples.sh docs/tutorial/06-schema`
runs one.

---

## 13. On a board

goose-rest is Goose with no C of its own, so a program cross-builds for an embedded Linux
board as goose-http's do, with `goose build --cc` and the board's C cross compiler.
goose-http's [docs/embedded.md](https://github.com/kaitk/goose-http/blob/main/docs/embedded.md)
covers distribution cross compilers, Yocto SDKs, what the board needs, and the checks to
run on it.

[`examples/device`](../examples/device/) is a board's API from a schema: temperature and
uptime from sysfs and `/proc`, settings whose bounds the schema checks and that set an
LED's brightness through sysfs, a firmware upload, a bearer token on writes, CORS, and a
page. It runs on one worker with small limits:

```goose
    let cfg = http::Config {
        port: port as i32, workers: 1, max_body: api::MAX_BODY,
        max_conns: 64, ring_entries: 256, ring_buffers: 64, ..
    };
```

The environment names the hardware (`THERMAL`, `LED`, `UPTIME`), so the example also runs
on a laptop, and its test fakes sysfs in files. `scripts/test-aarch64.sh` cross-builds
every example for aarch64 in an amd64 container and runs their checks in an arm64 one,
printing each one's peak RSS:

```sh
GOOSE_SRC=../goose GOOSE_HTTP=../goose-http scripts/test-aarch64.sh
```

There, `examples/device` peaked at 4,728 kB on one worker (task 013 has how it was
measured). None has run on a board yet. [development.md](development.md#run-the-examples-on-arm64)
covers the setup.

---

## 14. Where to go next

- **[`reference.md`](reference.md)**: every middleware, extractor, and error code.
- **[`generator.md`](generator.md)**: what the generator reads, what it writes, what it
  refuses, and how the router matches.
- **[`examples/`](../examples/)**: complete programs, without a schema (`plain`), from
  one (`schema`, `device`), and waiting on another thread (`waiting`).
- **[`architecture/README.md`](architecture/README.md)**: why goose-rest is shaped this
  way, from Actix and Elysia, and where Goose made it differ.
- **[`development.md`](development.md)**: the toolchain, the tests, and the benchmarks.
- **[`goose-findings.md`](goose-findings.md)**: Goose compiler and stdlib gaps found
  here, and their workarounds.

Clients come from the same `api.json`: standard OpenAPI tools, such as
[OpenAPI Generator](https://openapi-generator.tech/), write a Python or C client from
it, or one in most other languages, so the contract the server is generated from is
also the client's.
