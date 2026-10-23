# 1. Running something

A route checks its request in many places: a parameter in one function, a record in
another. In Actix or Axum, each check returns a `Result`, and every caller passes it up
to the handler, which turns it into a response. Plod answers the error where the
check fails, and the route ends there, so the functions in between return plain values.
This page runs a server with one such route.

## Failing from any depth

`plod::routes` runs its block as the request's route, and `plod::get` runs its own
block when the request is a GET of its path. A call to `plod::fail` anywhere in the
route's call chain answers the request and leaves the route. From
[`01-running`](01-running/main.goose):

```rust
fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/hello/:name") { hello(cx, plod::param(cx, "name")); };
    };
}

fn hello(cx, name: const u8[:]) {
    plod::text(cx, 200, greeting(cx, name));
}

fn greeting(cx, name: const u8[:]) -> u8[>..] {
    // Answers 400, and leaves every caller up to the route around hello.
    guard name.len <= 20 else { plod::fail(cx, 400, "name_too_long"); }
    return str("hello, ", name);
}
```

`greeting` returns a string, not a `Result`, and `hello` doesn't check anything. When
the name is too long, `plod::fail` leaves through Goose's `return ... from`, straight
to the route around `hello`, which answers `400 {"error":"name_too_long"}`. The
compiler checks that every call that can fail runs inside a route: a call outside one
doesn't compile. A request that no route takes gets 404 from `plod::routes`.

The rest of Plod's design follows from this, and from the fact that Goose can't store
functions:

- There is no handler table, so routes are code: `plod::get` calls and their kin
  inside `plod::routes`, or a router the generator writes as a `match`.
- Middleware is a block around routes, inlined into the handler, so it costs no call
  and no boxing. A `plod::fail` inside it leaves the whole route.
- Data that requests change is worker state, or lane data, owned by a thread of its own
  that workers reach by mail ([State](08-state.md)).

## Workers and `main`

A program's root file declares both packages, goose-http at the reference that its
Plod imports. The latest Plod release, `v0.5.0`, and the goose-http tag it
imports, `v0.5.6`, build with Goose `v2026.3`:

```text
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "github.com/kaitk/plod@v0.5.0";
```

This tutorial tracks the libraries' `main` branches until their next releases. Its
programs import Plod by its path (`import plod from "../../../";`) and the
goose-http reference that Plod imports, and build with the Goose release that
[development](../development.md#get-goose) names.

A server is a few worker threads, each running goose-http's event loop with your handler
inlined into it ([goose-http's concepts](https://github.com/kaitk/goose-http#concepts)).
Workers share no memory and take no locks: each has its own copy of the globals and
builds its own state, and a request runs from start to end on the worker that read it.

A worker is a `thread_fn` that calls `plod::serve`. For each request, `plod::serve`
calls its block with a `plod::Cx`, the request context:

```rust
thread_fn worker(cfg: http::Config) {
    let e = plod::serve(cfg) { cx => handle(cx) };
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
    http::run(cfg, worker);
}
```

`http::run` spawns the workers, each a `worker` with its own copy of `cfg`, and
returns once they have all returned. It starts `cfg.workers` when it's set, and
otherwise one worker per hardware thread (per performance core on macOS); values of
the program's for every worker go between `cfg` and `worker`. `http::stop_on_signals` makes SIGINT
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
