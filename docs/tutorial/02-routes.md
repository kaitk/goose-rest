# 2. Routes, path, query, and headers

Routes go in a `rest::routes` block, whose context holds a router over the request, and
each route is a `rest::on` with a method and a pattern: literal segments, `:name` for one
segment, and `*name`, last, for the rest of the path. A pattern matches the path without
the query string, so `/v1/projects` takes `/v1/projects?q=g`. `GET` routes take `HEAD`
too. A route that matches the path with another method adds the method to the router's
`Allow`, so `rest::otherwise`, at the end of the chain, answers 405 with `Allow` where
the path exists, 404 where it doesn't, and OPTIONS itself.

`rest::scope` takes a prefix off the path, so the routes inside it match the rest. From
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

Extractors read one part of the request each: `rest::param` and `rest::param_int` a path
parameter, `rest::query`, `rest::query_int`, and `rest::query_bool` a query string
parameter, `rest::header` a header field, and `rest::cookie` a cookie. They are plain
calls, made where the handler needs the value, rather than handler arguments as in Actix
or Axum:

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

An optional value comes with a `bool` that says whether the request has it, and a value
that doesn't parse fails the route with 400. `rest::require` turns a missing one into a
failure too. A query value is percent-decoded, with `+` as a space, and a repeated key
gives its first value:

```text
GET /v1/projects?q=g&limit=1   200 [{"id":1,"name":"goose"}]
GET /v1/projects?archived=yes  400 {"error":"invalid_parameter","detail":"archived: boolean"}
GET /v1/projects/two           400 {"error":"invalid_parameter","detail":"id: integer"}
GET /v1/me                     400 {"error":"invalid_parameter","detail":"X-User: required"}
DELETE /v1/projects/2          405 {"error":"method_not_allowed"}
```

An extractor returns a slice of the request where there is nothing to decode, and
otherwise decodes into `cx.scratch`. Either lasts until the handler returns, so a
value is used in the request and copied if it must outlive it. The
[reference](../reference.md#extractors) lists every extractor and what it fails with.

---

[Index](README.md) · Previous: [1. Running something](01-running.md) · Next:
[3. Answers and errors](03-errors.md)
