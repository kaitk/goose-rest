# 8. State

Workers share nothing, so state lives in one of three places: the worker, the request,
or a thread of its own
([goose-http's state that workers share](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#state-that-workers-share)).

## Per worker

The worker's `thread_fn` owns it as locals, and `rest::serve(cfg, app)` gives every
request `cx.app`, a reference to a struct of references to them, as Actix's `web::Data`
but without the `Arc`. From [`05-schema`](05-schema/main.goose):

```rust
struct App { projects: api::Project[>..]&, token: const u8[:] }
```

```rust
thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var app = app::App { projects: projects, token: "secret" };
    let e = rest::serve(cfg, app) { cx =>
```

Each worker has its own `projects`, so a project created on one worker isn't on another.
The tutorial's programs that keep projects run one worker for that reason. A cache or a
rate limiter is fine per worker; data every worker must see goes on a thread of its own,
below.

## Per request

`rest::serve(cfg, app, fresh)` gives each request `cx.state`, a fresh copy of `fresh`.
Its type picks the error shape ([Answers and errors](03-errors.md#errors)), and a
`rest::Once<T>` field in it computes a value on its first use in a request. From
[`08-state`](08-state/main.goose):

```rust
struct User { name: u8[..64] }

// The per-request state, which starts from St { .. } for each request.
struct St { user: rest::Once<User> }

// The per-worker state, which lasts as long as the worker.
struct App { lookups: i64 }

type Cx = rest::Cx<St, App, http::Router>;

// The request's user, looked up on the first call in a request.
fn user(cx: Cx&) -> User& {
    return rest::once(cx.state.user) { lookup(cx) };
}
```

```rust
            rest::route(cx) {
                guard user(cx).name != "mallory" else { rest::fail(cx, 403, "forbidden"); }
                rest::text(cx, 200, str(user(cx).name, ", lookups so far: ", cx.app.lookups));
            };
```

The alias types a route's context: `St` is the request's state, `App` is the worker's,
and `http::Router` is the router supplied by `rest::routes`. Outside that block the
context has `rest::NoRouter`, so it cannot be passed to `user`. A generic helper can
leave its context parameter untyped, as the other examples do.

The route calls `user` twice, and `lookup` runs once:

```text
GET /me 200 ada, lookups so far: 1
GET /me 200 grace, lookups so far: 2
```

## On another thread

A database connection, or anything else every worker shares, lives on a thread of its
own, which workers ask by message. A route asks it with `rest::ask`, and resumes when
the reply comes: [Work that waits](13-waiting.md).

---

[Index](README.md) · Previous: [7. Middleware and scopes](07-middleware.md) · Next:
[9. Testing without sockets](09-testing.md)
