# 1. Running something

A route checks its request in many places: a parameter in one function, a record in
another. In Actix or Axum, each check returns a `Result`, and every caller passes it up
to the handler, which turns it into a response. goose-rest answers the error where the
check fails, and the route ends there, so the functions in between return plain values.
This page runs a server with one such route.

## Failing from any depth

A route runs inside `rest::route`. A call to `rest::fail` anywhere in the route's call
chain answers the request and leaves the route. From
[`01-running`](01-running/main.goose):

```rust
fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/hello/:name") {
            rest::route(cx) { hello(cx, rest::param(cx, "name")); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn hello(cx, name: const u8[:]) {
    rest::text(cx, 200, greeting(cx, name));
}

fn greeting(cx, name: const u8[:]) -> u8[>..] {
    // Answers 400, and leaves every caller up to the rest::route around hello.
    guard name.len <= 20 else { rest::fail(cx, 400, "name_too_long"); }
    return str("hello, ", name);
}
```

`greeting` returns a string, not a `Result`, and `hello` doesn't check anything. When
the name is too long, `rest::fail` leaves through Goose's `return ... from`, straight
to the `rest::route` around `hello`, which answers `400 {"error":"name_too_long"}`.
The compiler checks that every call that can fail runs inside a `rest::route`: a call
outside one doesn't compile.

The rest of goose-rest's design follows from this, and from the fact that Goose can't store
functions:

- There is no handler table, so routes are code: an `if` chain of `rest::on` calls
  inside `rest::routes`, or a router the generator writes as a `match`.
- Middleware is a block around routes, inlined into the handler, so it costs no call
  and no boxing. A `rest::fail` inside it leaves the whole route.
- Data that requests change is worker state, or lane data, owned by a thread of its own
  that workers reach by mail ([State](08-state.md)).

## Workers and `main`

A program's root file declares both packages at release tags. Use the goose-http tag
that the goose-rest release imports:

```text
import http from "github.com/kaitk/goose-http@1ebca1fd5561ec8b070b42323fa2bf0ea6622be5";
import rest from "github.com/kaitk/goose-rest@v0.1.2";
```

The tutorial's programs live in this repository, so they import goose-rest by its path
instead (`import rest from "../../../";`).

A server is a few worker threads, each running goose-http's event loop with your handler
inlined into it ([goose-http's concepts](https://github.com/kaitk/goose-http#concepts)).
Workers share no memory and take no locks: each has its own copy of the globals and
builds its own state, and a request runs from start to end on the worker that read it.

A worker is a `thread_fn` that calls `rest::serve`. For each request, `rest::serve`
calls its block with a `rest::Cx`, the request context:

```rust
thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, .. };
    var ids: i64[>..] = [];
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg)); }
    for id in ids { thread_wait(id); }
}
```

`http::worker_count` uses `cfg.workers` when it's set, and otherwise one worker per
hardware thread (per performance core on macOS). `http::stop_on_signals` makes SIGINT
and SIGTERM stop the server rather than terminate the process. The other programs use
the same `main`, some with `workers: 1`.

When a worker starts, it gets its own copy of the globals it uses, so data `main` loads
before spawning the workers is copied into every one. Data that every worker reads
goes in goose-http's store, `http.store`, instead ([page 8](08-state.md#worker-state)).

Build with `goose build`. `goose run` uses the in-process TinyCC backend, which can't
run the threads a server needs:

```sh
goose build -o build/hello docs/tutorial/01-running/main.goose
build/hello 8080
curl -s localhost:8080/hello/goose              # hello, goose
curl -s localhost:8080/hello/aaaaaaaaaaaaaaaaaaaaaaaaa
                                                # {"error":"name_too_long"}
curl -s -X POST localhost:8080/hello/goose      # {"error":"method_not_allowed"}
```

---

[Index](README.md) · Next: [2. Routes, path, query, and headers](02-routes.md)
