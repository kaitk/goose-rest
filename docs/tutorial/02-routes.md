# 2. Routes, path, query, and headers

A request names its route by method and path, and carries what the route needs in the
path, the query string, and the headers. Plod has no table of handlers: routes are
calls in a row, and a route reads each part of the request with a call where it needs
the value.

## Matching a route

Routes go in a `plod::routes` block, whose context holds the router for the request.
Each route is `plod::get`, `plod::post`, `plod::put`, `plod::patch`, or `plod::delete`
with a pattern: literal segments, `:name` for one segment, and `*name` at the end for
the rest of the path. Patterns match the path without the query string, so
`/v1/projects` matches `/v1/projects?q=g`. `plod::get` also accepts `HEAD`. The first
route that matches takes the request and runs its block, and the routes after it don't
match. When no route answered, `plod::routes` answers 405 with `Allow` when another
method's route has the path, 404 when none has, and `OPTIONS` itself.

`plod::scope` is a block for the paths under a prefix: the routes inside it match the
rest of the path. The scope owns those paths, so it answers 404 and 405 for them itself,
and the routes after it don't match them. From [`02-routes`](02-routes/main.goose):

```rust
fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/v1") { v1(cx); };
    };
}
```

## Reading the request

Each extractor reads one part of the request: `plod::param` and `plod::param_int` read a
path parameter; `plod::query`, `plod::query_int`, and `plod::query_bool` read a query string
parameter; `plod::header` reads a header field; and `plod::cookie` reads a cookie. These
are plain calls, not handler arguments as in Actix or Axum:

```rust
fn v1(cx) {
    plod::get(cx, "/projects") {
        let q, has_q = plod::query(cx, "q");
        let archived, has_archived = plod::query_bool(cx, "archived");
        let limit, has_limit = plod::query_int(cx, "limit");
        plod::json(cx, 200, Listing { q: q, archived: archived, limit: if has_limit { limit } else { 10 } });
    };
    plod::get(cx, "/projects/:id") { plod::json(cx, 200, find_project(cx, plod::param_int(cx, "id"))); };
    plod::get(cx, "/me") {
        let user, has_user = plod::header(cx, "X-User");
        plod::require(cx, "X-User", has_user);
        let theme, has_theme = plod::cookie(cx, "theme");
        plod::text(cx, 200, str(user, " likes ", if has_theme { theme } else { "light" }));
    };
}
```

An optional value comes with a `bool` that says whether the request has it.
A value that doesn't parse fails the route with 400. `plod::require` fails it too when the
value is missing. Query values are percent-decoded, with `+` decoded as a space.
A repeated key gives its first value:

```text
GET /v1/projects?q=g&limit=1   200 [{"id":1,"name":"goose"}]
GET /v1/projects?archived=yes  400 {"error":"invalid_parameter","detail":"archived: boolean"}
GET /v1/projects/two           400 {"error":"invalid_parameter","detail":"id: integer"}
GET /v1/me                     400 {"error":"invalid_parameter","detail":"X-User: required"}
DELETE /v1/projects/2          405 {"error":"method_not_allowed"}
```

An extractor returns a slice of the request when nothing needs decoding, and otherwise
decodes into `cx.scratch`. Either way, the value stays valid until the handler returns,
so copy it if it must outlive the request. The
[reference](../reference.md#3-extractors) lists every extractor and the errors it can return.

---

[Index](README.md) · Previous: [1. Running something](01-running.md) · Next:
[3. Answers and errors](03-errors.md)
