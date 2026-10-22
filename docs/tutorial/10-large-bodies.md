# 10. Large bodies

Projects now have tasks, imported from a spreadsheet as CSV. Thousands of lines don't fit
in the 8 KB buffer that goose-http reads requests into. Plod gathers the whole
body, up to a limit the route sets, then calls the route with it.
[goose-http's request bodies](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)
covers how goose-http reads a body, and the other ways to read one.

## Gathered whole, up to a limit

A body that fits alongside its head in the read buffer reaches the handler whole. A longer
body is gathered only when a route asks for it with `plod::body(cx, limit)` or
`plod::take` of a JSON type, which calls `plod::body` with its default of 1 MB. From
[`10-large-bodies`](10-large-bodies/main.goose):

```rust
// The most bytes an import takes: past the 8 KB read buffer, and below the
// server's 1 MB, so the route's limit is the one that applies.
let IMPORT_LIMIT: i64 = 256 * 1024;
```

```rust
// Each record is title,assignee. The whole body is checked before any task
// is added, so a bad record adds none.
fn import_tasks(cx, project: i64) {
    let kind, has_kind = plod::header(cx, "Content-Type");
    guard has_kind && starts_with(kind, "text/csv") else { plod::fail(cx, 415, "unsupported_media_type"); }
    // Leaves the route until the body is whole; the lines above then run again.
    let text = plod::body(cx, IMPORT_LIMIT);
    var good = true;
    let ok = csv::each_record(text) { f =>
        if f.len != 2 || f[0].len < 1 || f[0].len > 128 || f[1].len > 32 { good = false; }
    };
    guard ok && good else { plod::fail(cx, 400, "invalid_csv"); }
    var n = 0;
    csv::each_record(text) { f =>
        cx.app.tasks.push(Task { project: project, title: f[0], assignee: f[1] });
        n++;
    };
    plod::json(cx, 201, Imported { project: project, imported: n });
}
```

```text
POST /v1/projects/1/tasks/import 201 {"project":1,"imported":2}
POST /v1/projects/1/tasks/import 201 {"project":1,"imported":1000}     13 KB, gathered
POST /v1/projects/1/tasks/import 413 {"error":"payload_too_large"}     289 KB
POST /v1/projects/9/tasks/import 404 {"error":"project_not_found"}     not read
POST /v1/projects/1/tasks/import 415 {"error":"unsupported_media_type"}
POST /v1/projects/1/tasks/import 400 {"error":"invalid_csv"}
```

## The code before `plod::body` runs twice

If the body hasn't all arrived when a route first calls `plod::body` or `plod::take`,
the route leaves without answering. `plod::serve` reads the body up to the limit, then
calls the handler again with the whole body. Code before that first call therefore runs
twice for a long body and must not change state.

A check before that call is fine, and an answer there ends the request without reading
the body. The import route finds the project and checks the `Content-Type` before `plod::body`,
so an import into a project that doesn't exist gets its 404 before any of its 13 KB is
read:

```rust
        plod::post(cx, "/v1/projects/:id/tasks/import") { import_tasks(cx, project(cx)); };
```

```rust
fn project(cx) -> i64 {
    let id = plod::param_int(cx, "id");
    guard id >= 1 && id <= PROJECTS else { plod::fail(cx, 404, "project_not_found"); }
    return id;
}
```

Tasks are added after `plod::body`, during the run with the complete body, so each task
is added only once.

## Body limits and the gather budget

Three limits apply to each body, and the smallest wins; a fourth, the gather budget,
applies to the bodies a worker gathers at once:

| Limit | Set by | Past it |
|---|---|---|
| A route's | its first `plod::body(cx, limit)`, 1 MB without one | 413 `{"error":"payload_too_large"}` |
| A generated route's | `x-body-limit` on its `requestBody`, in bytes | the same |
| The server's | `http::Config`'s `max_body`, 1 MB by default | goose-http's 413, without a body, before any route runs |
| The gather budget, per worker | `http::gather_budget(bytes)` in `main`, 64 MB by default | 503 `{"error":"unavailable"}` with `Retry-After: 1` |

The import accepts up to 256 KB, below the server's 1 MB limit, so the program keeps
the default. A route that accepts more raises `max_body` to its limit, as
[`05-schema`](05-schema/main.goose) does for its 2 MB uploads:

```rust
    let cfg = http::Config { port: port as i32, workers: 1, max_body: max(api::MAX_BODY, UPLOAD_LIMIT), .. };
```

`api::MAX_BODY` is the largest `x-body-limit` in the schema, or 1 MB.

A body whose `Content-Length` is over the limit is refused before it's sent, and a
chunked body once it passes the limit. The first call sets the limit for the request.
To accept a JSON body over 1 MB, call `plod::body` with the limit it needs before
`plod::take`, as generated routes do for `x-body-limit`.

The worker holds each body it gathers until the route returns, so the limit also bounds
the memory that each connection importing at the same time uses for its body. The
worker keeps that memory after the request, for the bodies it gathers next: the most it
has gathered at once stays with it for its life. The route then reads the whole body in
one call, and the worker answers no other request meanwhile.

The gather budget bounds what the worker promises its bodies at once. When a route
calls `plod::body`, a body with a `Content-Length` is promised its whole length plus its
head, and a chunked body the route's limit plus its head. If the budget can't promise
that much, the worker answers 503 with `Retry-After: 1`, in the program's error shape,
at once, before the client sends the body; a body it admits is never refused later. The
client can try again a second later, once the worker has answered the requests whose
bodies it gathered in the meantime.

The default, 64 MB, lets a worker gather 63 bodies at the 1 MB limit at once, since each
takes its head too. The import sets a budget of its own with goose-http's
`http::gather_budget`, in `main` before `http::run`, for every worker:

```rust
    // The most bytes each worker gathers at once: 15 imports at the limit,
    // with their heads, where the default, 64 MB, would take 255.
    http::gather_budget(16 * IMPORT_LIMIT);
```

A body too large to gather, such as an attachment of any size, or an import of many
megabytes, is read in pieces as it arrives, which the budget doesn't count:
[page 14](14-bodies-in-pieces.md).

---

[Index](README.md) · Previous: [9. Testing without sockets](09-testing.md) · Next:
[11. Work that waits](11-waiting.md)
