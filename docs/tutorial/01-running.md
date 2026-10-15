# 1. Running something

A goose-rest server is a few worker threads, each running goose-http's event loop with
your handler inlined into it ([goose-http's concepts](https://github.com/kaitk/goose-http#concepts)).
Workers share nothing but constants and messages: each has its own copy of the globals,
and there are no locks. Each one builds its own state, and a request runs start to
finish on the worker that read it.

## The one idea

Inside a worker, a route runs inside `rest::route`, and `rest::fail` answers the request
from any depth below it. From [`01-running`](01-running/main.goose):

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
    guard name.len <= 20 else { rest::fail(cx, 400, "name_too_long"); }
    return str("hello, ", name);
}
```

`greeting` returns a string, not a `Result`, and `hello` doesn't check anything. When
the name is too long, `rest::fail` leaves through Goose's `return ... from`, straight
to the `rest::route` around `hello`, which answers `400 {"error":"name_too_long"}`.
The compiler checks that every call that can fail runs inside a `rest::route`: one
outside it doesn't compile.

The rest of goose-rest follows from this, and from Goose being unable to store a
function:

- There is no handler table, so routes are code: an `if` chain of `rest::on` calls
  inside `rest::routes`, or a router the generator writes as a `match`.
- Middleware is a block around routes, inlined into the handler, so it costs no call
  and no boxing. A `rest::fail` inside it leaves the whole route.
- State a request changes lives in its worker, or on a thread of its own that workers
  send messages to ([State](08-state.md)).

## Workers and `main`

A program's root file declares both packages, each at a release tag, goose-http at the
one goose-rest's release imports:

```text
import http from "github.com/kaitk/goose-http@v0.3.2";
import rest from "github.com/kaitk/goose-rest@v0.0.1";
```

The tutorial's programs live in this repository, so they import goose-rest by its path
instead (`import rest from "../../../";`).

A worker is a `thread_fn` that calls `rest::serve`, which calls its block with a
`rest::Cx`, the request's context, for each request:

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

`http::worker_count` is `cfg.workers`, or without it one worker per hardware thread (per
performance core on macOS), and `http::stop_on_signals` makes SIGINT and SIGTERM stop
the server rather than end the process. The other programs repeat this `main`, some
with `workers: 1`.

Build with `goose build`. `goose run`, the in-process TinyCC backend, can't run threads,
and a server spawns them:

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
