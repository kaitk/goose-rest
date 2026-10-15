# 7. Middleware and scopes

Middleware is a function that takes a block, the routes it wraps. goose-rest has three,
and a program writes its own the same way. From
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
- `rest::cors` adds the CORS fields to every answer inside it, errors included, answers
  a preflight with 204 itself, and refuses an origin it doesn't list with 403.
- `rest::bearer` gives its block the bearer token, or fails with 401 `unauthenticated`;
  the block refuses a wrong one with `rest::invalid_token`.

## Where a middleware goes

Where a middleware goes is how it applies. `/health` is public, every route under `/v1`
needs a tenant, and every route under `/admin` a token, checked before the route is
matched. A middleware that adds fields to every answer, as `timed` and `cors` do, goes
outside `rest::route`, so that the errors the route answers get the fields too. One that
fails, as `bearer` and `tenant` do, goes inside it. A request has one `rest::route`:
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

Declare it `inline fn`. Goose inlines a plain function called once only up to a size, and
a block of routes passes that size at once, so a plain `fn` stays a call, and the
middleware around it stays out of line too. `inline fn` folds it into the handler, which
then compiles to one C function, each early answer a jump
([architecture](../architecture/README.md#inlining)).

With a schema, middleware goes around `dispatch`, as [`05-schema`](05-schema/main.goose)
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
