# 2. Routes, path, query, and headers

A request names its route by method and path, and carries what the route needs in the
path, the query string, and the headers. goose-rest has no table of handlers: routes are
an `if` chain, and a route reads each part of the request with a call where it needs
the value.

## Matching a route

Routes go in a `rest::routes` block, whose context holds the router for the request.
Each route uses `rest::on` with a method and a pattern: literal segments, `:name` for one
segment, and `*name` at the end for the rest of the path. Patterns match the path without
the query string, so `/v1/projects` matches `/v1/projects?q=g`. `GET` routes also accept
`HEAD`. At the end of the chain, `rest::otherwise` answers 405 with `Allow` when another
method's route has the path, 404 when none has, and `OPTIONS` itself.

`rest::scope` removes a prefix from the path, so the routes inside it match the rest. From
[`02-routes`](02-routes/main.goose):

```rust
fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/v1") {
            rest::route(cx) { v1(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}
```

## Reading the request

Each extractor reads one part of the request: `rest::param` and `rest::param_int` read a
path parameter; `rest::query`, `rest::query_int`, and `rest::query_bool` read a query string
parameter; `rest::header` reads a header field; and `rest::cookie` reads a cookie. These
are plain calls, not handler arguments as in Actix or Axum:

```rust
fn v1(cx) {
    if rest::on(cx, "GET", "/projects") {
        let q, has_q = rest::query(cx, "q");
        let archived, has_archived = rest::query_bool(cx, "archived");
        let limit, has_limit = rest::query_int(cx, "limit");
        rest::json(cx, 200, Listing { q: q, archived: archived, limit: if has_limit { limit } else { 10 } });
    } else if rest::on(cx, "GET", "/projects/:id") {
        rest::json(cx, 200, find_project(cx, rest::param_int(cx, "id")));
    } else if rest::on(cx, "GET", "/me") {
        let user, has_user = rest::header(cx, "X-User");
        rest::require(cx, "X-User", has_user);
        let theme, has_theme = rest::cookie(cx, "theme");
        rest::text(cx, 200, str(user, " likes ", if has_theme { theme } else { "light" }));
    } else {
        rest::otherwise(cx);
    }
}
```

An optional value comes with a `bool` that says whether the request has it.
A value that doesn't parse fails the route with 400. `rest::require` fails it too when the
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
[reference](../reference.md#extractors) lists every extractor and the errors it can return.

---

[Index](README.md) · Previous: [1. Running something](01-running.md) · Next:
[3. Answers and errors](03-errors.md)
