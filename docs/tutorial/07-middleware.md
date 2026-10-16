# 7. Middleware and scopes

A middleware is a function that takes the routes it wraps as a block. goose-rest
has three, and you can write your own the same way. From
[`07-middleware`](07-middleware/main.goose):

```rust
fn handle(cx) {
    // Outside every route, so that its errors get the timing and CORS fields too.
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            // The routes, with the middleware that can fail inside each scope's route.
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    // Every route under /v1 needs a tenant.
                    rest::route(cx) {
                        resolve_tenant(cx) { tenant => v1(cx, tenant); };
                    };
                } else if rest::scope(cx, "/admin") {
                    // Every route under /admin needs the token.
                    rest::route(cx) {
                        rest::bearer(cx) { token =>
                            guard token == "secret" else { rest::invalid_token(cx); }
                            admin(cx);
                        };
                    };
                    ...
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}
```

- `rest::timed` adds `Server-Timing: app;dur=<ms>` to every answer and writes an access
  log line to standard error: `GET /v1/projects 200 182 0.012`.
- `rest::cors` adds CORS headers to every answer inside it, including errors. It
  answers preflight requests with 204 and rejects unlisted origins with 403.
- `rest::bearer` passes the bearer token to its block, or fails with 401
  `unauthenticated`. The block rejects an invalid token with `rest::invalid_token`.

## Where a middleware goes

Where a middleware sits decides which routes it applies to. `/health` is public; every
route under `/v1` requires a tenant, and every route under `/admin` requires a token.
These checks run before the route inside the scope is matched.

Middleware that adds
headers to every answer, such as `timed` and `cors`, goes outside `rest::route` so
the errors the route answers get the headers too. Middleware that can fail, such as
`bearer` and `resolve_tenant`, goes inside it. A request has one `rest::route`:
routes nested in routes keep each other out of line.

## A middleware of your own

The program's own middleware is `resolve_tenant`:

```rust
inline fn resolve_tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Declare it `inline fn`. Goose inlines a plain function called once only if it's below
a size limit, and a block of routes is over that limit at once, so a plain `fn` stays
a call and keeps the middleware around it out of line too. `inline fn` folds the middleware into the handler, which compiles to one
C function with a jump for each early answer
([architecture](../architecture.md#middleware-and-inlining)).

## A stack of your own

Each middleware adds a level around every scope's routes, written again at each scope.
A stack is an `inline fn` that nests the middleware and passes its own block on, so each
scope has one level however many middleware the stack holds. The program's
`member_routes` stack, for the routes a tenant's signed-in members use, holds the
route, the token check, and `resolve_tenant`:

```rust
inline fn member_routes<F>(cx) {
    rest::route(cx) {
        rest::bearer(cx) { token =>
            guard token == "secret" else { rest::invalid_token(cx); }
            resolve_tenant(cx) { tenant => F(tenant); };
        };
    };
}
```

A scope uses it as one level:

```rust
                } else if rest::scope(cx, "/v2") {
                    // The token and a tenant, as the member_routes stack.
                    member_routes(cx) { tenant => v1(cx, tenant); };
```

The call compiles to the same code as the nesting written out, one C function with a
jump for each early answer. A stack can call another stack, and a block can take an
argument, as `F(tenant)` does.

A stack is code, not a value. A block is a compile-time argument, so a program can't
build a list of middleware at run time, as Actix's `wrap` or Tower's `Layer` does.

How to name stacks and middleware, and how many stacks to write, is in
[Middleware and stacks](../best-practices/middleware.md): a stack per audience, such
as `member_routes`, and a middleware named by a verb.
[Concepts and naming](../best-practices/concepts.md) has the rest of an application's
names.

A stack keeps the rules of the nesting it replaces, given above: each middleware on its
side of `rest::route`, one `rest::route` per request, and an `inline fn`, never a plain
`fn`. It also makes clear whether it opens the request's route, as `member_routes`
does, and code inside that route opens no other.

## Middleware with a schema

With a schema, wrap `dispatch` in middleware, as [`05-schema`](05-schema/main.goose)
does with `timed`:

```rust
    let e = rest::serve(cfg, app) { cx =>
        rest::timed(cx) { handle(cx); };
    };
```

The [reference](../reference.md#middleware) has each middleware's options.

---

[Index](README.md) · Previous: [6. The schema in TypeScript, Python, or Rust](06-schema-languages.md)
· Next: [8. State](08-state.md)
