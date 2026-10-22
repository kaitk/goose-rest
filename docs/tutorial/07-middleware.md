# 7. Middleware and scopes

A middleware is a function that takes the routes it wraps as a block. Plod
has three, and you can write your own the same way. From
[`07-middleware`](07-middleware/main.goose):

```rust
fn handle(cx) {
    // Around every route, so that every answer gets the timing and CORS fields.
    plod::timed(cx) {
        plod::cors(cx, plod::Cors { origins: "https://app.example", .. }) {
            // The routes, with the middleware that can fail inside each scope.
            plod::routes(cx) { cx =>
                plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
                plod::scope(cx, "/v1") {
                    // Every route under /v1 needs a tenant.
                    resolve_tenant(cx) { tenant => v1(cx, tenant); };
                };
                plod::scope(cx, "/admin") {
                    // Every route under /admin needs the token.
                    plod::bearer(cx) { token =>
                        guard token == "secret" else { plod::invalid_token(cx); }
                        admin(cx);
                    };
                };
                ...
            };
        };
    };
}
```

- `plod::timed` adds `Server-Timing: app;dur=<ms>` to every answer and writes an access
  log line to standard error: `GET /v1/projects 200 182 0.012`.
- `plod::cors` adds CORS headers to every answer inside it, including errors. It
  answers preflight requests with 204 and rejects unlisted origins with 403.
- `plod::bearer` passes the bearer token to its block, or fails with 401
  `unauthenticated`. The block rejects an invalid token with `plod::invalid_token`.

## Where a middleware goes

Where a middleware sits decides which routes it applies to. `/health` is public; every
route under `/v1` requires a tenant, and every route under `/admin` requires a token.
These checks run before the route inside the scope is matched.

Middleware that adds headers to answers, such as `timed` and `cors`, works on either
side of `plod::routes`. Around it, as here, every answer gets the headers. Inside a
scope, the scope's answers get them, its errors and its 404s and 405s included. Inside
`plod::routes`, such middleware answers every request that reaches it, so it goes in a
scope, not around one route among others.
[`examples/compress`](../../examples/compress/main.goose) compresses two scopes with
options of their own:

```rust
            plod::scope(cx, "/v1") { plod::compressed(cx) { cx => events(cx); }; };
            plod::scope(cx, "/archive") { plod::compressed(cx, ARCHIVE) { cx => events(cx); }; };
```

Middleware that can fail, such as `bearer` and `resolve_tenant`, goes inside
`plod::routes`. A request has one route, the one `plod::routes` opens: routes nested in
routes keep each other out of line, so a `plod::route` inside `plod::routes` joins its
route rather than opening another.

A route that matches takes the request and runs its block, which returns as any block
does, so the code after a route runs. A middleware around it does its work after its
block, as `timed` writes its log line, and the routes after it see the request taken
and don't match.

## A middleware of your own

The program's own middleware is `resolve_tenant`:

```rust
inline fn resolve_tenant<F>(cx) {
    let id, has = plod::header(cx, "X-Tenant");
    guard has else { plod::fail(cx, 400, "tenant_required"); }
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
token check and `resolve_tenant`:

```rust
inline fn member_routes<F>(cx) {
    plod::bearer(cx) { token =>
        guard token == "secret" else { plod::invalid_token(cx); }
        resolve_tenant(cx) { tenant => F(tenant); };
    };
}
```

A scope uses it as one level:

```rust
                plod::scope(cx, "/v2") {
                    // The token and a tenant, as the member_routes stack.
                    member_routes(cx) { tenant => v1(cx, tenant); };
                };
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

A stack keeps the rules of the nesting it replaces, given above: one that can fail
goes inside `plod::routes`, as `member_routes` does, and it's an `inline fn`, never a
plain `fn`.

A middleware of your own that works after its block, such as an audit log, or that
adds fields to answers, runs its block in `plod::scoped`. Inside `plod::routes`, that
answers a failure and a 404 inside the middleware, before the middleware's own work
after the block; outside, it only runs the block
([reference](../reference.md#2-middleware)).

## Middleware with a schema

With a schema, wrap `dispatch` in middleware, as [`05-schema`](05-schema/main.goose)
does with `timed`:

```rust
    let e = plod::serve(cfg, app) { cx =>
        plod::timed(cx) { handle(cx); };
    };
```

The [reference](../reference.md#2-middleware) has each middleware's options.

---

[Index](README.md) · Previous: [6. The schema in TypeScript, Python, or Rust](06-schema-languages.md)
· Next: [8. State](08-state.md)
