# 5. The API from a schema

When the schema includes `paths`, the generator also writes the router,
`api::dispatch(cx)`. You write the handlers it calls. [`05-schema`](05-schema/) has
three files besides the schema: the generated `api_gen.goose`, `app.goose` with the
handlers, and `main.goose` with the workers. Here are the paths from its `api.json`:

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

1. `cx`, with `cx.app` referring to the worker state passed to `rest::serve`.
2. The security check's result, when the operation specifies a scheme.
3. Typed path parameters in template order: an `integer` becomes an `i64`.
4. A `<OperationId>Params` struct containing the query, header, and cookie parameters.
5. The body, using the type named by its `$ref`.

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

`get_project` doesn't check that `id` is at least 1: the router has already checked
the schema's `minimum`. If the check fails, the router answers
`400 {"error":"invalid_parameter","detail":"id: minimum"}` without calling the handler.
In the parameters struct, each optional parameter follows a `has_` flag:

```rust
struct ListProjectsParams {
    has_q: bool,
    q: const u8[:],
    has_limit: bool,
    limit: i64,
}
```

For a scheme listed in `security`, the router calls `app::security_<scheme>(cx)` before
the handler and passes the result to the handler. Here the `token` scheme checks a
bearer token and returns the user it belongs to:

```rust
fn security_token(cx) -> const u8[:] {
    guard rest::bearer_token(cx) == cx.app.token else { rest::invalid_token(cx); }
    return "ada";
}
```

## When the schema and the handlers disagree

The router makes typed calls to the handlers by name, so the schema and handlers can't
drift apart unnoticed. Delete `get_project`, and the build fails:

```text
api_gen.goose:259: error: unknown function: app::get_project
                                            app::get_project(cx, id);
  in fn rest::attempt<F = {block at api_gen.goose:256:57}>() instantiated from .../runtime.goose:252
  in fn rest::route<F = {block at api_gen.goose:256:57}>(rest::Cx<rest::NoState, app::App, http::Router>&) instantiated from api_gen.goose:256
  in fn api::dispatch(rest::Cx<rest::NoState, app::App, http::Router>&) instantiated from main.goose:32
  ...
```

Declare its `id` as a string instead, and the build fails with
`argument 2: cannot pass i64 as const u8[:]`. Read the chain from the top: the line in
`api_gen.goose` identifies the call within the generated code for that operation. The
chain continues for 15 more frames through `rest::serve` and goose-http's event loop,
because Goose lists every generic function between the error and `main`
([Goose findings](../goose-findings.md#an-error-inside-a-generic-function-lists-every-frame-up-to-main)).

The workflow is to change `api.json`, regenerate `api_gen.goose`, and let the compiler
list the handlers to add or change. This repository commits both files so reviewers
can see the generated code changes alongside the schema change. Your project can do
the same and build without the generator, or generate `api_gen.goose` during the build
([architecture](../architecture/README.md#with-a-schema)).

The router first uses a `match` on the path's length for static paths, then walks the
path segment by segment, checking literals before parameters. Its answers match
those of the `if` chain byte for byte, except that it validates typed parameters and
gives a literal path priority over a matching template
([generator reference](../generator.md#how-it-matches)).

## Generated and hand-written routes

`dispatch` answers every request it receives, returning 404 for paths absent from
the schema. Put routes the schema can't describe, such as those with non-JSON bodies,
before it in the same `rest::routes` block. From
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

`rest::on` adds the methods of routes with matching paths to the router's `Allow` list,
and `dispatch` answers with them: `GET /uploads/logo.png` gets 405 with
`Allow: PUT`, and `OPTIONS` gets 204 with the same header, just as with a single router.
When hand-written routes and the schema share a path, `Allow` lists the hand-written
routes' methods first, then the schema's. A hand-written route takes precedence over a
schema operation with the same method because it comes first. The hand-written route
calls `app::security_token` itself, performing the same check as the generated routes.
For how `rest::body` gathers a body larger than the read buffer, and the limits that
apply, see [Large bodies](10-large-bodies.md).

---

[Index](README.md) · Previous: [4. JSON bodies](04-json.md) · Next:
[6. The schema in TypeScript, Python, or Rust](06-schema-languages.md)
