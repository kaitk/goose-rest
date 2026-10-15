# 5. The API from a schema

With `paths`, the generator also writes the router, `api::dispatch(cx)`, and the
program writes the handlers it calls. [`05-schema`](05-schema/) has three files besides
the schema: `api_gen.goose`, generated; `app.goose`, the handlers; and `main.goose`, the
workers. Here are the paths from its `api.json`:

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

## Handlers

Each operation calls a handler in the `app` namespace, named after its `operationId` in
snake_case: `listProjects` calls `app::list_projects`. A handler's arguments come in this
order:

1. `cx`, whose `cx.app` is the worker's state, whatever the program gave `rest::serve`.
2. The security check's result, when the operation names a scheme.
3. The path parameters, in the template's order, typed: an `integer` is an `i64`.
4. A struct of the query, header, and cookie parameters, `<OperationId>Params`.
5. The body, as the `$ref`'s type.

So the handlers in [`app.goose`](05-schema/app.goose) are:

```rust
fn health(cx) { rest::text(cx, 200, "ok"); }

fn list_projects(cx, q: api::ListProjectsParams) {
    rest::json(cx, 200, Listing { app: cx.app, q: if q.has_q { q.q } else { "" }, limit: if q.has_limit { q.limit } else { 20 } });
}

fn create_project(cx, user: const u8[:], body: const api::ProjectCreate&) {
    let p .= cx.app.projects.push(api::Project { id: cx.app.projects.len + 1, name: body.name, owner: user });
    rest::json(cx, 201, p);
}

fn get_project(cx, id: i64) {
    guard id <= cx.app.projects.len else { rest::fail(cx, 404, "project_not_found"); }
    rest::json(cx, 200, cx.app.projects[id - 1]);
}
```

`get_project` doesn't check that `id` is at least 1: the router has, from the schema's
`minimum`, and answered `400 {"error":"invalid_parameter","detail":"id: minimum"}`
without calling it. The parameters struct holds each optional parameter after a
`has_` flag:

```rust
struct ListProjectsParams {
    has_q: bool,
    q: const u8[:],
    has_limit: bool,
    limit: i64,
}
```

A scheme in `security` calls `app::security_<scheme>(cx)` before the handler, and the
handler gets what it returns. Here the `token` scheme checks a bearer token and returns
the user it belongs to:

```rust
fn security_token(cx) -> const u8[:] {
    guard rest::bearer_token(cx) == cx.app.token else { rest::invalid_token(cx); }
    return "ada";
}
```

## When the schema and the handlers disagree

The router calls the handlers by name, with their types, so the schema and the handlers
can't drift apart unnoticed. Delete `get_project`, and the build stops:

```text
api_gen.goose:259: error: unknown function: app::get_project
                                            app::get_project(cx, id);
  in fn rest::attempt<F = {block at api_gen.goose:256:57}>() instantiated from .../runtime.goose:252
  in fn rest::route<F = {block at api_gen.goose:256:57}>(rest::Cx<rest::NoState, app::App, http::Router>&) instantiated from api_gen.goose:256
  in fn api::dispatch(rest::Cx<rest::NoState, app::App, http::Router>&) instantiated from main.goose:32
  ...
```

Declare its `id` as a string instead, and it stops with
`argument 2: cannot pass i64 as const u8[:]`. Read the chain from the top: the line in
`api_gen.goose` names the call, and the operation is the one around it. The chain goes
on for 15 more frames, through `rest::serve` and goose-http's event loop, because Goose
lists every generic function between the error and `main`
([Goose findings](../goose-findings.md#an-error-inside-a-generic-function-lists-every-frame-up-to-main)).

The workflow, then, is: change `api.json`, regenerate `api_gen.goose`, and let the
compiler list the handlers to add or change. This repository commits both files, so
that a schema change shows in review as a diff of the code it makes. A program can do
the same, and then builds without the generator, or generate `api_gen.goose` in its
build ([architecture](../architecture/README.md#with-a-schema)).

The router itself is a `match` on the path's length for the static paths, then a walk
segment by segment, literals before parameters. Its answers are the `if` chain's,
byte for byte, except that a typed parameter is checked and a literal path wins over a
template that also matches ([generator reference](../generator.md#how-it-matches)).

## Generated and hand-written routes

`dispatch` answers every request it's given, with 404 for a path the schema doesn't
have. A route the schema can't describe, such as one whose body isn't JSON, goes
before it, in the same `rest::routes` block. From
[`05-schema/main.goose`](05-schema/main.goose):

```rust
fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "PUT", "/uploads/:name") {
            rest::route(cx) { upload(cx); };
        } else {
            api::dispatch(cx);
        }
    };
}

// An upload of any bytes, which a schema can't describe: its bodies are JSON.
fn upload(cx) {
    app::security_token(cx);
    let data = rest::body(cx, UPLOAD_LIMIT);
    rest::json(cx, 200, Upload { name: rest::param(cx, "name"), bytes: data.len });
}
```

`rest::on` adds the methods of the routes whose path matched to the router's `Allow`,
and `dispatch` answers with them: `GET /uploads/logo.png` gets 405 with `Allow: PUT`, and
`OPTIONS` 204 with it, as from one router. Where hand-written routes and the schema share
a path, the `Allow` lists the hand-written routes' methods, then the schema's, and a
hand-written route with a schema operation's method wins over it, since it comes first.
The hand-written route calls `app::security_token` itself, the same check the generated
routes make. How `rest::body` gathers a body past the read buffer, and its limits:
[Large bodies](10-large-bodies.md).

---

[Index](README.md) · Previous: [4. JSON bodies](04-json.md) · Next:
[6. The schema in TypeScript, Python, or Rust](06-schema-languages.md)
