# Architecture

goose-rest is a REST framework for Goose on `goose-http`. It follows Actix's model,
changed where Goose differs, and costs nothing over a hand-written `http::router` if
chain wherever the language allows. Routing, extractors, middleware, errors, worker
state, and JSON are the framework. A generator that writes types, readers, writers, and
a router from an OpenAPI document is an optional layer on top; a program without a
schema uses all of the rest.

This page explains how goose-rest works and why. The [tutorial](tutorial/README.md)
builds a program step by step, the [reference](reference.md) lists every call, and the
[generator reference](generator.md) says what the generator reads and writes. The dated
decisions and the alternatives they rejected are in [Decisions](decisions.md).

## How Goose shapes the package

Six properties of the language decide the design. Section numbers refer to the Goose
spec.

- **No handler table.** Function values are compile-time generic parameters. They
  can't be stored, returned, or put in data, and there are no runtime function
  pointers (§7.6). Actix's `App::new().route("/x", web::get().to(h))` is a data
  structure of boxed handlers and can't exist. The application is code: routes are an
  if chain of `rest::on` calls in `rest::routes`, or a generated `match`.
- **Middleware is a block.** A trailing block is inlined, and a `return` in it returns
  from the enclosing handler (§7.6, §7.9). `rest::cors(cx, rest::Cors { .. }) { ... }`
  can answer a preflight and not run the block, with no boxing, no dynamic dispatch,
  and no layer stack. This is cheaper than Actix's `Transform` and Tower's `Layer`, and
  is the framework's main idea.
- **Extractors by overload.** Generics are monomorphized and re-checked per
  instantiation (§7.7), so `rest::take<T>(cx)` calls `from_request(cx, v: const T?)`
  and overloading chooses by `T`, as Actix's `FromRequest` trait does.
- **Half a derive.** Goose has no macros, and its one compile-time expansion, `const
  for` (spec §6), names a struct's fields without their types. So
  `rest::format_fields` writes any struct's fields as JSON, as serde's derived
  `Serialize` does, but a reader, a renamed key, or a left-out field still comes from
  code written by hand or from the generator
  ([decisions](decisions.md#a-json-writer-from-a-structs-fields)).
- **No shared memory.** Workers share nothing but `const` data and messages (§11.2).
  A cache, rate limiter, or session store lives in worker state or in lane data owned
  by a separate thread. Workers access lane data by mail.
- **No async.** A handler that waits on another thread splits in two around the reply,
  with its state in the connection ([Waiting on a lane](#waiting-on-a-lane)).

## Actix, and where goose-rest differs

| Actix | goose-rest | Why |
|---|---|---|
| `HttpServer::new(\|\| App::new())` builds an `App` per worker thread | Each worker's `thread_fn` builds its own state and calls `rest::serve` | The same model. Goose enforces it: workers share nothing. |
| `web::Data<T>`, `app_data` | `App`, a struct of references to the worker's locals, in `cx.app` | A struct holds at most one resizable, as its last field (§3.4); references avoid that limit. |
| `App::route`, `web::scope`, `web::resource`, guards | `rest::on` inside `rest::routes`, with `rest::scope(cx, prefix)`; guards are `if` conditions | No handler table. |
| `FromRequest` extractors as handler arguments | `let v = rest::take<T>(cx);`, or `rest::param_int(cx, "id")` | `T` is explicit; Goose can't infer it from the result. |
| Middleware: `wrap`, `from_fn`, `Transform` | Blocks around the dispatch or a route, inlined into it | No boxing and no call per layer. |
| `ResponseError`, `Result<impl Responder, E>`, `?` | `rest::fail(cx, status, code)` returns from `rest::route` from any depth | `return ... from` replaces threading a `Result` up. |
| `Responder`, `web::Json<T>` | `rest::json(cx, status, v)`, which calls `format(out, v)` | The `format` hook is Goose's one type-directed lookup (§3.7, §11.1). |
| serde's `Serialize` and `Deserialize` | `format` and a reader per type, written by hand or generated | No derive. |
| `async fn` handlers awaiting a database | A handler that asks another thread, and a case function that resumes it | No async. |

## A request's path

Each worker's thread builds its own state and calls `rest::serve`, which puts that
state in `cx.app`, starts the request state `cx.state` fresh for each request, and
calls the program's handler with one context, `cx`. The handler is plain code:

```rust
fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::routes(cx) { cx =>
                if rest::on(cx, "GET", "/health") {
                    rest::text(cx, 200, "ok");
                } else if rest::scope(cx, "/v1") {
                    rest::route(cx) {
                        let s = security_session(cx);
                        if rest::on(cx, "GET", "/projects/:id") {
                            get_project(cx, s, rest::param_int(cx, "id"));
                        } else if rest::on(cx, "POST", "/projects") {
                            create_project(cx, s, rest::take<ProjectCreate>(cx));
                        } else {
                            rest::otherwise(cx);
                        }
                    };
                } else {
                    rest::otherwise(cx);
                }
            };
        };
    };
}
```

`rest::scope` narrows the router to a prefix, and `rest::otherwise` answers 404, 405,
and OPTIONS across scopes from the routes it passed. An extractor runs only where the
handler calls it, and `goose-http` keeps header lines as bytes until one is asked for,
so a route parses only what it reads. A body taken as a schema type, with `rest::take`
or by the generated router, arrives parsed and validated; a malformed one gets 400 and
its field errors, in one error shape for every route, before the code that uses it
runs. A route that reads `rest::body` gets the bytes and parses them itself.

`rest::fail` leaves through `return ... from rest::route`, so a helper several calls
down can answer 404 without passing an error back up. A call to `fail` outside a route
doesn't compile. The first answer wins: a failure after the handler began a response
leaves that response, and if the response is still open, goose-http closes the
connection, so the client sees it cut short rather than an error inside it.

A check that must run, such as a session lookup, fails the route. Work that can wait,
such as loading a profile, is a lazy extractor: `rest::once` runs it on first call and
keeps the result in `cx.state` for the request. The request state is fixed-size,
kept in a pool slot, and reset per request ([State](tutorial/08-state.md)).

`GET /projects/42` then costs a router match, an integer parse, the session check, the
handler, and the writer. It looks up no handler, runs no boxed middleware, and parses
nothing the route doesn't read.

## Middleware and inlining

Middleware is a block around the routes it applies to. A handler behind middleware
compiles to one C function, with the middleware, the route, and the code that fails
inlined into it, with each early answer compiled as a jump. Three rules keep it so:

- **One route per request.** A function that fails returns from the innermost route,
  so a route nested in a route keeps both out of line. Middleware doesn't open routes
  of its own.
- **Functions that fail stay small.** A function that fails and stays a call keeps its
  route, everything around it, and the handler out of line. goose-rest's extractors
  fail in a few statements and do their work in leaves that return whether it
  succeeded.
- **Block-taking functions are `inline fn`.** Given a block of routes, a plain function
  passes the inliner's size limit at once and stays a call, although it's called once.

Middleware that applies to every answer, such as `timed`, `cors`, and `compressed`, goes
outside `rest::route`, so that the errors the route answers get it too; middleware that
can fail, such as `bearer`, goes inside it. The [reference](reference.md#middleware)
says which answers get which fields.

A program's own middleware is an `inline fn` that takes a block. A stack is one that
nests several middleware and passes its own block on, so a scope has one level however
many it holds, and compiles to the same code as the nesting written out
([A stack of your own](tutorial/07-middleware.md#a-stack-of-your-own)). A stack is code,
not a value: a program can't build a list of middleware at run time.

## Waiting on a lane

Workers share no memory, so I/O-bound work, such as a query to a database server, runs
on a lane, which workers mail: a thread of its own, or several that run the same jobs,
for one kind of work. It's the synchronous half of goose-http's
[half-sync/half-async split](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#slow-work).
In the route, the worker's core would sit idle through each wait while the worker's
other connections queue. CPU-bound work, including a query on embedded SQLite, runs in
the route. When the workers already use every core, a lane adds no throughput for it;
it helps only work long enough to hold up the worker's other connections, which a lane
lets the operating system interleave with it. A route sends the lane one job naming the
whole use case with `rest::ask`, and the lane does it start to end with blocking calls,
in one transaction. The route waits once, with one time limit and one place where a
full box refuses work, and the job can be tested as a plain call. A route waits more
than once only for what one lane can't do: a second lane in turn.

Goose can't store a function to call later, so the request state holds a
fixed-mode enum of what each waiting route needs, and the program writes a case
function per variant. The compiler dispatches on the tag and checks that every variant
has its case:

```rust
enum Waiting { None, Report { org: i64 } }
struct St { waiting: Waiting = Waiting.None }

rest::serve(cfg, app, St { .. }) { cx =>
    if rest::resumed(cx) { rest::route(cx) { resume(cx.state.waiting, cx); }; } else { handle(cx); }
};
```

The job crosses as a `to_bytes` image, with no JSON between threads, and the lane's
box carries bytes in fixed-size slots, as goose-http's
[mail between threads](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#mail-between-threads)
explains. A reply larger than a slot comes in pieces; `rest::relay` sends each as a
chunk. `rest::still_wanted` tells the lane whether the route still waits, so it can
skip the work of a client that has gone. A route that never waits keeps nothing on the
connection. The tutorial builds this from [work that waits](tutorial/11-waiting.md) to
[limits](tutorial/13-limits.md).

## Bodies and responses in pieces

Every call after a request's first goes through the same case functions, not only a
reply. A route that reads its body in pieces (`rest::body_in_pieces`), sends its
response in pieces (`rest::begin`, `rest::file`), or takes an upgraded connection
(`rest::upgrade`) gives a `Waiting` variant, as `rest::ask` does. `rest::serve` then
calls the handler again for each event of the exchange, with `cx.kind` saying which:
`BODY`, `END`, `MORE`, or `CLOSED`. `CLOSED` comes once to a route that ended early, so
that its case function releases what the state holds. A route that began a response
can pause it with `rest::pause`, and gets `TIMEOUT` when the time has passed, for
events sent over time: the exchange keeps the pause's deadline, so that goose-rest
ends the response when goose-http, with no timer free, gives `TIMEOUT` at once. One case function per variant
handles every kind, because Goose can't keep a block to call at the next event.
[Later calls](reference.md#later-calls) has each call and event.

Each call goes to the variant that is in `cx.state.waiting` at the time, and goose-rest
keeps no other. An upgraded connection that waits on `rest::ask` therefore gets the
client's bytes in the ask's case function, which also gets the `TIMEOUT`, since a 504
can't follow the 101, and which sets the upgrade's variant back when the wait ends. An
exchange has one wait, so a second `rest::ask` during it fails.

A route's middleware keeps what it decided with the exchange, so an answer written at a
later call still gets the CORS fields and `Server-Timing`. A file being sent lives in
the program's state, so a program that serves no files keeps no bytes for one.

## The generator

The generator is a Goose program that reads an OpenAPI 3.1 document, whose types are
JSON Schema, and writes a Goose file: for each schema, a struct, a reader, and a writer;
and a router, `dispatch`, from its paths. The build compiles that file with the
handlers. OpenAPI is the format clients, documentation tools, and a TypeScript backend
already read and write, so one contract can describe two backends of one API. An
optional TypeScript helper types a document to the supported subset as it's written
([Write it in TypeScript](generator.md#write-it-in-typescript)).

Its ideas come from Elysia 2, which composes each route's handler at run time or in an
ahead-of-time build. Goose's compiler already composes a handler with its middleware.
What the generator adds is the rest:

- **Readers** that dispatch keys by length and then bytes, validate as they read, and
  build the struct once, in place.
- **Writers** that write only the declared fields, each key's bytes a constant.
- **A router** that matches static paths by length and then bytes, and the rest by
  segment, so a 404 or 405 costs no more than a match, and each path's `Allow` is a
  constant.
- **Security per operation.** OpenAPI declares `security` per operation, so the router
  applies a check only to the operations that name it.

Each handler call is typed from its operation. A missing handler, or one whose
parameters have the wrong types, fails to compile, which keeps schema and code in step.
A construct outside the supported subset is a generator error that names it, never
silently dropped. The generated code is plain Goose, can be read and debugged like any other
file, and is never edited.

Without a schema, the if chain is the API. Each `rest::on` scans the path again from its
start, so a long chain costs more per request than a generated router
([tier R](benchmarks.md#tier-r)).

## What each choice costs

- **Routes are code.** A program can't build its routes or its middleware at run time,
  and can't list them, so an OpenAPI document can't yet be written from the routes.
- **Extractor types are explicit.** `rest::take<T>(cx)` names `T`, and a program
  declares its readers in `rest`'s namespace, `fn rest::from_request(...)`, because a
  generic body looks names up where it's defined.
- **No derive.** Without the generator, each type's reader and `format` are written by
  hand. A type with no `format` overload renders as a Goose value, not JSON, and still
  compiles.
- **Inlining has rules.** A route nested in a route, a large function that fails, or a
  plain `fn` that takes a block keeps the handler out of line, and the program still
  works, at a call per layer.
- **Worker state.** A cache or session store lives in worker state or in lane data
  accessed by mail. Workers share nothing by reference.
- **Waiting splits a handler.** A route that waits writes its state into a `Waiting`
  variant and resumes in a case function, instead of continuing after an `await`.
  Replies come through fixed-size mail slots, and a larger one in pieces.
- **The first answer wins.** Once a response has begun, a failure can't replace it; an
  open response is cut short instead.
- **Compression copies.** `rest::compressed` writes each answer inside it to a local
  buffer and copies it once into the response.
- **The generator's subset.** It refuses what it can't read yet, such as `pattern` and
  recursive schemas ([The subset](generator.md#the-subset)).
