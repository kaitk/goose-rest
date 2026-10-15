# 7. Middleware and scopes

A middleware function takes a block containing the routes it wraps. goose-rest
provides three middleware functions, and you can write your own the same way. From
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
                        tenant(cx) { id => v1(cx, id); };
                    };
                } else if rest::scope(cx, "/admin") {
                    // Every route under /admin needs the token.
                    rest::route(cx) {
                        rest::bearer(cx) { token =>
                            guard token == "secret" else { rest::invalid_token(cx); }
                            admin(cx);
                        };
                    };
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

Placement determines which routes middleware applies to. `/health` is public; every
route under `/v1` requires a tenant, and every route under `/admin` requires a token.
These checks run before matching the route within the scope. Middleware that adds
headers to every answer, such as `timed` and `cors`, goes outside `rest::route` so
the errors the route answers get the headers too. Middleware that can fail, such as
`bearer` and `tenant`, goes inside it. A request has one `rest::route`:
routes nested in routes keep each other out of line.

## A middleware of your own

The program's own middleware is `tenant`:

```rust
inline fn tenant<F>(cx) {
    let id, has = rest::header(cx, "X-Tenant");
    guard has else { rest::fail(cx, 400, "tenant_required"); }
    F(id);
}
```

Declare it `inline fn`. Goose inlines a plain function called once only if it is below
a size threshold. A block of routes immediately exceeds that threshold, so a plain
`fn` remains a function call and prevents the surrounding middleware from being
inlined too. `inline fn` folds the middleware into the handler, which compiles to one
C function with a jump for each early answer
([architecture](../architecture/README.md#inlining)).

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
