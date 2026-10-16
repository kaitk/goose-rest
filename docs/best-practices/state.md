# State

Workers share nothing, so where a piece of data lives decides who sees it and what it
costs. [State](../tutorial/08-state.md) shows each place; this page says which to use.

The code on this page is from [`state/`](state/).

## Choose the place by what the data is

| The data | Where it lives |
|---|---|
| Known at build time: holidays, translations, lookup tables | A global with a literal initializer, compiled into the program |
| Loaded at startup, and too large to copy into every worker: a GeoIP database, a catalog | goose-http's shared store, `import http.store` ([state that workers share](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#state-that-workers-share)) |
| Changing, and every worker must see the change: the projects, the users | A service thread that owns it, which routes ask ([Work that waits](../tutorial/13-waiting.md)) |
| A worker's own, where workers may differ: a cache, a rate limiter's counts | The worker's state, `cx.app` |
| One request's own: the signed-in user, looked up once | The request's state, `cx.state`, with `rest::once` |

Each row is the cheapest place that still gives every request the right answer. Data
that must look the same to every worker doesn't go per worker, and data that one worker can
keep doesn't cost a message to another thread.

## Data known at build time is a global

Write data that ships with a release as a global with a literal initializer. From
[`state/main.goose`](state/main.goose):

```rust
// Known at build time: compiled into the program, for every worker to read.
let HOLIDAYS = [
    Holiday { date: "2026-02-24", name: "Independence Day" },
    Holiday { date: "2026-06-24", name: "Midsummer Day" },
];
```

It's compiled into the program, so nothing loads it at startup, and a change to it is a
change to the code, reviewed and released as one. Don't load data into a global in
`main` before the workers start: each worker gets a copy of it
([State](../tutorial/08-state.md#per-worker)).

## A worker's state holds only what may differ

Keep in `cx.app` only data whose value may differ from one worker to the next without a
wrong answer: a cache, a count, a connection of the worker's own. Its type is `App`:

```rust
// The worker's own state: it lasts as long as the worker, and no other
// worker sees it.
struct App { lookups: i64 }
```

```rust
thread_fn worker(cfg: http::Config) {
    var app = App { lookups: 0 };
    let e = rest::serve(cfg, app) { cx => handle(cx) };
```

A client's next request may reach another worker. Data that must be the same for the client
on that worker, such as a project just created, belongs on a service thread. The programs in this
section and the tutorial keep projects per worker only because they run one worker.

## The state's types are declared in `main.goose`

Declare `App`, the worker's state, `St`, the request's state, and `Waiting`, what a
route that waits keeps until it resumes
([Work that waits](../tutorial/13-waiting.md)), in `main.goose`, beside the workers
that pass them to `rest::serve`.

Each is one type for the whole program: every domain's routes get the same `cx`, so no
domain owns them. A domain still owns its part of `Waiting`: its variants are named for
it (`Waiting.ProjectCreate`), and their `resume` case functions are in its
`routes.goose` ([Layout by domain](layout.md#the-same-files-in-every-domain)).

---

[Best practices](README.md) · Previous: [Middleware and stacks](middleware.md) · Next:
[Errors](errors.md)
