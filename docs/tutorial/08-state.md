# 8. State

Workers share nothing, so data lives in one of five places, each with a name of its
own:

- a *constant*, a global with a literal value, compiled into the program;
- the *store*, goose-http's `http.store`, loaded once at startup and read by every
  worker;
- *worker state*, `cx.app`, which each worker keeps for itself;
- *request state*, `cx.state`, which each request starts afresh;
- *lane data*, owned by a thread of its own, a lane, which workers ask.

This page shows worker state, request state, and how to access the store and a lane.
The Best practices guide explains where to keep each kind of data in
[State](../best-practices/state.md#choose-the-place-by-what-the-data-is).

## Worker state

The worker's `thread_fn` owns its state in local variables. `rest::serve(cfg, app)`
gives each request `cx.app`, a reference to a struct containing references to those
variables. This serves the role of Actix's `web::Data`, but without the `Arc`. From
[`05-schema`](05-schema/main.goose):

```rust
struct App { projects: api::Project[>..]&, token: const u8[:] }
```

```rust
thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var app = app::App { projects: projects, token: "secret" };
    let e = rest::serve(cfg, app) { cx =>
```

Each worker has its own `projects`, so a project created on one worker isn't available
on another. For that reason, tutorial programs that store projects use one worker. A
cache or rate limiter can be worker state; data that every worker must see is lane
data, as described below.

Data that every worker only reads, such as a catalog loaded at startup, is the
exception: don't load it into globals in `main` before the workers start, because each
worker then holds it more than once. The store, `import http.store`, keeps one copy that every worker reads
([goose-http's state that workers share](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#state-that-workers-share)).

To keep many records in memory, hold their strings as ranges into one byte array, not
in fixed-capacity fields such as `u8[..48]`. A limited array always takes its full
capacity, so a 6-byte name in a `u8[..48]` field takes 48 bytes. A generated type's
string with a `maxLength` is such a field, four bytes per code point
([generator](../generator.md#the-subset)). Where every value is ASCII, as in a code or
an identifier, `format: ascii` sizes it at one byte per code point
([JSON bodies](04-json.md#size-a-string-in-bytes)).

## Request state

`rest::serve(cfg, app, fresh)` gives each request `cx.state`, a fresh copy of `fresh`.
The state type determines the error format ([Answers and errors](03-errors.md#errors)).
A `rest::Once<T>` field computes a value on its first use within the request. From
[`08-state`](08-state/main.goose):

```rust
struct User { name: u8[..64] }

// The request state, which starts from St { .. } for each request.
struct St { user: rest::Once<User> }

// The worker state, which lasts as long as the worker.
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

The alias defines the route's context type: `St` is the request state, `App` is the
worker state, and `http::Router` is the router supplied by `rest::routes`. Outside that
block, the context has `rest::NoRouter`, so it cannot be passed to `user`. A generic
helper can leave its context parameter untyped, as the other examples do.

The route calls `user` twice, and `lookup` runs once:

```text
GET /me 200 ada, lookups so far: 1
GET /me 200 grace, lookups so far: 2
```

## Lane data

A database connection, or other data that every worker uses and changes, belongs to a
lane, a thread of its own. Workers send it jobs by mail. A route uses `rest::ask` and
resumes when the reply arrives: [Work that waits](11-waiting.md).

---

[Index](README.md) · Previous: [7. Middleware and scopes](07-middleware.md) · Next:
[9. Testing without sockets](09-testing.md)
